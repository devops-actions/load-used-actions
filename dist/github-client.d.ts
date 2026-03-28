import { Octokit } from '@octokit/rest';
import { Repository, FileInfo } from './types';
/**
 * Create an authenticated Octokit client. Supports GITHUB_API_URL for GitHub Enterprise.
 */
export declare function createOctokit(pat: string): Octokit;
/**
 * Find all repositories in an org or user account.
 * Tries org endpoint first, falls back to user repos if 404.
 */
export declare function findAllRepos(octokit: Octokit, orgName: string, includeArchived: boolean): Promise<Repository[]>;
/**
 * Get all files in a repository path (e.g., .github/workflows).
 */
export declare function getAllFilesInPath(octokit: Octokit, owner: string, repo: string, path: string): Promise<FileInfo[]>;
/**
 * Get info about a single file. Returns null on 404.
 */
export declare function getFileInfo(octokit: Octokit, owner: string, repo: string, path: string): Promise<FileInfo | null>;
/**
 * Download raw file content. Strips empty lines for YAML consistency.
 */
export declare function getRawFile(url: string, pat: string): Promise<string>;
