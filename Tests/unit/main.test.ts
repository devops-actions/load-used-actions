import { describe, it, expect, vi, beforeEach } from 'vitest';
import { resolveCompositeActionsRecursively, MAX_COMPOSITE_NESTING_DEPTH } from '../../src/main';

// ─── helpers ────────────────────────────────────────────────────────────────

function createMockOctokit() {
  return {
    paginate: vi.fn(),
    repos: {
      listForOrg: vi.fn(),
      listForUser: vi.fn(),
      getContent: vi.fn(),
    },
  } as any;
}

/** Build a minimal composite-action YAML string. */
function compositeYaml(uses: string[]): string {
  const steps = uses
    .map((u) => `      - uses: ${u}`)
    .join('\n');
  return `name: test\nruns:\n  using: composite\n  steps:\n${steps}\n`;
}

/** Build a minimal node20-action YAML (non-composite). */
const node20Yaml = `name: node action\nruns:\n  using: node20\n  main: dist/index.js\n`;

// ─── mocks for github-client & actions-scanner ──────────────────────────────

vi.mock('../../src/github-client', () => ({
  getFileInfo: vi.fn(),
  getRawFile: vi.fn(),
  createOctokit: vi.fn(),
  findAllRepos: vi.fn(),
  getAllFilesInPath: vi.fn(),
}));

import { getFileInfo, getRawFile } from '../../src/github-client';

const mockGetFileInfo = vi.mocked(getFileInfo);
const mockGetRawFile = vi.mocked(getRawFile);

// ─── tests ──────────────────────────────────────────────────────────────────

