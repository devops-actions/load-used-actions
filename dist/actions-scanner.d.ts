import { ActionReference, SummarizedAction } from './types';
/**
 * Extract actions, reusable workflows, and container images from a workflow YAML file.
 */
export declare function getActionsFromWorkflow(yamlContent: string, workflowFileName: string, repo: string): ActionReference[];
/**
 * Extract actions from a composite action YAML file.
 */
export declare function getActionsFromCompositeAction(yamlContent: string, fileName: string, repo: string): ActionReference[];
/**
 * Summarize actions usage — group by actionLink + type, count occurrences, collect workflow references.
 */
export declare function summarizeActionsUsed(actions: ActionReference[]): SummarizedAction[];
