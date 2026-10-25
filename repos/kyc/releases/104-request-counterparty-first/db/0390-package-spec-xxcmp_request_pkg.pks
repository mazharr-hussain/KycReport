
create or replace package xxcmp_request_pkg authid definer as

    -- release 90: QUESTIONNAIRE_FOR and CREATE_REQUEST are private (used only inside the package).

    -- Requesting department of the signed-in user: the department of the employee profile (release 96: matched to a
    -- COMMON department, XXHR_ORGANIZATIONS of type DEPARTMENT, by code or name; its ORGANIZATION_ID), or null.
    function default_department return number;
    -- Release 96: the name of a requesting department (XXHR_ORGANIZATIONS.ORGANIZATION_ID), or null.
    function department_name(p_department_id in number) return varchar2;
    -- Y: the user may raise requests for any department (Compliance staff: privilege CASES.VIEW); N: only for the
    -- department of the employee profile (when the profile has one).
    function can_choose_department return varchar2;
    -- Release 76: the requesting departments the user's data security allows (release 96: their IDs, column
    -- XXCMP_REQUESTS.REQUESTING_DEPARTMENT_ID, e.g. role Requesting Entity - Finance): null = any department,
    -- '#NONE' = none; Create Request lists them and SAVE_REQUEST refuses any other (KYC_REQUEST_DEPT_NOT_ALLOWED).
    function allowed_departments return varchar2;

    -- Release 99 (risk screening on Create Request step 1): the questionnaire a new onboarding request of the party
    -- type answers (PERSON: INDIVIDUAL, otherwise CORPORATE).
    function questionnaire_code(p_party_type in varchar2) return varchar2;
    -- Release 99: the intake outcome the request's saved answers lead to - the same rule EVALUATE applies at submit
    -- (critical answer: ASSIGNED; a gate question answered with a waiver option: NOT_REQUIRED; score within the
    -- questionnaire's low-risk maximum: AUTO_APPROVED; otherwise ASSIGNED) - without changing the request. Null while
    -- a required question is not answered. A request without a questionnaire (a review) is ASSIGNED.
    function screening_outcome(p_request_id in number) return varchar2;
    -- Release 99: Yes (KYC report required: Compliance reviews) / No (not required or approved automatically) for an
    -- intake outcome; null for null.
    function outcome_kyc_required(p_outcome in varchar2) return varchar2;
    -- Release 99: SAVE_ANSWERS for the risk screening of step 1: answers to questions the request does not have (the
    -- party type changed before the check) are left out.
    procedure save_screening(p_request_id in number, p_answers in clob);

    -- Release 100: the other party a NEW counterparty of the request duplicates (XXCMP_PARTY_PKG.EXACT_PARTY_ID; the
    -- request's own party excluded), or null. Page 201 asks Use the existing party Yes / No when it is set.
    function duplicate_party_id(p_request_id          in number,
                                p_party_type          in varchar2,
                                p_registration_number in varchar2,
                                p_jurisdiction        in varchar2,
                                p_registration_type   in varchar2) return number;

    -- The rules of Create Request step 1 (null = acceptable): EXISTING needs an approved party; NEW follows the
    -- common party form (XXCMP_PARTY_PKG.PARTY_ERROR); the business justification is required.
    -- P_DRAFT = Y checks only what a draft needs (type and name, or the party).
    -- Release 99: the counterparty follows the short request form (XXCMP_PARTY_PKG.PARTY_ERROR, P_REQUEST_FORM = Y); the
    -- business relationship and justification are not asked when the risk screening finds KYC not required.
    -- Release 104: the business relationship is always required, the business justification never.
    -- Release 100: EXISTING takes any enabled party that is not rejected or cancelled. A NEW counterparty with the
    -- registration type, number and country of another party (XXCMP_PARTY_PKG.EXACT_PARTY_ID, drafts too) is not
    -- created: P_USE_EXISTING null asks to use that party, N asks to change the details, Y uses it (SAVE_REQUEST).
    function request_error(p_request_id          in number,
                           p_party_selection     in varchar2,
                           p_party_id            in number,
                           p_party_type          in varchar2,
                           p_party_name          in varchar2,
                           p_jurisdiction        in varchar2,
                           p_registration_number in varchar2,
                           p_entity_type         in varchar2,
                           p_incorporation_date  in date,
                           p_email               in varchar2,
                           p_phone               in varchar2,
                           p_justification       in varchar2,
                           p_draft               in varchar2 default 'N',
                           p_match_ack           in varchar2 default 'Y',
                           p_registration_type   in varchar2 default null,
                           p_business_relationship in varchar2 default null,
                           p_use_existing        in varchar2 default null) return varchar2;

    -- Create Request step 1: creates the DRAFT request (p_request_id null) or updates it (Draft or Information
    -- Needed, by its requester). NEW creates the counterparty as a party with status Pending (or updates the
    -- request's own Pending party); EXISTING links an approved party. A change of type replaces the questionnaire.
    -- The contact person (hidden by the build option REQUEST_CONTACT) becomes the new party's primary contact.
    procedure save_request(p_request_id            in out number,
                           p_party_selection       in varchar2,
                           p_party_id              in number,
                           p_party_type            in varchar2,
                           p_party_name            in varchar2,
                           p_jurisdiction          in varchar2,
                           p_registration_number   in varchar2,
                           p_entity_type           in varchar2,
                           p_incorporation_date    in date,
                           p_email                 in varchar2,
                           p_phone                 in varchar2,
                           p_website               in varchar2,
                           p_fax                   in varchar2,
                           p_requesting_department_id in number,
                           p_justification         in varchar2,
                           p_draft                 in varchar2 default 'N',
                           p_contact_name          in varchar2 default null,
                           p_contact_email         in varchar2 default null,
                           p_contact_phone         in varchar2 default null,
                           p_match_ack             in varchar2 default 'Y',
                           p_registration_type     in varchar2 default null,
                           p_address               in varchar2 default null,
                           p_business_relationship in varchar2 default null,
                           p_use_existing          in varchar2 default null);

    -- Y when the signed-in user may change the request (its requester, while Draft or Information Needed).
    function is_editable(p_request_id in number) return varchar2;
    -- Y when the requester may change the counterparty's party: an editable request whose party was created by it
    -- (new counterparty, not merged into an existing party). The party status does not decide it.
    function party_editable(p_request_id in number) return varchar2;

    -- release 74: the party directory and party matching are in the party package (XXCMP_PARTY_PKG).
    -- The same for a saved request, without its own party (Compliance merges a duplicate from the request page).
    function request_candidates_json(p_request_id in number) return clob;
    -- Y while an older request (workflow 1.1) still waits for Compliance's match decision.
    function match_pending(p_request_id in number) return varchar2;

    -- Create Request step 2 (page 202): release 90 - the questionnaire form is the KYC Question template component fed by
    -- SQL on the page (no HTML here; QUESTIONNAIRE_HTML removed). kyc-app.js (kycQuestionnaire.bind) copies the answers
    -- into a JSON item before submit: [{"q": question_id, "o": answer_option_id, "t": "text answer"}, ...]
    -- Required questions without an answer in P_ANSWERS (null = all answered).
    function answers_error(p_request_id in number, p_answers in clob) return varchar2;
    -- Saves the answers of a Draft or Information Needed request; only its own questions and approved options.
    procedure save_answers(p_request_id in number, p_answers in clob);

    -- Why the request cannot be submitted yet (null = it can).
    function submit_error(p_request_id in number) return varchar2;
    -- Submits the request (In Progress) and starts the KYC_REQUEST workflow.
    procedure submit(p_request_id in number);

    -- Why the signed-in user cannot cancel the request (null = can): its requester, while Draft, In Progress or
    -- Information Needed.
    function cancel_error(p_request_id in number) return varchar2;
    -- Cancels the request: ends its workflow and tasks; a Pending party only this request uses is Cancelled.
    procedure cancel(p_request_id in number, p_reason in varchar2 default null);
    -- Withdraw: the requester pulls a submitted request (In Progress) back to Draft; its workflow and task end.
    function withdraw_error(p_request_id in number) return varchar2;
    -- Y when the approver may use Request Information on the task: the question goes to the task's initiator (the
    -- requester), so an approver who is also the requester cannot ask (APEX refuses REQUEST_INFO_NOT_AUTHORIZED).
    function can_request_info(p_task_id in number) return varchar2;
    -- release 73: Request Information when the approver is the requester (APEX cannot ask the task initiator's
    -- own question back): the question is recorded (XXCMP_RFIS), the approval ends and the request goes back to
    -- the requester (Information needed); resubmitting starts the approval again.
    procedure return_for_info(p_request_id in number, p_task_id in number, p_comment in varchar2);
    -- Y when the request was returned to the requester by return_for_info and waits to be submitted again.
    function returned_for_info(p_request_id in number) return varchar2;
    procedure withdraw(p_request_id in number);

    -- Document checklist task events: Compliance asked the requester for information / the requester answered.
    procedure info_requested(p_request_id in number);
    procedure info_submitted(p_request_id in number);

    -- Workflow steps (KYC_REQUEST). Run as system steps, not limited by data security.
    procedure evaluate(p_request_id in number);
    function outcome(p_request_id in number) return varchar2;
    procedure close_without_case(p_request_id in number);
    -- release 74: the request asks the case package to open the case (XXCMP_CASE_PKG.CREATE_CASE), then the request and
    -- its party are Approved here.
    procedure open_case(p_request_id in number);
    -- Release 75: the case officer chosen on the approval that opens the case (Approve popup on 206); OPEN_CASE gives
    -- the case to that person (default: the approver, as before). Checked with XXCMP_CASE_PKG.IS_CASE_OFFICER.
    procedure set_case_assignee(p_request_id in number, p_user_name in varchar2);
    -- Y when approving the current step opens the case (the last approval step of a request that needs KYC).
    function opens_case_on_approval(p_request_id in number) return varchar2;
    -- Release 76: Assign Case on the request (205, opened right after the approval that opens the case). Y when the user
    -- may give the request's case to an officer: the case exists and XXCMP_CASE_PKG.CAN_ASSIGN, or the approval is
    -- complete and the workflow is about to open the case (Case Assignment privilege).
    function can_assign_case(p_request_id in number) return varchar2;
    -- Gives the request's case to the officer: XXCMP_CASE_PKG.ASSIGN when the case exists, else the officer is kept on the
    -- request and OPEN_CASE creates the case for them (the request row is locked, so the two never cross).
    procedure assign_case(p_request_id in number, p_user_name in varchar2, p_comment in varchar2 default null);
    -- The in-progress request behind a case Compliance opens by hand for a party (XXCMP_CASE_PKG.CREATE_MANUAL_CASE).
    function create_case_request(p_party_id in number, p_justification in varchar2, p_business_relationship in varchar2)
        return number;
    procedure reject(p_request_id in number);

    -- Status as shown to users (lookup KYC_REQUEST_STATUS).
    function stage(p_request_id in number) return varchar2;
    -- KYC Required: Yes when the approval workflow runs (Compliance review), No when approved automatically.
    function kyc_required(p_request_id in number) return varchar2;
    -- Who must act now: the requester (Draft, Information Needed), the Compliance user holding the task or
    -- 'Compliance' (In Progress); null once closed.
    function pending_with(p_request_id in number) return varchar2;

    -- New review request for the party of a case (monitoring): submitted at once, always to Compliance.
    function start_review(p_case_id in number, p_request_type in varchar2, p_trigger_source in varchar2,
                          p_justification in varchar2) return number;

    -- Release 90 (from XXCMP_APPROVAL_PKG, dropped): the request approval - who approves the request now, from the common
    -- Approval Setup (transaction type KYC_REQUEST), and the request's approval history. The path is chosen and started
    -- by SUBMIT; the request's own columns APPROVAL_PATH_NAME (the rule) and CURRENT_STEP (the position) follow it.
    -- Approvers (comma-separated user names) of the request's current step (task DOC_CHECKLIST_REVIEW).
    function step_approvers(p_request_id in number) return varchar2;
    -- Name of the current step (task subject).
    function step_name(p_request_id in number) return varchar2;
    -- Moves to the next step: Y when there is one, N when the path is complete (KYC_REQUEST workflow).
    function next_step(p_request_id in number) return varchar2;
    -- The approval history table: what happened (submit, decisions, information requests, withdraw, cancel) with
    -- who, when and the comments; then the current step (Pending, with its approvers) and the steps still to come
    -- (Waiting); before submit, the expected steps (Expected) with their role or user.
    function history_rows(p_request_id in number) return xxcmp_history_tab pipelined;
    -- Release 90 (pages 205, 206): the case opened for the request, or null.
    function request_case(p_request_id in number) return number;
    -- Release 90 (page 206): Y when the user may decide the request's approval task P_TASK_ID (a document checklist
    -- task the user may approve or claim): Approve, Reject, Request Information.
    function can_decide(p_task_id in number) return varchar2;
    -- Y when the current approver may add an approver after them (the Approval Setup approval has started and the task
    -- is open).
    function can_add_approver(p_request_id in number, p_task_id in number) return varchar2;

end xxcmp_request_pkg;
/
