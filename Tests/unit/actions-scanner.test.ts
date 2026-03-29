import { describe, it, expect } from 'vitest';
import {
  getActionsFromWorkflow,
  getActionsFromCompositeAction,
  summarizeActionsUsed,
} from '../../src/actions-scanner';
import { ActionReference } from '../../src/types';

describe('summarizeActionsUsed', () => {
  it('should aggregate actions by actionLink + type', () => {
    const actions: ActionReference[] = [
      {
        actionLink: 'actions/checkout',
        actionRef: 'v3',
        actionVersionComment: null,
        workflowFileName: 'build.yml',
        repo: 'org/repo1',
        type: 'action',
      },
      {
        actionLink: 'actions/checkout',
        actionRef: 'v4',
        actionVersionComment: null,
        workflowFileName: 'deploy.yml',
        repo: 'org/repo2',
        type: 'action',
      },
      {
        actionLink: 'actions/setup-node',
        actionRef: 'v3',
        actionVersionComment: null,
        workflowFileName: 'build.yml',
        repo: 'org/repo1',
        type: 'action',
      },
    ];

    const result = summarizeActionsUsed(actions);

    expect(result).toHaveLength(2);

    const checkoutSummary = result.find((s) => s.actionLink === 'actions/checkout');
    expect(checkoutSummary).toBeDefined();
    expect(checkoutSummary!.count).toBe(2);
    expect(checkoutSummary!.type).toBe('action');
    expect(checkoutSummary!.workflows).toHaveLength(2);
    expect(checkoutSummary!.workflows[0].repo).toBe('org/repo1');
    expect(checkoutSummary!.workflows[1].repo).toBe('org/repo2');

    const setupNodeSummary = result.find((s) => s.actionLink === 'actions/setup-node');
    expect(setupNodeSummary).toBeDefined();
    expect(setupNodeSummary!.count).toBe(1);
  });

  it('should treat same actionLink with different type as separate entries', () => {
    const actions: ActionReference[] = [
      {
        actionLink: 'node:18',
        actionRef: null,
        actionVersionComment: null,
        workflowFileName: 'build.yml',
        repo: 'org/repo1',
        type: 'container-image',
      },
      {
        actionLink: 'node:18',
        actionRef: null,
        actionVersionComment: null,
        workflowFileName: 'deploy.yml',
        repo: 'org/repo2',
        type: 'container-image',
      },
    ];

    const result = summarizeActionsUsed(actions);
    expect(result).toHaveLength(1);
    expect(result[0].count).toBe(2);
  });

  it('should return empty array for empty input', () => {
    const result = summarizeActionsUsed([]);
    expect(result).toHaveLength(0);
  });
});

describe('getActionsFromWorkflow - unit tests with inline YAML', () => {
  it('should return empty for empty workflow (no jobs)', () => {
    const yaml = `name: Empty\non: push\n`;
    const result = getActionsFromWorkflow(yaml, 'empty.yml', 'org/repo');
    expect(result).toHaveLength(0);
  });

  it('should return empty for job with no steps and no uses', () => {
    const yaml = `
name: NoSteps
on: push
jobs:
  build:
    runs-on: ubuntu-latest
`;
    const result = getActionsFromWorkflow(yaml, 'nosteps.yml', 'org/repo');
    expect(result).toHaveLength(0);
  });

  it('should handle action with version comment after @', () => {
    const yaml = `
name: VersionComment
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@abc123 # v4
`;
    const result = getActionsFromWorkflow(yaml, 'comment.yml', 'org/repo');
    // js-yaml will parse "actions/checkout@abc123 # v4" as the full string including the comment
    // But actually, YAML treats # as a comment when preceded by a space
    // So the value of uses is "actions/checkout@abc123"
    expect(result).toHaveLength(1);
    expect(result[0].actionLink).toBe('actions/checkout');
    expect(result[0].actionRef).toBe('abc123');
    expect(result[0].type).toBe('action');
  });

  it('should handle docker:// reference in step', () => {
    const yaml = `
name: Docker
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: docker://node:18-alpine
`;
    const result = getActionsFromWorkflow(yaml, 'docker.yml', 'org/repo');
    expect(result).toHaveLength(1);
    expect(result[0].actionLink).toBe('docker://node:18-alpine');
    expect(result[0].type).toBe('container-image');
    expect(result[0].actionRef).toBeNull();
  });

  it('should handle reusable workflow', () => {
    const yaml = `
name: Reusable
on: push
jobs:
  call-workflow:
    uses: org/repo/.github/workflows/reusable.yml@main
`;
    const result = getActionsFromWorkflow(yaml, 'caller.yml', 'org/caller-repo');
    expect(result).toHaveLength(1);
    expect(result[0].actionLink).toBe('org/repo/.github/workflows/reusable.yml');
    expect(result[0].actionRef).toBe('main');
    expect(result[0].type).toBe('reusable workflow');
  });
});

describe('getActionsFromCompositeAction - unit tests', () => {
  it('should return empty for non-composite action (using: node20)', () => {
    const yaml = `
name: Node Action
runs:
  using: 'node20'
  main: 'dist/index.js'
`;
    const result = getActionsFromCompositeAction(yaml, 'action.yml', 'org/repo');
    expect(result).toHaveLength(0);
  });

  it('should return empty for composite action with no steps', () => {
    const yaml = `
name: Empty Composite
runs:
  using: 'composite'
`;
    const result = getActionsFromCompositeAction(yaml, 'action.yml', 'org/repo');
    expect(result).toHaveLength(0);
  });

  it('should return empty for invalid YAML', () => {
    const result = getActionsFromCompositeAction('{{{{invalid', 'action.yml', 'org/repo');
    expect(result).toHaveLength(0);
  });
});
