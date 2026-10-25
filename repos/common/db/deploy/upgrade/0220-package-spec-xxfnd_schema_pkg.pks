
--------------------------------------------------------------------------------
-- 03_xxfnd_core_pkgs.sql
--   XXFND_UTIL_PKG      session user/language, WHO-trigger generator (release 80: lookups in XXFND_LOOKUP_PKG, 05c)
--   XXFND_AUDIT_PKG     change reason + audit-trigger generator
--   (XXFND_SECURITY_PKG until release 78: its parts moved to XXFND_USER_PKG 16j, XXFND_PRIVILEGE_PKG 09b and
--    XXFND_INTEGRATION_PKG 05b)
--   XXFND_APPROVAL_PKG  maker-checker for configuration changes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- release 54: generators that create triggers and data security policies in the schema of the CALLER
-- (invoker rights). The shared objects live in XXFUSION; an application schema (XXCUS) reaches this
-- package through its synonym and the triggers / policies are created on its own tables.
-- XXFND_UTIL_PKG / XXFND_AUDIT_PKG / XXFND_VPD_PKG keep their generator procedures for XXFUSION itself.
--------------------------------------------------------------------------------
create or replace package xxfnd_schema_pkg authid current_user as
    -- WHO-column trigger (CREATED_BY ... OBJECT_VERSION_NUMBER) on a table of the caller's schema.
    procedure create_who_trigger(p_table_name in varchar2);
    -- WHO triggers on every XXFND_/XXCMP_ table of the caller's schema that has the WHO columns.
    procedure create_all_who_triggers;
    -- Audit trigger: one XXFND_AUDIT_LOG row per changed column (updates) or per record (inserts, deletes).
    procedure create_audit_trigger(p_table_name in varchar2);
    -- Audit triggers on the caller's tables registered with AUDIT_FLAG = Y (XXFND_CONFIG_TABLES).
    procedure create_config_audit_triggers;
    -- Data security: the policy XXFND_VPD_PKG.POLICY on every table of the caller's schema that has a rule
    -- (XXFND_DATA_SECURITY_RULES); a policy pointing to another function owner is replaced.
    procedure apply_policies;
end xxfnd_schema_pkg;
/
