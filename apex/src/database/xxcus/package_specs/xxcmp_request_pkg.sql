create or replace package xxcus.xxcmp_request_pkg authid definer as

    -- Requester questionnaire for a party type (PERSON -> INDIVIDUAL, ORGANIZATION -> CORPORATE).
    function questionnaire_for (
        p_party_type in varchar2
    ) return varchar2;

    -- New DRAFT request with one empty answer row per question of its questionnaire.
    function create_request (
        p_party_type            in varchar2,
        p_party_name            in varchar2,
        p_registration_number   in varchar2 default null,
        p_jurisdiction          in varchar2 default null,
        p_entity_type           in varchar2 default null,
        p_date_of_birth         in date default null,
        p_nationality           in varchar2 default null,
        p_requesting_department in varchar2 default null,
        p_justification         in varchar2 default null,
        p_request_type          in varchar2 default 'NEW_ONBOARDING',
        p_trigger_source        in varchar2 default 'MANUAL',
        p_parent_request_id     in number default null,
        p_parent_case_id        in number default null,
        p_party_id              in number default null
    ) return number;

    -- Counterparty rules (null = acceptable). EXISTING: a party must be chosen. NEW organisation: registration
    -- number and entity type; NEW individual: date of birth (not in the future), nationality and identity document.
    -- Country for every NEW counterparty. P_DRAFT = Y checks only what a draft needs (type and name or party).
    function counterparty_error (
        p_party_selection     in varchar2,
        p_party_id            in number,
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2,
        p_entity_type         in varchar2,
        p_incorporation_date  in date,
        p_id_type             in varchar2,
        p_id_number           in varchar2,
        p_jurisdiction        in varchar2,
        p_date_of_birth       in date,
        p_nationality         in varchar2,
        p_draft               in varchar2 default 'N'
    ) return varchar2;

    -- Wizard step 1: creates the DRAFT request (p_request_id null) or updates it. EXISTING copies the chosen
    -- party's details; NEW keeps what was typed, clearing fields that do not apply to the type. A change of
    -- type replaces the questionnaire. P_MATCH_ACK = Y: the requester declared none of the possible matches is
    -- the counterparty (Compliance still decides at the document checklist).
    procedure save_counterparty (
        p_request_id            in out number,
        p_party_selection       in varchar2,
        p_party_id              in number,
        p_party_type            in varchar2,
        p_party_name            in varchar2,
        p_registration_number   in varchar2,
        p_entity_type           in varchar2,
        p_incorporation_date    in date,
        p_id_type               in varchar2,
        p_id_number             in varchar2,
        p_jurisdiction          in varchar2,
        p_date_of_birth         in date,
        p_nationality           in varchar2,
        p_requesting_department in varchar2,
        p_justification         in varchar2,
        p_match_ack             in varchar2 default 'N',
        p_draft                 in varchar2 default 'N'
    );

    -- Parties a requester may choose from (requesters cannot read the party master itself): enabled parties of
    -- the type with number, name and country only. JSON array [{"party_id","party_number","party_name","country"}].
    function party_directory_json (
        p_party_type in varchar2
    ) return clob;

    -- Possible existing parties for a new counterparty, strongest first (at most 10). Matching: same registration
    -- number (organisation) or identity document number (individual); name similarity; same date of incorporation
    -- or birth; same country. JSON array [{"party_id","party_number","party_name","country","score","reasons"}].
    function party_candidates_json (
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2,
        p_id_number           in varchar2,
        p_date                in date,
        p_country             in varchar2
    ) return clob;

    function party_candidate_count (
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2,
        p_id_number           in varchar2,
        p_date                in date,
        p_country             in varchar2
    ) return number;
    -- The same for a saved request (Compliance's view on the request page).
    function request_candidates_json (
        p_request_id in number
    ) return clob;
    -- Y while Compliance still has to decide whether a new counterparty is an existing party.
    function match_pending (
        p_request_id in number
    ) return varchar2;
    -- Compliance's decision: P_PARTY_ID = merge the counterparty into that party (the request is linked to it and the
    -- party's empty fields are completed from the request); null = confirm it as a new party.
    procedure resolve_match (
        p_request_id in number,
        p_party_id   in number default null,
        p_note       in varchar2 default null
    );

    -- Wizard step 2: the questionnaire as a form. Questions grouped by section (translated), each with its
    -- answer control (Yes/No and single choice: radio buttons; text, number, date: an input) and the saved answer.
    -- kyc-app.js (kycQuestionnaire.bind) copies the answers into a JSON item before submit:
    --   [{"q": question_id, "o": answer_option_id, "t": "text answer"}, ...]
    function questionnaire_html (
        p_request_id in number,
        p_respondent in varchar2 default 'REQUESTER'
    ) return clob;
    -- Required questions without an answer in P_ANSWERS (null = all answered).
    function answers_error (
        p_request_id in number,
        p_answers    in clob
    ) return varchar2;
    -- Saves the answers of a DRAFT request; only its own questions and their approved options are accepted.
    procedure save_answers (
        p_request_id in number,
        p_answers    in clob
    );

    -- Why the request cannot be submitted yet (null = it can).
    function submit_error (
        p_request_id in number
    ) return varchar2;
    -- Submits the request and starts the KYC_REQUEST workflow.
    procedure submit (
        p_request_id in number
    );

    -- Workflow steps (KYC_REQUEST). Run as system steps, not limited by data security.
    procedure evaluate (
        p_request_id in number
    );

    function outcome (
        p_request_id in number
    ) return varchar2;

    procedure close_without_case (
        p_request_id in number
    );

    procedure create_case (
        p_request_id in number
    );

    procedure reject (
        p_request_id in number
    );

    -- Requester's three-stage view: Draft, Submitted, Processing, In Progress, Completed, Rejected.
    function stage (
        p_request_id in number
    ) return varchar2;

    -- New review request for the party of a case (monitoring): submitted at once, always to Compliance.
    function start_review (
        p_case_id        in number,
        p_request_type   in varchar2,
        p_trigger_source in varchar2,
        p_justification  in varchar2
    ) return number;

end xxcmp_request_pkg;
/


-- sqlcl_snapshot {"hash":"64b3d2f2fbb1f620337d15169cd6ee76bcccced7","type":"PACKAGE_SPEC","name":"XXCMP_REQUEST_PKG","schemaName":"XXCUS","sxml":""}