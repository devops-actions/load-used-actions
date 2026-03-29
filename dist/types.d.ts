export interface ActionReference {
    actionLink: string;
    actionRef: string | null;
    actionVersionComment: string | null;
    workflowFileName: string;
    repo: string;
    type: 'action' | 'reusable workflow' | 'container-image';
}
export interface SummarizedAction {
    type: string;
    actionLink: string;
    count: number;
    workflows: WorkflowReference[];
}
export interface WorkflowReference {
    repo: string;
    workflowFileName: string;
    actionRef: string | null;
    actionVersionComment: string | null;
}
export interface Repository {
    full_name: string;
    archived: boolean;
}
export interface FileInfo {
    name: string;
    download_url: string | null;
    path: string;
    type: string;
}
