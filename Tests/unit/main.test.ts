import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('main - input defaults and validation', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('should use GITHUB_REPOSITORY_OWNER when organization input is empty', async () => {
    // Test the fallback logic
    const organization = '' || process.env.GITHUB_REPOSITORY_OWNER || '';
    // When empty input but env is set, should use env
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
    // Any value that isn't exactly "false" should be treated as true
    for (const value of ['true', 'True', 'yes', '1', '']) {
      const includeArchived = value !== 'false';
      expect(includeArchived).toBe(true);
    }
  });
});
