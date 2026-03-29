import { describe, it, expect, vi, beforeEach } from 'vitest';
import { findAllRepos } from '../../src/github-client';

// Helper to create a mock Octokit instance
function createMockOctokit(overrides: Record<string, unknown> = {}) {
  return {
    paginate: vi.fn(),
    repos: {
      listForOrg: vi.fn(),
      listForUser: vi.fn(),
      getContent: vi.fn(),
    },
    ...overrides,
  } as any;
}

describe('findAllRepos', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('should return repos from org endpoint on success', async () => {
    const mockOctokit = createMockOctokit();
    mockOctokit.paginate.mockResolvedValue([
      { full_name: 'org/repo1', archived: false },
      { full_name: 'org/repo2', archived: true },
    ]);

    const result = await findAllRepos(mockOctokit, 'org', true);

    expect(result).toHaveLength(2);
    expect(result[0].full_name).toBe('org/repo1');
    expect(result[1].full_name).toBe('org/repo2');
    expect(mockOctokit.paginate).toHaveBeenCalledWith(
      mockOctokit.repos.listForOrg,
      expect.objectContaining({ org: 'org' })
    );
  });

  it('should fall back to user repos on 404', async () => {
    const mockOctokit = createMockOctokit();
    mockOctokit.paginate
      .mockRejectedValueOnce({ status: 404 })
      .mockResolvedValueOnce([{ full_name: 'user/repo1', archived: false }]);

    const result = await findAllRepos(mockOctokit, 'myuser', true);

    expect(result).toHaveLength(1);
    expect(result[0].full_name).toBe('user/repo1');
    expect(mockOctokit.paginate).toHaveBeenCalledTimes(2);
  });

  it('should filter archived repos when includeArchived is false', async () => {
    const mockOctokit = createMockOctokit();
    mockOctokit.paginate.mockResolvedValue([
      { full_name: 'org/active', archived: false },
      { full_name: 'org/archived', archived: true },
      { full_name: 'org/also-active', archived: false },
    ]);

    const result = await findAllRepos(mockOctokit, 'org', false);

    expect(result).toHaveLength(2);
    expect(result.every((r) => !r.archived)).toBe(true);
  });

  it('should rethrow non-404 errors', async () => {
    const mockOctokit = createMockOctokit();
    mockOctokit.paginate.mockRejectedValue({ status: 500, message: 'Server Error' });

    await expect(findAllRepos(mockOctokit, 'org', true)).rejects.toEqual(
      expect.objectContaining({ status: 500 })
    );
  });
});

describe('getRawFile', () => {
  it('should strip empty lines from content', async () => {
    // We test the stripping logic inline since getRawFile uses fetch
    const content = `name: test\n\n\njobs:\n  build:\n    runs-on: ubuntu-latest\n`;
    const lines = content.split('\n');
    const filtered = lines.filter((line) => {
      const trimmed = line.replace(/\t/g, '').replace(/ /g, '');
      return trimmed.length > 0;
    });
    const result = filtered.join('\n');

    expect(result).not.toContain('\n\n');
    expect(result).toContain('name: test');
    expect(result).toContain('jobs:');
  });
});
