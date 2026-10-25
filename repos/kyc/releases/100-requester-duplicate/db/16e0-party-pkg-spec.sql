--------------------------------------------------------------------------------
-- 16e0 Party logic - package specification (release 43)
--   The XXCMP_PARTY_PKG specification runs before 16b: the request and case packages (16b) call
--   put_party / owners_json / ownership_tree_json, so the current specification must exist when they
--   compile, on install and on upgrade. The body stays in 16e (it needs the 16b tables).
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxcmp_party_pkg authid definer as

    -- Label of a shared party field for the party type: JURISDICTION, REGISTRATION_NUMBER, ENTITY_TYPE,
    -- INCORPORATION_DATE (for example Registration No. / ID Number).
    function field_label(p_party_type in varchar2, p_field in varchar2) return varchar2;
    -- Lookup type of ENTITY_TYPE for the party type (ENTITY_TYPE / ID_DOCUMENT_TYPE).
    function entity_lookup(p_party_type in varchar2) return varchar2;
    -- Lookup type of REGISTRATION_TYPE for the party type: REGISTRATION_TYPE (organisation) / ID_DOCUMENT_TYPE (individual).
    function registration_lookup(p_party_type in varchar2) return varchar2;

    -- Party number of another enabled party with the same party type, registration / ID type, registration / ID
    -- number (ignoring spaces and punctuation) and country, or null. Reads the whole party master (trusted); returns only the number.
    function exact_party_number(p_party_type          in varchar2,
                                p_registration_number in varchar2,
                                p_jurisdiction        in varchar2,
                                p_exclude_party_id    in number default null,
                                p_registration_type   in varchar2 default null) return varchar2;
    -- Release 100: the party ID of that other party (the same rule), or null - the request form offers to use it.
    function exact_party_id(p_party_type          in varchar2,
                            p_registration_number in varchar2,
                            p_jurisdiction        in varchar2,
                            p_exclude_party_id    in number default null,
                            p_registration_type   in varchar2 default null) return number;

    -- The rules of the common party form (null = acceptable). Type, name and country required;
    -- organisation: registration number and entity type required; individual: ID type required when an
    -- ID number is given; email or phone required (email must be valid); the date not in the future;
    -- no other party with the same number and country; when similar parties exist the user must confirm
    -- (P_MATCH_ACK = Y) that none of them is this party. P_DRAFT = Y checks only the type and the name.
    -- Release 99: P_REQUEST_FORM = Y is the requester's KYC request form (the short counterparty data Risk Management
    -- completes later): no email or phone are asked there, and a party with the same number is not checked here
    -- (release 100: XXCMP_REQUEST_PKG.REQUEST_ERROR asks to use the existing party); the registration type is required
    -- (release 100).
    function party_error(p_party_id            in number,
                         p_party_type          in varchar2,
                         p_party_name          in varchar2,
                         p_jurisdiction        in varchar2,
                         p_registration_number in varchar2,
                         p_entity_type         in varchar2,
                         p_incorporation_date  in date,
                         p_email               in varchar2,
                         p_phone               in varchar2,
                         p_draft               in varchar2 default 'N',
                         p_match_ack           in varchar2 default 'Y',
                         p_registration_type   in varchar2 default null,
                         p_request_form        in varchar2 default 'N') return varchar2;

    -- Inserts (P_PARTY_ID null) or updates the party's form fields, without a privilege check (the request
    -- package creates the Pending party of a request through it). A new party is APPROVED unless
    -- P_PARTY_STATUS says otherwise. Null P_DATA_PROVENANCE / P_ENABLED_FLAG keep the current values.
    procedure put_party(p_party_id            in out number,
                        p_party_type          in varchar2,
                        p_party_name          in varchar2,
                        p_jurisdiction        in varchar2,
                        p_registration_number in varchar2,
                        p_entity_type         in varchar2,
                        p_incorporation_date  in date,
                        p_email               in varchar2,
                        p_phone               in varchar2,
                        p_website             in varchar2,
                        p_fax                 in varchar2,
                        p_party_status        in varchar2 default null,
                        p_data_provenance     in varchar2 default null,
                        p_enabled_flag        in varchar2 default null,
                        p_registration_type   in varchar2 default null,
                        p_address             in varchar2 default null);

    -- Compliance saves the common party form (Party dialog, new owner / officer): Parties - Create for a new
    -- party, Parties - Manage to change one; the form rules apply. A party created here is Approved.
    procedure save_party(p_party_id            in out number,
                         p_party_type          in varchar2,
                         p_party_name          in varchar2,
                         p_jurisdiction        in varchar2,
                         p_registration_number in varchar2,
                         p_entity_type         in varchar2,
                         p_incorporation_date  in date,
                         p_email               in varchar2,
                         p_phone               in varchar2,
                         p_website             in varchar2 default null,
                         p_fax                 in varchar2 default null,
                         p_data_provenance     in varchar2 default null,
                         p_enabled_flag        in varchar2 default null,
                         p_match_ack           in varchar2 default 'Y',
                         p_request_id          in number   default null,
                         p_registration_type   in varchar2 default null,
                         p_address             in varchar2 default null);
    -- Y when the user may see the party on a request or party screen: PARTIES.VIEW, the party of a request the user
    -- can see (P_REQUEST_ID), or an approved party.
    function can_view(p_party_id in number, p_request_id in number default null) return varchar2;
    -- Y when the user may change the party's details (additional information, contact persons, owners / officers,
    -- documents): PARTIES.MANAGE, or the requester while the request's party was created by it and is editable.
    function can_edit_details(p_party_id in number, p_request_id in number default null) return varchar2;
    -- Owners / officers of the party (both directions) when CAN_VIEW: JSON array [{"party_relationship_id",
    -- "direction","related_party","relationship_type","ownership_percentage","start_date","end_date"}].
    function owners_json(p_party_id in number, p_request_id in number default null) return clob;
    -- Ownership Tree (release 42, party and case screens): the parties that hold an interest in it (level 1), the
    -- parties that hold an interest in those (level 2), and so on (at most 6 levels, no cycles), then the parties this
    -- party holds an interest in (level 1 only). Each row: relationship, the related party's country / nationality,
    -- incorporation date / date of birth, registration / ID number and the latest expiry date of its documents.
    -- With P_CASE_ID: a first row for the case's party itself (level 0) and, on every row, the party's latest
    -- screening in the case (results, conclusion, source, risk level).
    function ownership_tree_json(p_party_id in number, p_request_id in number default null, p_case_id in number default null) return clob;
    -- Additional information (DFF) of the party: read only unless CAN_EDIT_DETAILS and P_EDIT = Y; empty when the user may
    -- not see the party or the party type has no field. Release 90: KYC builds no HTML here - the fields are drawn by
    -- COMMON's reusable flexfield rendering (XXFND_DFF_PKG.RENDER, runtime-defined fields: no APEX component fits); this
    -- function only adds the party's access rules and reads the party past data security for a requester.
    function dff_html(p_party_id in number, p_request_id in number, p_context_code in varchar2, p_edit in varchar2) return clob;
    function dff_error(p_party_id in number, p_values_json in clob, p_context_code in varchar2) return varchar2;
    procedure save_dff(p_party_id in number, p_request_id in number, p_values_json in clob, p_context_code in varchar2);

    -- Party status: PENDING, APPROVED, REJECTED, CANCELLED.
    procedure set_status(p_party_id in number, p_status in varchar2);

    -- Fills the items of the common party region (P0_PARTY_*) with the party, or empties them for a new party.
    -- Compliance (Parties - View) reads any party; a requester only a party of one of their own requests.
    -- P_READ_ONLY = Y shows the region read only.
    procedure load_items(p_party_id in number, p_read_only in varchar2 default 'N');

    -- Owner / officer rules (null = acceptable): Ownership % required for Shareholder, Beneficial Owner and
    -- Parent Company and empty for the other types; the active owners of a party hold at most 100%.
    function relationship_error(p_relationship_id   in number,
                                p_object_party_id   in number,
                                p_relationship_type in varchar2,
                                p_percentage        in number,
                                p_start_date        in date,
                                p_end_date          in date) return varchar2;

    -- Compliance merges the duplicate P_FROM_PARTY_ID into P_INTO_PARTY_ID (Parties - Manage): requests, cases,
    -- screenings, alerts, notes, beneficial-owner decisions, contacts, relationships and documents move to the
    -- kept party; its empty details are completed from the duplicate; the duplicate is disabled and points to it.
    procedure merge_parties(p_from_party_id in number, p_into_party_id in number, p_note in varchar2 default null);

    -- Y when the party exists and is enabled (a merged or disabled party is not edited or merged again).
    function is_enabled(p_party_id in number) return varchar2;

    -- The common Party card shown on every screen that shows a party: number, name, type, registration / identity,
    -- country, main contact details, primary contact person, party status and next KYC date. Follows data security.
    -- release 74 (R11): data only - the screens show it with a standard report (Global Page region Party, page 222).
    -- JSON array of fields [{"group_name","seq","label","value","meta","tone","url"}] in the groups Party (name,
    -- number, status), Identity, Contact and KYC. P_REQUEST_ID: the party of that request - shown to anyone who can
    -- see the request, without the party status and KYC dates; a user who cannot see the party gets one note field.
    -- Release 99: P_REQUEST_FORM = Y shows the party as the requester's KYC request form has it (Create Request): no
    -- email, phone or website, no registration type or incorporation date for an organisation, the form's labels.
    function card_json(p_party_id in number, p_request_id in number default null, p_show_status in varchar2 default 'Y',
                       p_request_form in varchar2 default 'N') return clob;

    -- release 74 (from the request and KYC rules packages): party directory and matching.
    -- 0-100 similarity of two names after normalisation (case, punctuation, common legal suffixes).
    function name_similarity(p_name_1 in varchar2, p_name_2 in varchar2) return number deterministic;
    -- Parties a requester may choose from (requesters cannot read the party master itself): approved, enabled
    -- parties of the type (null = both types) with number, name and country only. JSON array [{"party_id","party_number","party_name","country"}].
    function party_directory_json(p_party_type in varchar2) return clob;

    -- Possible existing parties for a counterparty, strongest first (at most 10). Matching: same registration / ID
    -- number; name similarity; same incorporation / birth date; same country. 100 = same number and country.
    -- JSON array [{"party_id","party_number","registration_number","party_name","country","score","reg_match",
    --              "reasons","exact","status"}]; reg_match = 0-100 similarity of the numbers.
    function party_candidates_json(p_party_type          in varchar2,
                                   p_party_name          in varchar2,
                                   p_registration_number in varchar2,
                                   p_date                in date,
                                   p_country             in varchar2,
                                   p_exclude_party_id    in number default null) return clob;
    -- release 90: PARTY_CANDIDATE_COUNT is private (PARTY_ERROR counts the candidates).

    -- Party type (ORGANIZATION / PERSON) of a party, or null (only the type is read past data security).
    function party_type(p_party_id in number) return varchar2;
    -- Release 90 (from the request package): the party reads other components need, past data security. PARTY_STATUS:
    -- PENDING, APPROVED, REJECTED, CANCELLED or null. GET_PARTY: the whole row (NO_DATA_FOUND when missing) - for other
    -- components' packages only (the request copies the party's fields); never shown on a page as it is.
    function party_status(p_party_id in number) return varchar2;
    function get_party(p_party_id in number) return xxcmp_parties%rowtype;
    -- release 74 (R14): party verifications (identity document checks, company registry / KYB checks).
    -- Y when the user may record one for the party (Parties Create; from a case only while it is investigated).
    function can_record_verification(p_party_id in number, p_case_id in number default null) return varchar2;
    function id_verification_error(p_party_id        in number,
                                   p_document_number in varchar2,
                                   p_issue_date      in date,
                                   p_expiry_date     in date,
                                   p_result          in varchar2) return varchar2;
    function registry_check_error(p_part