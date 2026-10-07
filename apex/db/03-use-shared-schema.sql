--------------------------------------------------------------------------------
-- 03 Use the shared schema (release 54; release 55: the move is a separate script). KYC only; runs first on install and on every upgrade.
--   The shared XXFND_ objects live only in XXFUSION (the COMMON application's schema). This schema keeps its
--   own XXCMP_ objects and reaches the shared ones through synonyms; XXFUSION grants what is needed
--   (XXFND_SHARE_PKG, COMMON script 19c). The COMMON application must be installed / upgraded first.
--   1. While this schema still has its own copy of the shared tables (installs before release 54), nothing is
--      installed: ORA-20903 asks to run the one-time move script (install pack migrate/, release 55) first.
--   2. A synonym for every shared object (new objects of later releases too).
--   3. The foreign keys are re-created on the XXFUSION tables.
--   4. Data security policies are re-pointed to XXFUSION.XXFND_VPD_PKG.
--   XXFND_SCHEMA_RELEASES / XXFND_DDL_PKG stay local (script 00): release tracking per schema.
-- Idempotent; safe to re-run after a failure.
--------------------------------------------------------------------------------
create table if not exists xxcmp_shared_fks (
    constraint_name  varchar2(128)  not null,
    table_name       varchar2(128)  not null,
    ddl              varchar2(4000) not null,
    constraint xxcmp_shared_fks_pk primary key (constraint_name)
);
comment on table xxcmp_shared_fks is 'Foreign keys of XXCMP_ tables to the shared XXFND_ tables, kept while the shared tables move to XXFUSION (script 03); empty afterwards.';

declare
    c_shared constant varchar2(128) := 'XXFUSION';
    l_n      pls_integer;

    function local_object(p_name in varchar2) return boolean is
    begin
        return p_name in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG');
    end local_object;
begin
    select count(*) into l_n from all_objects
     where owner = c_shared and object_name = 'XXFND_SHARE_PKG' and object_type = 'PACKAGE';
    if l_n = 0 then
        raise_application_error(-20902,
            'ACTION NEEDED - the shared objects are not available in ' || c_shared || '. Nothing was installed.' || chr(10)
            || '1. Import the COMMON application (same release, parsing schema ' || c_shared
            || ', Install Supporting Objects: Yes).' || chr(10)
            || '2. Come back: App Builder > KYC > Utilities > Supporting Objects > Install Supporting Objects (or Upgrade).');
    end if;

    -- 1. this schema's own copy of the shared objects
    select count(*) into l_n from user_tables where table_name = 'XXFND_LOOKUP_TYPES';
    if l_n > 0 then
        raise_application_error(-20903,
            'ACTION NEEDED - XXCUS still has its own copy of the shared data. Nothing was installed.' || chr(10)
            || '1. Run migrate/move-kyc-shared-data-to-xxfusion.sql from the KYC install pack once, as XXCUS'
            || ' (SQL Workshop > SQL Scripts > Upload > Run).' || chr(10)
            || '2. Come back: App Builder > KYC > Utilities > Supporting Objects > Install Supporting Objects (or Upgrade).');
    end if;

    -- 2. synonyms for the shared objects
    for o in (select object_name from all_objects
               where owner = c_shared and object_name like 'XXFND\_%' escape '\'
                 and object_type in ('TABLE', 'VIEW', 'SEQUENCE', 'PACKAGE', 'TYPE', 'PROCEDURE', 'FUNCTION')) loop
        continue when local_object(o.object_name);
        select count(*) into l_n from user_objects where object_name = o.object_name and object_type <> 'SYNONYM';
        if l_n = 0 then
            execute immediate 'create or replace synonym ' || o.object_name || ' for ' || c_shared || '.' || o.object_name;
        end if;
    end loop;

    -- 3. the foreign keys, now on the XXFUSION tables
    for f in (select constraint_name, ddl from xxcmp_shared_fks) loop
        select count(*) into l_n from user_constraints where constraint_name = f.constraint_name;
        if l_n = 0 then
            execute immediate f.ddl;
        end if;
        delete from xxcmp_shared_fks where constraint_name = f.constraint_name;
        commit;
    end loop;

    -- 4. data security policies use the shared policy function
    execute immediate 'begin xxfnd_schema_pkg.apply_policies; end;';
    commit;
end;
/
