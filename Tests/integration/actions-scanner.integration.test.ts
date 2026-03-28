import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import { getActionsFromWorkflow, getActionsFromCompositeAction } from '../../src/actions-scanner';

const fixturesDir = path.join(__dirname, '..', '..', 'Tests', 'Files');

function readFixture(filename: string): string {
  return fs.readFileSync(path.join(fixturesDir, filename), 'utf-8');
}

describe('getActionsFromWorkflow - integration with fixture files', () => {
  it('should parse extra-indentation.yml without error and find actions', () => {
    const yaml = readFixture('extra-indentation.yml');
    const result = getActionsFromWorkflow(yaml, 'extra-indentation.yml', 'test-org/test-repo');

    expect(result.length).toBeGreaterThan(0);
    expect(result).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          actionLink: 'actions/checkout',
          actionRef: 'v2',
          type: 'action',
        }),
      ])
    );
  });

  it('should find 1 action step in normal-indentation.yml', () => {
    const yaml = readFixture('normal-indentation.yml');
    const result = getActionsFromWorkflow(yaml, 'normal-indentation.yml', 'test-org/test-repo');

    // 1 action: actions/checkout@v2
    const actions = result.filter((r) => r.type === 'action');
    expect(actions).toHaveLength(1);
    expect(actions[0].actionLink).toBe('actions/checkout');
    expect(actions[0].actionRef).toBe('v2');
    expect(actions[0].workflowFileName).toBe('normal-indentation.yml');
    expect(actions[0].repo).toBe('test-org/test-repo');
  });

  it('should handle rajbos-actions-demo_deploy-cloudrun.yml with 4 jobs and correct step counts', () => {
    const yaml = readFixture('rajbos-actions-demo_deploy-cloudrun.yml');
    const result = getActionsFromWorkflow(
      yaml,
      'deploy-cloudrun-credentials-it.yml',
      'rajbos-actions-demo/deploy-cloudrun'
    );

    // Count actions per job:
    // gcloud: checkout@v2, setup-node@master, setup-gcloud@master, ./ = 4
    // b64_json: checkout@v2, setup-node@master, ./, setup-gcloud@master = 4
    // json: checkout@v2, setup-node@master, ./, setup-gcloud@master = 4
    // cleanup: setup-gcloud@master = 1
    // Total: 13
    expect(result).toHaveLength(13);

    // Verify specific actions
    const checkoutActions = result.filter((a) => a.actionLink === 'actions/checkout');
    expect(checkoutActions).toHaveLength(3);

    const setupNodeActions = result.filter((a) => a.actionLink === 'actions/setup-node');
    expect(setupNodeActions).toHaveLength(3);

    const gcloudActions = result.filter(
      (a) => a.actionLink === 'google-github-actions/setup-gcloud'
    );
    expect(gcloudActions).toHaveLength(4);

    const localActions = result.filter((a) => a.actionLink === './');
    expect(localActions).toHaveLength(3);
  });

  it('should correctly parse container-images.yml', () => {
    const yaml = readFixture('container-images.yml');
    const result = getActionsFromWorkflow(yaml, 'container-images.yml', 'test-org/test-repo');

    const containerImages = result.filter((r) => r.type === 'container-image');
    const actions = result.filter((r) => r.type === 'action');

    // 5 container images: node:18-alpine, redis:7, postgres:15, docker://ghcr.io/..., python:3.12-slim
    expect(containerImages).toHaveLength(5);

    const imageLinks = containerImages.map((c) => c.actionLink);
    expect(imageLinks).toContain('node:18-alpine');
    expect(imageLinks).toContain('redis:7');
    expect(imageLinks).toContain('postgres:15');
    expect(imageLinks).toContain('docker://ghcr.io/some-org/some-tool:latest');
    expect(imageLinks).toContain('python:3.12-slim');

    // 2 regular actions (actions/checkout@v4 used twice)
    expect(actions).toHaveLength(2);
    expect(actions.every((a) => a.actionLink === 'actions/checkout')).toBe(true);
    expect(actions.every((a) => a.actionRef === 'v4')).toBe(true);
  });
});

describe('getActionsFromCompositeAction - integration with fixture files', () => {
  it('should find 3 actions and 1 container image in composite-action.yml', () => {
    const yaml = readFixture('composite-action.yml');
    const result = getActionsFromCompositeAction(yaml, 'action.yml', 'test-org/test-repo');

    const actions = result.filter((r) => r.type === 'action');
    const containerImages = result.filter((r) => r.type === 'container-image');

    // 3 actions: checkout, setup-node, cache
    expect(actions).toHaveLength(3);
    expect(actions.map((a) => a.actionLink)).toEqual(
      expect.arrayContaining(['actions/checkout', 'actions/setup-node', 'actions/cache'])
    );

    // 1 container image: docker://alpine:3.18
    expect(containerImages).toHaveLength(1);
    expect(containerImages[0].actionLink).toBe('docker://alpine:3.18');
  });

  it('should return empty array for a workflow file (not a composite action)', () => {
    const yaml = readFixture('normal-indentation.yml');
    const result = getActionsFromCompositeAction(yaml, 'build.yml', 'test-org/test-repo');

    expect(result).toHaveLength(0);
  });
});
