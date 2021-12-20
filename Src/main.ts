import * as core from '@actions/core'
import {Octokit} from 'octokit'
import YAML from 'yaml'
import GetDateFormatted from './utils'
import dotenv from 'dotenv'
import { parse, action } from './parsing'

// always import the config
dotenv.config()

async function run(): Promise<void> {
 
  core.info('Starting')
  try {
    const PAT = core.getInput('PAT') || process.env.PAT || ''
    const user = core.getInput('user') || process.env.GITHUB_USER || ''
    const organization =
      core.getInput('organization') || process.env.GITHUB_ORGANIZATION || ''

    if (!PAT || PAT === '') {
      core.setFailed(
        "Parameter 'PAT' is required to load all workflows from the organization or user account"
      )
      return
    }

    if (user === '' && organization === '') {
      core.setFailed(
        "Either parameter 'user' or 'organization' is required to load all workflows from it. Please provide one of them."
      )
      return
    }

    const apiUrl = process.env.GITHUB_API_URL || 'https://api.github.com' 
    core.debug(`Using API URL: ${apiUrl}`)
    const octokit = new Octokit({auth: PAT, baseUrl: apiUrl})

    // try {
    //   const currentUser = await octokit.rest.users.getAuthenticated()

    //   core.info(`Hello, ${currentUser.data.login}`)
    // } catch (error) {
    //   core.setFailed(
    //     `Could not authenticate with PAT. Please check that it is correct and that it has [read access] to the organization or user account: ${error}`
    //   )
    //   return
    // }

    const repos = await findAllRepos(octokit, user, organization)
    const workflows = await findAllWorkflows(octokit, repos)
    // load the information in the files
    const actions = await loadActionsFromWorkflows(octokit, workflows)
    const uniqueActions = getUniqueActions(actions)

    // output the json we want to output
    const output: {
      lastUpdated: string
      organization: string
      user: string
      actions: action[]
      uniqueActions: string[]
    } = {
      lastUpdated: GetDateFormatted(new Date()),
      actions: actions,
      organization,
      user,
      uniqueActions
    }

    const json = JSON.stringify(output)
    core.setOutput('actions', json)
  } catch (error) {
    core.setFailed(`Error running action: : ${error.message}`)
  }
}

//todo: move this function to a separate file, with the corresponding class definition
async function findAllRepos(
  client: Octokit,
  username: string,
  organization: string
): Promise<Repository[]> {
  // todo: switch between user and org

  // convert to an array of objects we can return
  const result: Repository[] = []

  if (username !== '') {
    core.info(`Searching for repositories for user: [${username}]`)
    const repos = await client.paginate(client.rest.repos.listForUser, {
      username
    })

    core.info(`Found [${repos.length}] repositories`)

    // eslint disabled: no iterator available
    // eslint-disable-next-line @typescript-eslint/prefer-for-of
    for (let num = 0; num < repos.length; num++) {
      const repo = repos[num]
      const repository = new Repository(repo.owner?.login || '', repo.name) //todo: handle for orgs
      result.push(repository)
    }
  }

  if (organization !== '') {
    core.info(`Searching for repositories in organization: [${organization}]`)
    const repos = await client.paginate(client.rest.repos.listForOrg, {
      org: organization
    })

    console.log(`Found [${organization}] as orgname parameter`)
    core.info(`Found [${repos.length}] repositories`)

    // eslint disabled: no iterator available
    // eslint-disable-next-line @typescript-eslint/prefer-for-of
    for (let num = 0; num < repos.length; num++) {
      const repo = repos[num]
      const repository = new Repository(repo.owner?.login || '', repo.name) //todo: handle for orgs
      result.push(repository)
    }
  }

  return result
}

class Repository {
  name: string
  owner: string
  constructor(owner: string, name: string) {
    this.name = name
    this.owner = owner
  }
}

class Content {
  name = ``
  repo = ``
  downloadUrl = ``
  author = ``
  description = ``
}

async function findAllActions(
  client: Octokit,
  repos: Repository[]
): Promise<Content[]> {
  // create array
  const result: Content[] = []

  // search all repos for actions
  for (const repo of repos) {
    core.debug(`Searching repository for actions: ${repo.name}`)
    const content = await getActionFile(client, repo)
    if (content && content.name !== '') {
      core.info(
        `Found action file in repository: ${repo.name} with filename [${content.name}] download url [${content.downloadUrl}]`
      )
      // add to array
      result.push(content)
    }
  }

  console.log(`Found [${result.length}] actions in [${repos.length}] repos`)
  return result
}

