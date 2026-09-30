create or replace package xxcus.xxcmp_kyc_pkg authid definer as

    -- Document categories required for a record, from approved rules; the most
    -- specific rule per category wins (jurisdiction + entity type, then either,
    -- then the general rule), PRIORITY breaks ties.
    function mandatory_categories (
        p_entity_name  in varchar2,
        p_jurisdiction in varchar2,
        p_entity_type  in varchar2
    ) return apex_t_varchar2;

    -- Mandatory categories with no current, unexpired attachment on the record.
    function missing_categories (
        p_entity_name  in varchar2,
        p_pk1_value    in varchar2,
        p_jurisdiction in varchar2,
        p_entity_type  in varchar2
    ) return apex_t_varchar2;

    -- Existing party that is certainly the same one (registration number +
    -- jurisdiction for organisations; name + date of birth for persons), or null.
    function exact_party_match (
        p_party_type          in varchar2,
        p_party_name          in varchar2,
        p_registration_number in varchar2 default null,
        p_jurisdiction        in varchar2 default null,
        p_date_of_birth       in date default null
    ) return number;

    -- 0-100 similarity of two names after normalisation (case, punctuation,
    -- common legal suffixes). Used by the Possible Matches region.
    function name_similarity (
        p_name_1 in varchar2,
        p_name_2 in varchar2
    ) return number
        deterministic;

    -- Raise an RFI. For an external party a one-time token is generated; its
    -- hash is stored and the token itself is returned for the email link only.
    procedure create_rfi (
        p_entity_name         in varchar2,
        p_pk1_value           in varchar2,
        p_recipient_type      in varchar2,
        p_rfi_category        in varchar2,
        p_description         in varchar2,
        p_continue_other_work in varchar2,
        p_due_date            in date,
        p_recipient_user_name in varchar2 default null,
        p_party_contact_id    in number default null,
        p_rfi_id              out number,
        p_token               out varchar2
    );

    -- Participant of the RFI_RESPONSE task: the internal recipient.
    function rfi_recipient (
        p_rfi_id in number
    ) return varchar2;

    -- Response from the requesting department (signed-in user).
    procedure respond (
        p_rfi_id        in number,
        p_response_text in clob
    );
    -- Response from an external party through the public response page.
    function respond_by_token (
        p_token         in varchar2,
        p_response_text in clob
    ) return number;
    -- Officer closes the RFI.
    procedure resolve (
        p_rfi_id in number,
        p_status in varchar2,
        p_notes  in varchar2
    );

    -- Emails the recipient using template RFI_RAISED_INTERNAL or RFI_RAISED_EXTERNAL
    -- (APEX_MAIL queue). P_RESPONSE_URL is the public response page link with the token.
    procedure send_rfi_email (
        p_rfi_id       in number,
        p_response_url in varchar2 default null
    );

end xxcmp_kyc_pkg;
/


-- sqlcl_snapshot {"hash":"3e5de85a3cd2bc4c9c7b13b144d769514762f7ad","type":"PACKAGE_SPEC","name":"XXCMP_KYC_PKG","schemaName":"XXCUS","sxml":""}