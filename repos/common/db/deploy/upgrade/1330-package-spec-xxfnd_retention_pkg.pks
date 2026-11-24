--------------------------------------------------------------------------------
-- 14b XXFND_RETENTION_PKG - the Retention component of Documents and Records (release 81). COMMON only.
--   A placeholder (decision D3): no retention policy is defined, nothing is flagged, archived or deleted, and no job
--   runs. The spec documents what the component will do once it is built (review stage, then archive or delete, with
--   configurable reminders); every routine is a stub that changes nothing. The Retention screen (page 112) shows a
--   message until then.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_retention_pkg authid definer as
    -- Y when retention is active. Always N until the component is built.
    function is_active return varchar2;
    -- The policy that applies to a table (and jurisdiction): null while retention is not active.
    function policy_for(p_table_name in varchar2, p_jurisdiction in varchar2 default null) return number;
    -- The scheduled run: flags records due for review, sends the reminders, archives or deletes what was approved.
    -- A stub: it does nothing while retention is not active (no job calls it).
    procedure run;
end xxfnd_retention_pkg;
/
