# github-action-load-used-actions
Load used actions from an entire organization, by calling the REST API with a Personal Access Token and loop through all workflows in all repositories in the user account or organization.

## Usage
Minimal uses expression to use this action:

``` yaml
uses: rajbos/github-action-load-used-actions@main`
with: 
    PAT: ${{ secrets.GITHUB_TOKEN }}
```
Note: the default GITHUB_TOKEN might only have read access to the current repository, depending on the setup. Create a new token with `repo` scope to have full read-only access to the organization and use that as a parameter.
-[ ] todo: check the scope and update above if needed

## Full example
This example shows how to use the action to get a json file with all the used actions in an organization. The json file is uploaded as an artefact in the third step.

|#|Name|Description|
|---|---|---|
|1|Run this action to load all actions used in an organization|
|2|Output the json value from the output of the action in step 1|
|3|Upload the json file as an artefact|


``` yaml
jobs:
  load-all-used-actions:
    runs-on: ubuntu-latest
    steps: 
      - uses: rajbos/github-action-load-used-actions@main
        name: Load used actions
        with: 
          PAT: ${{ secrets.GITHUB_TOKEN }}
        id: load-actions

      - shell: pwsh        
        run: |
         Write-Host "Found actions [${{ steps.load-actions.outputs.actions }}]"
         $content = ${{ steps.load-actions.outputs.actions }}
         New-Item -Path 'actions.json' -Value $content -Force | Out-Null
            
      - name: Upload result file as artefact
        uses: actions/upload-artifact@v2
        with: 
          name: actions
          path: actions.json
```