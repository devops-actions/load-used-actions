# github-action-load-used-actions
Load used actions from an entire organization, by calling the REST API with a Personal Access Token and loop through all workflows in all repositories in the user account or organization.

The output is stored with the name `actions`, which can be retrieved in another action with `${{ steps.<step id>.outputs.actions }}`.

Used for inserting data into the [internal actions marketplace](https://github.com/rajbos/actions-marketplace).

## Example usage
Minimal uses expression to use this action:

``` yaml
uses: devops-actions/github-action-load-used-actions@main`
with: 
    PAT: ${{ secrets.GITHUB_TOKEN }} # use an Access Token with correct permissions to view private repos if you need to
```
Note: the default GITHUB_TOKEN might only have read access to the current repository but can read the public repositories for any organization, depending on the specific setup of the GITHUB_TOKEN. Create a new access token (PAT or use a GitHub App) with `repo` scope to have full read-only access to the organization and use that as a parameter.  

## Full example
This example shows how to use the action to get a json file with all the used actions in an organization. The json file is uploaded as an artefact in the third step.

|#|Name|Description|
|---|---|---|
|1|Load used actions|Run this action to load all actions used in an organization. Note the id of this step|
|2|Store json file|Output the json value from the output of the action in step 1, by using the id of step 1 in `${{ steps.<step id>.outputs.actions }}`|
|3|Upload result file as artefact|Upload the json file as an artefact|


``` yaml
jobs:
  load-all-used-actions:
    runs-on: ubuntu-latest
    steps: 
      - uses: devops-actions/github-action-load-used-actions@main
        name: Load used actions        
        id: load-actions
        with: 
          PAT: ${{ secrets.GITHUB_TOKEN }} # use an Access Token with correct permissions to view private repos if you need to

      - shell: pwsh        
        name: Store json file
        run: echo ${{ steps.load-actions.outputs.actions }} > 'actions.json'
            
      - name: Upload result file as artefact
        uses: actions/upload-artifact@v2
        with: 
          name: actions
          path: actions.json
```

## Inputs
|Name|Description|
|---|---|
|organization|The name of the organization to run on.|
|PAT|The Personal Access Token to use for the API calls.|

## Outputs
actions: a compressed json string with all the actions used in the workflows in the organization. The json is in the format:
``` json
[
    "actionLink": "actions/checkout",
    "count": 50,
    "workflows": [
        {
            "repo": "rajbos/actions-marketplace",
            "workflowFileName": "build-image.yml"
        },
        { "etc" : "--" }
    ]
]
```
Properties:
|Name|Description|
|----|-----------|
|actionLink|The link to the action used in the workflow|
|count|The number of times the action was used in the workflow|
|workflows|An array of workflows that used the action|

The workflow object has the following properties:
|Name|Description|
|----|-----------|
|repo|The name of the repository that uses the action|
|workflowFileName|The name of the workflow file that was found in the directory `.github/workflows/`|