async function findAllWorkflows(
    client: Octokit,
    repos: Repository[]
  ): Promise<Content[]> {
    // create array
    let result: Content[] = []
  
    // search all repos for actions
    for (const repo of repos) {
      core.debug(`Searching repository for workflows: ${repo.name}`)
      const repoContent = await getWorkflowFiles(client, repo)
      let currentCount = 0
      if (repoContent && repoContent.length !== 0) {
        // add to full array
        result = result.concat(repoContent)
        currentCount = repoContent.length
      }
      console.log(`  Found [${currentCount}] workflows in repository: ${repo.name} `)

      //temp for testing so we dont load ALL repos, the first one is enough
      // if (result.length !== 0){
      //    return result
      // }
    }
  
    console.log(`Found [${result.length}] workflows in [${repos.length}] repos`)
    return result
}

async function getWorkflowFiles(
    client: Octokit,
    repo: Repository
  ): Promise<Content[] | null> {
  
    // search for *.yml files in the .github/workflows foder of the repo
    const result: Content[] = []
    try {
        // todo: add pagination!
      const {data: workflows} = await client.rest.repos.getContent({
        owner: repo.owner,
        repo: repo.name,
        path: '.github/workflows'
      })
  
      // todo: warning: duplicated code here     
      for (const file of workflows) { 
        if ('name' in file && 'download_url' in file) {
            if (file.name.endsWith('.yml')) {
                
                let currentWorkflow = new Content()

                currentWorkflow.name = file.name
                currentWorkflow.repo = repo.name
                if (file.download_url !== null) {
                    currentWorkflow.downloadUrl = file.download_url
                }

                result.push(currentWorkflow)
            }
        }        
      }
    } catch (error) {
      core.debug(`No .yml file(s) found in repository: ${repo.name}`)
    }      
  
    if (result.length === 0) {
      core.info(`No workflows found in repository: ${repo.name}`)
      return null
    }
  
    return result
}

async function getActionFile(
  client: Octokit,
  repo: Repository
): Promise<Content | null> {
  const result = new Content()

  // search for action.yml file in the root of the repo
  try {
    const {data: yml} = await client.rest.repos.getContent({
      owner: repo.owner,
      repo: repo.name,
      path: 'action.yml'
    })

    // todo: warning: duplicated code here
    if ('name' in yml && 'download_url' in yml) {
      result.name = yml.name
      result.repo = repo.name
      if (yml.download_url !== null) {
        result.downloadUrl = yml.download_url
      }
    }
  } catch (error) {
    core.debug(`No action.yml file found in repository: ${repo.name}`)
  }

  if (result.name === '') {
    try {
      // search for the action.yaml, that is also allowed
      const {data: yaml} = await client.rest.repos.getContent({
        owner: repo.owner,
        repo: repo.name,
        path: 'action.yaml'
      })

      if ('name' in yaml && 'download_url' in yaml) {
        result.name = yaml.name
        result.repo = repo.name
        if (yaml.download_url !== null) {
          result.downloadUrl = yaml.download_url
        }
      }
    } catch (error) {
      core.debug(`No action.yaml file found in repository: ${repo.name}`)
    }
  }

  if (result.name === '') {
    core.info(`No actions found in repository: ${repo.name}`)
    return null
  }

  return result
}

async function enrichActionFiles(
  client: Octokit,
  actionFiles: Content[]
): Promise<Content[]> {
  for (const action of actionFiles) {
    // download the file in it and parse it
    if (action.downloadUrl !== null) {
      const {data: content} = await client.request({url: action.downloadUrl})

      // try to parse the yaml
      try {
        const parsed = YAML.parse(content)
        action.name = parsed.name
        action.author = parsed.author
        action.description = parsed.description
      } catch (error) {
        // this happens in https://github.com/gaurav-nelson/github-action-markdown-link-check/blob/9de9db77de3b29b650d2e2e99f0ee290f435214b/action.yml#L9
        // because of invalid yaml
        console.log(
          `Error parsing action file in repo [${action.repo}] with error:`
        )
        console.log(error)
        console.log(
          `The parsing error is informational, seaching for actions has continued`
        )
      }
    }
  }
  return actionFiles
}

async function loadActionsFromWorkflows(client: Octokit, workflows: Content[]): Promise<action[]> {
    
    let allActions: action[] = []
    for (const workflow of workflows) {
        // download the file in it and parse it
        if (workflow.downloadUrl !== null) {
            const {data: content} = await client.request({url: workflow.downloadUrl})
            // downloads as a string with \n line endings
            const splitted = content.split('\n')
            const actions = parse(splitted, workflow.name, workflow.repo)            

            allActions = allActions.concat(actions)
        }
    }
    console.log(`Found a total of [${allActions.length}] actions used in [${workflows.length}] workflows`)
    return allActions
}


run()

function getUniqueActions(actions: action[]):string[] {
    const unique = new Set(actions.map(action => action.name))
    return Array.from(unique)
}
