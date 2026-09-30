create or replace package xxcus.xxcmp_case_pkg authid definer as

    -- Opens the case of a request and starts the KYC_CASE workflow.
    function create_case (
        p_request_id  in number,
        p_assigned_to in varchar2 default null
    ) return number;
    -- A case opened by an officer without an intake request (a request is recorded for the trail).
    function create_manual_case (
        p_party_id      in number,
        p_justification in varchar2
    ) return number;

    procedure assign (
        p_case_id   in number,
        p_user_name in varchar2
    );

    -- Task participants.
    function investigation_owners (
        p_case_id in number
    ) return varchar2;

    function level_approvers (
        p_case_id in number
    ) return varchar2;

    -- Approval levels from the approval matrix (risk tier; Enhanced KYC needs two).
    function required_levels (
        p_case_id in number
    ) return number;

    function level_role (
        p_case_id in number,
        p_level   in number
    ) return varchar2;

    function sar_gate (
        p_case_id in number
    ) return varchar2;

    -- Y when the case is under investigation and the user may manage cases (Case page read-only otherwise).
    function is_editable (
        p_case_id in number
    ) return varchar2;

    -- Investigation -> approval.
    function submit_error (
        p_case_id in number
    ) return varchar2;

    procedure submit_for_approval (
        p_case_id in number
    );

    -- Approval (CASE_APPROVAL task actions and the decision page).
    function approval_error (
        p_case_id in number
    ) return varchar2;

    procedure record_decision (
        p_case_id  in number,
        p_outcome  in varchar2,
        p_comments in varchar2,
        p_task_id  in number
    );

    function next_review_date (
        p_case_id in number
    ) return date;

    -- Workflow steps (KYC_CASE).
    procedure start_approval (
        p_case_id in number
    );

    function has_next_level (
        p_case_id in number
    ) return varchar2;

    procedure approve_case (
        p_case_id in number
    );

    procedure reject_case (
        p_case_id in number
    );

    -- Screening results: a confirmed match or PEP flag forces Enhanced KYC.
    procedure apply_screening (
        p_case_id in number
    );

end xxcmp_case_pkg;
/


-- sqlcl_snapshot {"hash":"7bf0f86ac2857466538a11d1aceb4745c039ecbe","type":"PACKAGE_SPEC","name":"XXCMP_CASE_PKG","schemaName":"XXCUS","sxml":""}