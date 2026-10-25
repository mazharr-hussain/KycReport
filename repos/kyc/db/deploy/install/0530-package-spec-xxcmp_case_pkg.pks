
create or replace package xxcmp_case_pkg authid definer as

    -- Release 91: a numeric KYC parameter (CASE_SLA_DAYS, PEP_REVIEW_MONTHS, REVIEW_LEAD_DAYS). It is a KYC application
    -- setting; while the setting is empty, the value an administrator kept in the old lookup KYC_PARAMETER (TAG)
    -- applies, then P_DEFAULT. Read from the APEX dictionary, so it also works without an APEX session (views).
    function parameter(p_name in varchar2, p_default in number) return number;

    -- Opens the case of a request and starts the KYC_CASE workflow.
    function create_case(p_request_id in number, p_assigned_to in varchar2 default null) return number;
    -- A case opened by an officer without an intake request (a request is recorded for the trail).
    function create_manual_case(p_party_id in number, p_justification in varchar2) return number;

    procedure assign(p_case_id in number, p_user_name in varchar2, p_comment in varchar2 default null);
    -- Assign on the case and request screens: the Case Assignment privilege (release 76; before: Manage on Cases or the
    -- assignee) and a business administrator of the open investigation task (APEX lets only them move it).
    function can_assign(p_case_id in number) return varchar2;
    -- Release 75: Y when the user may be given a case (an active Compliance officer, manager or head of Compliance):
    -- the list of officers on the Assign screens and the check of a chosen officer.
    function is_case_officer(p_user_name in varchar2) return varchar2;
    -- The approver of the first step of the request's approval path (default assignee of its case).
    function first_approver(p_request_id in number) return varchar2;
    -- Withdraw from approval: back to investigation (the submitter or Manage on Cases, while Pending approval).
    function can_withdraw(p_case_id in number) return varchar2;
    procedure withdraw(p_case_id in number, p_reason in varchar2);

    -- Task participants.
    function investigation_owners(p_case_id in number) return varchar2;
    -- Release 75: business administrators of the investigation task - the workflow administrators and (release 76) the
    -- holders of Case Assignment, who may give the case (and its task) to another officer.
    function investigation_admins(p_case_id in number) return varchar2;
    function level_approvers(p_case_id in number) return varchar2;

    -- Approval levels from the approval matrix (risk tier; Enhanced KYC needs two).
    function required_levels(p_case_id in number) return number;
    function level_role(p_case_id in number, p_level in number) return varchar2;
    function sar_gate(p_case_id in number) return varchar2;

    -- Y when the case is under investigation and the user may manage cases (Case page read-only otherwise).
    function is_editable(p_case_id in number) return varchar2;

    -- Investigation -> approval.
    function submit_error(p_case_id in number) return varchar2;
    procedure submit_for_approval(p_case_id in number);

    -- Approval (CASE_APPROVAL task actions and the decision page).
    function approval_error(p_case_id in number) return varchar2;
    procedure record_decision(p_case_id in number, p_outcome in varchar2, p_comments in varchar2, p_task_id in number);
    -- The case approval history table (release 74: from XXCMP_APPROVAL_PKG): investigation, then each approval level
    -- (who, when, outcome, comments); the current level Pending and the levels to come Waiting (Expected while
    -- investigating), from the Approval Setup (KYC_CASE).
    function case_history_rows(p_case_id in number) return xxcmp_history_tab pipelined;
    -- CASE_APPROVAL task events: the approver asked the requester for information (Pending Information) / the
    -- requester submitted it (Pending Approval again).
    procedure info_requested(p_case_id in number);
    procedure info_submitted(p_case_id in number);
    -- The requester answers a case approver's question on their request screen (they cannot open cases): the case
    -- approval task of the request waiting for the current user's information, and the request of a case.
    function info_task(p_request_id in number) return number;
    function request_of(p_case_id in number) return number;
    function next_review_date(p_case_id in number) return date;

    -- Workflow steps (KYC_CASE).
    procedure start_approval(p_case_id in number);
    -- Release 76 (A-11): Y when the case goes to its approvers - the approval workflow is on and the matching Approval
    -- Setup rule has steps (a rule without steps approves the case at once). The KYC_CASE workflow (version 1.3) asks it.
    function approval_required(p_case_id in number) return varchar2;
    function has_next_level(p_case_id in number) return varchar2;
    -- Release 90: the decision that closes the case (APPROVE_CASE / REJECT_CASE were one routine twice).
    -- P_DECISION = APPROVED or REJECTED; the party's next KYC date follows (KYC_CASE workflow, trusted).
    procedure close_case(p_case_id in number, p_decision in varchar2);

    -- Screening results: a confirmed match or PEP flag forces Enhanced KYC.
    -- release 74: an RFI raised from a case (or its request / party) - its own workflow process (common RFI).
    -- p_recipient_type SETUP (default): the providers come from the Approval Setup (CASE_RFI, default the requester);
    -- REQUESTING_DEPARTMENT: a named user; EXTERNAL_PARTY: a contact person of the party (name and e-mail).
    -- release 89: COMMON's RFI process runs it (XXFND_RFI_PKG): a user answers and the raiser reviews on COMMON's task
    -- page Information Request (143); an outside person answers on COMMON's public page Provide Information (50).
    procedure raise_rfi(p_entity_name      in varchar2,
                        p_pk1_value        in varchar2,
                        p_recipient_type   in varchar2,
                        p_recipient_user   in varchar2,
                        p_party_contact_id in number,
                        p_rfi_category     in varchar2,
                        p_description      in varchar2,
                        p_continue_work    in varchar2,
                        p_due_date         in date);
    -- release 89: the open step of an RFI the signed-in user takes in COMMON's RFI process (the RFI_RESPONSE or RFI_REVIEW
    -- task of COMMON in the user's My Tasks), for the link to COMMON's task page 143; null when there is none.
    function rfi_task(p_rfi_id in number) return number;
    procedure apply_screening(p_case_id in number);

    -- Case screen (211, release 27): the sections an officer works through, in order.
    -- release 29: Contacts and Ownership merged into Party
    -- release 42: Ownership Tree (the whole ownership tree with each party's screening) after Party
    c_sections constant varchar2(200) := 'SUMMARY:PARTY:TREE:SCREENING:DOCUMENTS:RISK:NOTES:REVIEW';
    -- DONE, TODO or WARN (an open request for information) for one section.
    function section_state(p_case_id in number, p_section in varchar2) return varchar2;
    -- release 74 (R5, R11): data for the case screen's section menu (dynamic list CASE-SECTIONS on page 211), no HTML.
    -- The sections in order (c_sections, for SQL) and the progress "done / total".
    function sections return varchar2;
    function section_progress(p_case_id in number) return varchar2;
    -- The case summary (Summary, Review, and Risk when read only) for the standard Value Attribute Pairs report (R7, R11:
    -- moved from the request UI package, data only): JSON array [{"group_name","seq","label","value","tone","url",
    -- "link_text","user_name"}]; a missing required value has tone "missing" and links (url, link_text) to its section.
    function case_summary_json(p_case_id in number, p_task_id in number default null) return clob;

    -- release 74 (R14): screening by hand now, by a provider later. A person saved a provider row: it is marked as
    -- changed by a person (the original response stays unchanged); a person confirms a provider row (reviewed by).
    procedure screening_saved(p_screening_id in number);
    procedure review_screening(p_screening_id in number);
    -- release 74 (R14): FIU / goAML reports of the case. Prepared by the officer; approved by another Compliance
    -- manager (not the preparer); filed with the goAML reference and date. P_ACTION: APPROVE, FILE, CANCEL.
    function fiu_report_error(p_case_id in number, p_report_type in varchar2, p_grounds in varchar2) return varchar2;
    -- Y when the user may create (no report yet) or change (Draft) a report: Cases Create, any case status (the
    -- suspicion is often decided at approval).
    function fiu_editable(p_fiu_report_id in number, p_case_id in number) return varchar2;
    function fiu_action_allowed(p_fiu_report_id in number, p_action in varchar2) return varchar2;
    procedure fiu_action(p_fiu_report_id in number, p_action in varchar2, p_reference in varchar2 default null,
                         p_filed_date in date default null);
    -- release 74 (R19): guided source of funds / wealth. The evidence expected for a category (lookup FUNDS_CATEGORY
    -- tag, codes of FUNDS_EVIDENCE_TYPE), its meanings for the screen, the check of a line and its verification.
    function expected_evidence_text(p_category in varchar2) return varchar2;
    function funds_error(p_case_id in number, p_funds_type in varchar2, p_category in varchar2, p_evidence_type in varchar2,
                         p_amount in number, p_period_from in date, p_period_to in date) return varchar2;
    procedure verify_funds(p_case_funds_id in number);

end xxcmp_case_pkg;
/
