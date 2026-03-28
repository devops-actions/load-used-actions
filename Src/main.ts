import * as core from '@actions/core';
import * as fs from 'fs';
import * as path from 'path';
import {
  createOctokit,
  findAllRepos,
  getAllFilesInPath,
  getFileInfo,
  getRawFile,
} from './github-client';
import {
  getActionsFromWorkflow,
  getActionsFromCompositeAction,
  summarizeActionsUsed,
} from './actions-scanner';
import { ActionReference } from './types';
import { Octokit } from '@octokit/rest';

async function getAllUsedActionsFromRepo(
  repo: string,
  pat: string,
  octokit: Octokit
): Promise<ActionReference[]> {
  const [owner, repoName] = repo.split('/');
  const actionsInRepo: ActionReference[] = [];

  // Get workflow files
  const workflowFiles = await getAllFilesInPath(octokit, owner, repoName, '.github/workflows');
  if (workflowFiles.length > 0) {
    console.log(`Found [${workflowFiles.length}] files in the workflows directory`);
    for (const workflowFile of workflowFiles) {
      try {
        if (
          workflowFile.download_url &&
          workflowFile.download_url.split('?')[0].endsWith('.yml')
        ) {
          console.log(`Loading workflow file: [${workflowFile.name}]`);
          const workflow = await getRawFile(workflowFile.download_url, pat);
          const actions = getActionsFromWorkflow(workflow, workflowFile.name, repo);
          actionsInRepo.push(...actions);
        }
      } catch (error) {
        console.warn(`Error handling workflow file [${workflowFile.name}] in repo [${repo}]: ${error}`);
      }
    }
  }

  // Check for composite action files at repo root (action.yml / action.yaml)
  for (const actionFileName of ['action.yml', 'action.yaml']) {
    try {
      const fileInfo = await getFileInfo(octokit, owner, repoName, actionFileName);
      if (fileInfo && fileInfo.download_url) {
        console.log(`Found [${actionFileName}] in repo [${repo}], checking for composite action`);
        const content = await getRawFile(fileInfo.download_url, pat);
        if (content && content.length > 0) {
          const compositeActions = getActionsFromCompositeAction(content, actionFileName, repo);
          actionsInRepo.push(...compositeActions);
        }
        break; // don't check action.yaml if action.yml was found
      }
    } catch {
      // No action file found or error loading it
    }
  }

  return actionsInRepo;
}

export async function run(): Promise<void> {
  try {
    // Read inputs
    let organization = core.getInput('organization') || process.env.GITHUB_REPOSITORY_OWNER || '';
    let pat = core.getInput('PAT') || process.env.GITHUB_TOKEN || '';
    const includeArchivedInput = core.getInput('include-archived-repositories') || 'true';
    const includeArchived = includeArchivedInput !== 'false';

    if (!organization) {
      core.setFailed('No organization specified. Set the organization input or GITHUB_REPOSITORY_OWNER env var.');
      return;
    }

    if (!pat) {
      core.setFailed('No PAT specified. Set the PAT input or GITHUB_TOKEN env var.');
      return;
    }

    // Mask the token
    core.setSecret(pat);

    console.log(`Running with organization: [${organization}], includeArchived: [${includeArchived}]`);

    const octokit = createOctokit(pat);

    // Find all repos
    const repos = await findAllRepos(octokit, organization, includeArchived);

    // Get actions from all repos
    const allActions: ActionReference[] = [];
    for (const repo of repos) {
      if (repo.full_name && repo.full_name.length > 0) {
        console.log(`Loading actions from repo: [${repo.full_name}]`);
        const actionsUsed = await getAllUsedActionsFromRepo(repo.full_name, pat, octokit);
        allActions.push(...actionsUsed);
      }
    }

    if (allActions.length > 0) {
      // Separate container images from actions/reusable workflows
      const containerImages = allActions.filter((a) => a.type === 'container-image');
      const actionsOnly = allActions.filter((a) => a.type !== 'container-image');

      const summarizedActions = summarizeActionsUsed(actionsOnly);
      console.log(
        `Found [${actionsOnly.length}] actions used in [${repos.length}] repos with [${summarizedActions.length} unique actions]`
      );

      // Determine output directory
      const workspace = process.env.GITHUB_WORKSPACE || process.cwd();

      // Write actions file
      const actionsFileName = 'used-actions.json';
      const actionsFilePath = path.join(workspace, actionsFileName);
      const actionsJson = JSON.stringify(summarizedActions, null, 2);
      fs.writeFileSync(actionsFilePath, actionsJson);
      console.log(`Stored the summarized usage info into file: [${actionsFileName}]`);

      core.setOutput('actions-file', actionsFileName);

      // Write container images file if any were found
      if (containerImages.length > 0) {
        const summarizedContainerImages = summarizeActionsUsed(containerImages);
        console.log(
          `Found [${containerImages.length}] container image references with [${summarizedContainerImages.length}] unique images`
        );

        const containerFileName = 'container-images.json';
        const containerFilePath = path.join(workspace, containerFileName);
        const containerJson = JSON.stringify(summarizedContainerImages, null, 2);
        fs.writeFileSync(containerFilePath, containerJson);
        console.log(`Stored the container images info into file: [${containerFileName}]`);

        core.setOutput('container-images-file', containerFileName);
      }
    } else {
      console.log('No actions found in any repositories.');
    }
  } catch (error) {
    if (error instanceof Error) {
      core.setFailed(error.message);
    } else {
      core.setFailed(String(error));
    }
  }
}

run();
