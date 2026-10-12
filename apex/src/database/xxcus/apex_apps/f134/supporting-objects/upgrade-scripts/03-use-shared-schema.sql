--------------------------------------------------------------------------------
-- 03 Use the shared schema (release 54; release 57: the one-time move is an ADMIN script). KYC only; runs on install and
-- on every upgrade.
--   The shared XXFND_ objects live only in XXFUSION (the COMMON application's schema). This schema keeps its
--   own XXCMP_ objects and reaches the shared ones through synonyms; XXFUSION grants what is needed
--   (XXFND_SHARE_PKG, COMMON script 19c). The COMMON application must be installed / upgraded first.
--   - A synonym for every shared object (new objects of later releases too).
--   - Data security policies use XXFUSION.XXFND_VPD_PKG.
--   While XXCUS still has its own copy of the shared data it installs nothing and reports ORA-20903: run the one-time
--   ADMIN script apex/db/admin/move-kyc-shared-data-to-xxfusion.sql first.
-- Idempotent.
--------------------------------------------------------------------------------
declare
    c_shared constant varchar2(128) := 'XXFUSION';
    l_n      pls_integer;
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

    -- release 76: COMMON of the same release first - its new shared calls must be there (a KYC install started while
    -- the COMMON install still runs, or over an older COMMON, stops here before it changes anything)
    select count(*) into l_n from all_procedures
     where owner = c_shared
       and (object_name, procedure_name) in (('XXFND_APPROVAL_RULE_PKG', 'APPROVAL_ERROR'),
                                             ('XXFND_VPD_PKG', 'ALLOWED_VALUES'));
    if l_n < 2 then
        raise_application_error(-20904,
            'ACTION NEEDED - COMMON is older than this KYC release (or its install has not finished). Nothing was installed.'
            || chr(10) || '1. Install / upgrade the COMMON application of the same release and wait until it has finished.'
            || chr(10) || '2. Come back: App Builder > KYC > Utilities > Supporting Objects > Install Supporting Objects '
            || '(or Upgrade). Every script can be re-run.');
    end if;

    select count(*) into l_n from user_tables where table_name in ('XXFND_LOOKUP_TYPES', 'XXCMP_SHARED_FKS');
    if l_n > 0 then
        raise_application_error(-20903,
            'ACTION NEEDED - XXCUS still has its own copy of the shared data. Nothing was installed.' || chr(10)
            || '1. Run apex/db/admin/move-kyc-shared-data-to-xxfusion.sql once as ADMIN (it validates first, then moves).'
            || chr(10)
            || '2. Come back: App Builder > KYC > Utilities > Supporting Objects > Install Supporting Objects (or Upgrade).');
    end if;

    for o in (select object_name from all_objects
               where owner = c_shared and object_name like 'XXFND\_%' escape '\'
                 and object_type in ('TABLE', 'VIEW', 'SEQUENCE', 'PACKAGE', 'TYPE', 'PROCEDURE', 'FUNCTION')
                 and object_name not in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG')) loop
        select count(*) into l_n from user_objects where object_name = o.object_name;
        if l_n = 0 then
            execute immediate 'create synonym ' || o.object_name || ' for ' || c_shared || '.' || o.object_name;
        end if;
    end loop;

    execute immediate 'begin xxfnd_schema_pkg.apply_policies; end;';
    commit;
end;
/
