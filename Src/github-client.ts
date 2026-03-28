import { Octokit } from '@octokit/rest';
import { Repository, FileInfo } from './types';

/**
 * Create an authenticated Octokit client. Supports GITHUB_API_URL for GitHub Enterprise.
 */
export function createOctokit(pat: string): Octokit {
  const baseUrl = process.env.GITHUB_API_URL || 'https://api.github.com';
  return new Octokit({
    auth: pat,
    baseUrl,
  });
}

/**
 * Find all repositories in an org or user account.
 * Tries org endpoint first, falls back to user repos if 404.
 */
export async function findAllRepos(
  octokit: Octokit,
  orgName: string,
  includeArchived: boolean
): Promise<Repository[]> {
  let repos: Repository[];

  try {
    const orgRepos = await octokit.paginate(octokit.repos.listForOrg, {
      org: orgName,
      per_page: 100,
    });
    repos = orgRepos.map((r) => ({
      full_name: r.full_name,
      archived: r.archived ?? false,
    }));
  } catch (error: unknown) {
    const status = (error as { status?: number }).status;
    if (status === 404) {
      console.log(`Org [${orgName}] not found, trying user repos`);
      const userRepos = await octokit.paginate(octokit.repos.listForUser, {
        username: orgName,
        per_page: 100,
      });
      repos = userRepos.map((r) => ({
        full_name: r.full_name,
        archived: r.archived ?? false,
      }));
    } else {
      throw error;
    }
  }

  if (!includeArchived) {
    const archivedCount = repos.filter((r) => r.archived).length;
    repos = repos.filter((r) => !r.archived);
    console.log(`Filtered out [${archivedCount}] archived repositories`);
  }

  console.log(`Found [${repos.length}] repositories in [${orgName}]`);
  return repos;
}

/**
 * Get all files in a repository path (e.g., .github/workflows).
 */
export async function getAllFilesInPath(
  octokit: Octokit,
  owner: string,
  repo: string,
  path: string
): Promise<FileInfo[]> {
  try {
    const response = await octokit.repos.getContent({
      owner,
      repo,
      path,
    });

    if (!Array.isArray(response.data)) {
      return [];
    }

    return response.data.map((item) => ({
      name: item.name,
      download_url: item.download_url ?? null,
      path: item.path,
      type: item.type,
    }));
  } catch {
    return [];
  }
}

/**
 * Get info about a single file. Returns null on 404.
 */
export async function getFileInfo(
  octokit: Octokit,
  owner: string,
  repo: string,
  path: string
): Promise<FileInfo | null> {
  try {
    const response = await octokit.repos.getContent({
      owner,
      repo,
      path,
    });

    if (Array.isArray(response.data)) {
      return null;
    }

    return {
      name: response.data.name,
      download_url: response.data.download_url ?? null,
      path: response.data.path,
      type: response.data.type,
    };
  } catch {
    return null;
  }
}

/**
 * Download raw file content. Strips empty lines for YAML consistency.
 */
export async function getRawFile(url: string, pat: string): Promise<string> {
  const response = await fetch(url, {
    headers: {
      Authorization: `token ${pat}`,
      'User-Agent': 'load-used-actions',
    },
  });

  if (!response.ok) {
    console.warn(`Error loading file from url [${url.split('?')[0]}]`);
    return '';
  }

  const content = await response.text();

  // Remove empty lines (lines with only whitespace/tabs) to prevent YAML parsing issues
  const lines = content.split('\n');
  const filtered = lines.filter((line) => {
    const trimmed = line.replace(/\t/g, '').replace(/ /g, '');
    return trimmed.length > 0;
  });

  return filtered.join('\n');
}