describe('resolveCompositeActionsRecursively', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns empty array when repo has no action.yml or action.yaml', async () => {
    mockGetFileInfo.mockResolvedValue(null);

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'repo', 0, new Set()
    );

    expect(result).toHaveLength(0);
  });

  it('returns empty array for a non-composite action (node20)', async () => {
    mockGetFileInfo.mockResolvedValue({
      name: 'action.yml',
      download_url: 'https://example.com/action.yml',
      path: 'action.yml',
      type: 'file',
    });
    mockGetRawFile.mockResolvedValue(node20Yaml);

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'repo', 0, new Set()
    );

    expect(result).toHaveLength(0);
  });

  it('returns direct actions from a composite action with no nested composites', async () => {
    mockGetFileInfo.mockResolvedValue({
      name: 'action.yml',
      download_url: 'https://example.com/action.yml',
      path: 'action.yml',
      type: 'file',
    });
    // Root composite uses actions/checkout@v4 (not a composite action itself)
    mockGetRawFile
      .mockResolvedValueOnce(compositeYaml(['actions/checkout@v4']))
      // actions/checkout@v4 is a node20 action, not composite
      .mockResolvedValueOnce(node20Yaml);

    // First call: root action.yml found; second call: actions/checkout action.yml found (node20)
    mockGetFileInfo
      .mockResolvedValueOnce({
        name: 'action.yml',
        download_url: 'https://example.com/action.yml',
        path: 'action.yml',
        type: 'file',
      })
      .mockResolvedValueOnce({
        name: 'action.yml',
        download_url: 'https://example.com/checkout/action.yml',
        path: 'action.yml',
        type: 'file',
      });

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'my-composite', 0, new Set()
    );

    expect(result).toHaveLength(1);
    expect(result[0].actionLink).toBe('actions/checkout');
    expect(result[0].actionRef).toBe('v4');
    expect(result[0].repo).toBe('org/my-composite');
  });

  it('resolves nested composite actions transitively', async () => {
    // org/action-a -> org/action-b@v1 -> actions/checkout@v3
    //
    // action-a/action.yml  – composite, uses org/action-b@v1
    // action-b/action.yml  – composite, uses actions/checkout@v3
    // checkout/action.yml  – node20, no further nesting

    mockGetFileInfo
      // depth 0: org/action-a
      .mockResolvedValueOnce({ name: 'action.yml', download_url: 'url-a', path: 'action.yml', type: 'file' })
      // depth 1: org/action-b (reached from action-a's uses)
      .mockResolvedValueOnce({ name: 'action.yml', download_url: 'url-b', path: 'action.yml', type: 'file' })
      // depth 2: actions/checkout (reached from action-b's uses)
      .mockResolvedValueOnce({ name: 'action.yml', download_url: 'url-checkout', path: 'action.yml', type: 'file' });

    mockGetRawFile
      .mockResolvedValueOnce(compositeYaml(['org/action-b@v1']))   // action-a
      .mockResolvedValueOnce(compositeYaml(['actions/checkout@v3'])) // action-b
      .mockResolvedValueOnce(node20Yaml);                            // checkout (not composite)

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'action-a', 0, new Set()
    );

    // Should include: org/action-b (from action-a) + actions/checkout (from action-b)
    expect(result).toHaveLength(2);
    const links = result.map((r) => r.actionLink);
    expect(links).toContain('org/action-b');
    expect(links).toContain('actions/checkout');
  });

  it('respects the visited set to prevent infinite loops', async () => {
    // action-a uses action-b, action-b uses action-a (cycle)
    // The cycle guard stops recursion but the action-a *reference* from action-b's
    // steps is still collected as an ActionReference (we stop recursing into it, not
    // stop recording it).
    mockGetFileInfo
      .mockResolvedValueOnce({ name: 'action.yml', download_url: 'url-a', path: 'action.yml', type: 'file' })
      .mockResolvedValueOnce({ name: 'action.yml', download_url: 'url-b', path: 'action.yml', type: 'file' });

    mockGetRawFile
      .mockResolvedValueOnce(compositeYaml(['org/action-b@v1']))  // action-a
      .mockResolvedValueOnce(compositeYaml(['org/action-a@v1'])); // action-b

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'action-a', 0, new Set()
    );

    // action-b (from action-a) and action-a ref (from action-b) are both collected;
    // the cycle guard prevents a third fetch (no infinite loop).
    expect(result).toHaveLength(2);
    const links = result.map((r) => r.actionLink);
    expect(links).toContain('org/action-b');
    expect(links).toContain('org/action-a');
    // getRawFile called exactly twice (action-a and action-b), not a third time
    expect(mockGetRawFile).toHaveBeenCalledTimes(2);
  });

  it('stops recursion when depth exceeds MAX_COMPOSITE_NESTING_DEPTH', async () => {
    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'repo', MAX_COMPOSITE_NESTING_DEPTH + 1, new Set()
    );

    expect(result).toHaveLength(0);
    expect(mockGetFileInfo).not.toHaveBeenCalled();
  });

  it('falls back to action.yaml when action.yml is not found', async () => {
    mockGetFileInfo
      // action.yml not found
      .mockResolvedValueOnce(null)
      // action.yaml found
      .mockResolvedValueOnce({ name: 'action.yaml', download_url: 'url-yaml', path: 'action.yaml', type: 'file' });

    mockGetRawFile.mockResolvedValue(compositeYaml(['actions/setup-node@v4']));
    // actions/setup-node has no composite action
    mockGetFileInfo
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'repo', 0, new Set()
    );

    expect(result).toHaveLength(1);
    expect(result[0].actionLink).toBe('actions/setup-node');
    expect(result[0].workflowFileName).toBe('action.yaml');
  });

  it('skips docker:// references when recursing (no action.yml to follow)', async () => {
    mockGetFileInfo.mockResolvedValueOnce({
      name: 'action.yml',
      download_url: 'url',
      path: 'action.yml',
      type: 'file',
    });
    mockGetRawFile.mockResolvedValue(compositeYaml(['docker://node:18-alpine']));

    const result = await resolveCompositeActionsRecursively(
      createMockOctokit(), 'token', 'org', 'repo', 0, new Set()
    );

    // docker:// reference is collected as container-image but not recursed into
    expect(result).toHaveLength(1);
    expect(result[0].type).toBe('container-image');
    expect(result[0].actionLink).toBe('docker://node:18-alpine');
    // No further getFileInfo calls for the docker reference
    expect(mockGetFileInfo).toHaveBeenCalledTimes(1);
  });
});

// ─── basic input validation tests (kept from original file) ─────────────────

describe('main - input defaults and validation', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('should use GITHUB_REPOSITORY_OWNER when organization input is empty', async () => {
    const testEnv = 'test-org';
    const result = '' || testEnv || '';
    expect(result).toBe('test-org');
  });

  it('should use GITHUB_TOKEN when PAT input is empty', async () => {
    const testToken = 'ghp_test123';
    const result = '' || testToken || '';
    expect(result).toBe('ghp_test123');
  });

  it('should treat include-archived-repositories as true by default', () => {
    const includeArchivedInput = 'true';
    const includeArchived = includeArchivedInput !== 'false';
    expect(includeArchived).toBe(true);
  });

  it('should set includeArchived to false when input is "false"', () => {
    const includeArchivedInput = 'false';
    const includeArchived = includeArchivedInput !== 'false';
    expect(includeArchived).toBe(false);
  });

  it('should treat non-"false" values as truthy for includeArchived', () => {
    for (const value of ['true', 'True', 'yes', '1', '']) {
      const includeArchived = value !== 'false';
      expect(includeArchived).toBe(true);
    }
  });
});
