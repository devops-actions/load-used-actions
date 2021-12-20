import YAML from 'yaml'

export function parse(content: string[], workflow: string, repo: string): action[] {
    console.log(`Starting analysis of workflow [${workflow}] in repo [${repo}]`)
    let actions: action[] = []    

    // try to parse the yaml
    try {   

        let foundJobs = false
        for (let i = 0; i < content.length; i++) {
            let line = content[i]
            if (line.startsWith('jobs:')){
                foundJobs = true
                continue
            }

            if (foundJobs) {
                // replace spaces with underscores
                let cleanLine = line.replace(/ /g, '')
                if (cleanLine.startsWith(('#'))) {
                    continue
                }
                // find index of first non space character
                let firstNonSpace = line.search(/\S/)
                if (firstNonSpace === 2) {
                    // found a job line!
                    //console.log(`Found job: ${line}`)
                    // indent with a -
                    line = '- ' // + line.substring(2, line.length - 1) // make item part of a yaml array so that we can find the properties better (instead of having a named object with subproperties)
                    // update the array
                    content[i] = line
                }
            }
        }

        try {                        
            //console.log('Updated file')
            //console.log(content.join('\r\n'))
            let parsed            
            try {
                parsed =YAML.parse(content.join('\r\n'))  
            } catch (e) {
                console.log(`Error parsing the workflow [${workflow}] in repo [${repo}]`)
                console.log(`${e}`)
                return actions
            }
            //console.log(`Found these jobs: ${JSON.stringify(parsed.jobs)})`)
            for (const job of parsed.jobs) {
                //console.log(`- Found job: ${JSON.stringify(job)}`)
                //console.log(`- Found a job`)
                if ('steps' in job) {
                    for(const step of job.steps) {
                        //console.log(`    - Found step: ${JSON.stringify(step)}`)
                        // search for uses property:
                        if ('uses' in step) {
                            //console.log(`      - Found uses: ${JSON.stringify(step.uses)}`)
                            const action = loadActionFromUses(step.uses, workflow, repo)
                            console.log(`  - Found action: ${JSON.stringify(action)}`)

                            actions.push(action)
                        }
                    }
                }
                else {
                    if ('uses' in job) {
                        // found reusable workflows!
                        console.log(`  - Found reusable workflow: ${JSON.stringify(job.uses)}`)
                    }
                }
            }        
            
            return actions
        }
        catch (e) {
            console.log(`Error parsing yaml on file: ${workflow}`)
            console.log(e)
        }        
    } catch (error) {
        // this happens in https://github.com/gaurav-nelson/github-action-markdown-link-check/blob/9de9db77de3b29b650d2e2e99f0ee290f435214b/action.yml#L9
        // because of invalid yaml
        console.log(
            `Error parsing workflow file [${workflow}] with error:`
        )
        console.log(error)
        console.log(
            `The parsing error is informational, seaching for actions has continued`
        )
    }

    return actions
}

function loadActionFromUses(uses: string, workflow: string, repo: string): action {
    if (uses.indexOf('@') === -1) {
        return new action(uses, "", workflow, repo);
    }
    const split = uses.split('@');
    return new action(split[0], split[1], workflow, repo);
}

export class action {
    name: string
    version: string
    workflow: string
    repo: string
    constructor(name: string, version: string, workflow: string, repo: string) {
        this.name = name
        this.version = version
        this.workflow = workflow
        this.repo = repo
    }
}
