import { ActionReference } from './types';
import { Octokit } from '@octokit/rest';
/** Maximum composite-action nesting depth (mirrors the GitHub Actions runner limit). */
export declare const MAX_COMPOSITE_NESTING_DEPTH = 9;
/**
 * Recursively resolve all actions used by a composite action at owner/repoName,
 * following nested composite action references up to MAX_COMPOSITE_NESTING_DEPTH levels deep.
 *
 * @param octokit   Authenticated Octokit instance
 * @param pat       Personal access token for raw-file downloads
 * @param owner     Repository owner (org or user)
 * @param repoName  Repository name
 * @param depth     Current recursion depth (0 = root call)
 * @param visited   Set of "owner/repo" strings already processed (cycle guard)
 * @returns All ActionReference objects found at this level and below
 */
export declare function resolveCompositeActionsRecursively(octokit: Octokit, pat: string, owner: string, repoName: string, depth: number, visited: Set<string>): Promise<ActionReference[]>;
export declare function run(): Promise<void>;
