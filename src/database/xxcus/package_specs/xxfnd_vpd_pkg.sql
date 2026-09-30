create or replace package xxcus.xxfnd_vpd_pkg authid definer as
    -- DBMS_RLS policy function for every table that has data security rules.
    function policy (
        p_schema in varchar2,
        p_object in varchar2
    ) return varchar2;
    -- Attach the policy to every table referenced by a rule (idempotent).
    procedure apply_policies;
    -- Narrow bypass for server code that has already authorised the caller
    -- (e.g. a validated RFI response token). Always paired with end_trusted.
    procedure begin_trusted;

    procedure end_trusted;

end xxfnd_vpd_pkg;
/


-- sqlcl_snapshot {"hash":"d4ee687d8973a6b30dfdcf02cfc39196b022878f","type":"PACKAGE_SPEC","name":"XXFND_VPD_PKG","schemaName":"XXCUS","sxml":""}