import * as yaml from 'js-yaml';
import { ActionReference, SummarizedAction, WorkflowReference } from './types';

/**
 * Extract actions, reusable workflows, and container images from a workflow YAML file.
 */
export function getActionsFromWorkflow(
  yamlContent: string,
  workflowFileName: string,
  repo: string
): ActionReference[] {
  let parsedYaml: Record<string, unknown>;
  try {
    parsedYaml = yaml.load(yamlContent) as Record<string, unknown>;
  } catch {
    console.warn(`Error parsing the yaml from workflow file: [${workflowFileName}] in repo: [${repo}]`);
    return [];
  }

  if (!parsedYaml || typeof parsedYaml !== 'object') {
    return [];
  }

  const actions: ActionReference[] = [];
  const jobs = parsedYaml['jobs'] as Record<string, Record<string, unknown>> | undefined;
  if (!jobs || typeof jobs !== 'object') {
    return actions;
  }

  for (const [jobKey, job] of Object.entries(jobs)) {
    if (!job || typeof job !== 'object') continue;

    // Check for job-level container image
    const jobContainer = job['container'];
    if (jobContainer != null) {
      let containerImage: string | null = null;
      if (typeof jobContainer === 'string') {
        containerImage = jobContainer;
      } else if (typeof jobContainer === 'object' && (jobContainer as Record<string, unknown>)['image']) {
        containerImage = (jobContainer as Record<string, unknown>)['image'] as string;
      }
      if (containerImage && containerImage.length > 0) {
        actions.push({
          actionLink: containerImage,
          actionRef: null,
          actionVersionComment: null,
          workflowFileName,
          repo,
          type: 'container-image',
        });
      }
    }

    // Check for job-level services / sidecars
    const services = job['services'] as Record<string, unknown> | undefined;
    if (services && typeof services === 'object') {
      for (const [, serviceValue] of Object.entries(services)) {
        let serviceImage: string | null = null;
        if (typeof serviceValue === 'string') {
          serviceImage = serviceValue;
        } else if (typeof serviceValue === 'object' && serviceValue !== null && (serviceValue as Record<string, unknown>)['image']) {
          serviceImage = (serviceValue as Record<string, unknown>)['image'] as string;
        }
        if (serviceImage && serviceImage.length > 0) {
          actions.push({
            actionLink: serviceImage,
            actionRef: null,
            actionVersionComment: null,
            workflowFileName,
            repo,
            type: 'container-image',
          });
        }
      }
    }

    // Check steps
    const steps = job['steps'] as Array<Record<string, unknown>> | undefined;
    if (steps && Array.isArray(steps)) {
      for (const step of steps) {
        const uses = step['uses'] as string | undefined;
        if (uses) {
          if (uses.startsWith('docker://')) {
            actions.push({
              actionLink: uses,
              actionRef: null,
              actionVersionComment: null,
              workflowFileName,
              repo,
              type: 'container-image',
            });
          } else {
            const splitted = uses.split('@');
            const actionLink = splitted[0];
            const actionRef = splitted[1] ?? null;
            const actionVersionComment = splitted[2] ?? null;

            actions.push({
              actionLink,
              actionRef,
              actionVersionComment,
              workflowFileName,
              repo,
              type: 'action',
            });
          }
        }
      }
    } else {
      // No steps — check for reusable workflow
      const uses = job['uses'] as string | undefined;
      if (uses) {
        const splitted = uses.split('@');
        const actionLink = splitted[0];
        const actionRef = splitted[1] ?? null;
        const actionVersionComment = splitted[2] ?? null;

        actions.push({
          actionLink,
          actionRef,
          actionVersionComment,
          workflowFileName,
          repo,
          type: 'reusable workflow',
        });
      }
    }
  }

  return actions;
}

/**
 * Extract actions from a composite action YAML file.
 */
export function getActionsFromCompositeAction(
  yamlContent: string,
  fileName: string,
  repo: string
): ActionReference[] {
  let parsedYaml: Record<string, unknown>;
  try {
    parsedYaml = yaml.load(yamlContent) as Record<string, unknown>;
  } catch {
    console.warn(`Error parsing composite action file: [${fileName}] in repo: [${repo}]`);
    return [];
  }

  if (!parsedYaml || typeof parsedYaml !== 'object') {
    return [];
  }

  const actions: ActionReference[] = [];
  const runs = parsedYaml['runs'] as Record<string, unknown> | undefined;
  if (!runs) return actions;

  const using = runs['using'] as string | undefined;
  if (using !== 'composite') return actions;

  const steps = runs['steps'] as Array<Record<string, unknown>> | undefined;
  if (!steps || !Array.isArray(steps)) return actions;

  for (const step of steps) {
    const uses = step['uses'] as string | undefined;
    if (uses) {
      if (uses.startsWith('docker://')) {
        actions.push({
          actionLink: uses,
          actionRef: null,
          actionVersionComment: null,
          workflowFileName: fileName,
          repo,
          type: 'container-image',
        });
      } else {
        const splitted = uses.split('@');
        actions.push({
          actionLink: splitted[0],
          actionRef: splitted[1] ?? null,
          actionVersionComment: splitted[2] ?? null,
          workflowFileName: fileName,
          repo,
          type: 'action',
        });
      }
    }
  }

  return actions;
}

/**
 * Summarize actions usage — group by actionLink + type, count occurrences, collect workflow references.
 */
export function summarizeActionsUsed(actions: ActionReference[]): SummarizedAction[] {
  const summarized: SummarizedAction[] = [];

  for (const action of actions) {
    const found = summarized.find(
      (s) => s.actionLink === action.actionLink && s.type === action.type
    );

    const workflowRef: WorkflowReference = {
      repo: action.repo,
      workflowFileName: action.workflowFileName,
      actionRef: action.actionRef,
      actionVersionComment: action.actionVersionComment,
    };

    if (found) {
      found.workflows.push(workflowRef);
      found.count++;
    } else {
      summarized.push({
        type: action.type,
        actionLink: action.actionLink,
        count: 1,
        workflows: [workflowRef],
      });
    }
  }

  return summarized;
}
