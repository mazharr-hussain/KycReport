--------------------------------------------------------------------------------
-- 03 Use the shared schema (release 54; release 57: the one-time move is an ADMIN script). KYC only; runs on install and
-- on every upgrade.
--   The shared XXFND_ objects live only in XXFUSION (the COMMON application's schema). This schema keeps its
--   own XXCMP_ objects and reaches the shared ones through synonyms; XXFUSION grants what is needed
--   (XXFND_SHARE_PKG, COMMON script 19c). The COMMON application must be installed / upgraded first.
--   - A synonym for every shared object (new objects of later releases too).
--   - Release 87: a synonym whose shared object COMMON has removed (e.g. XXFND_TASK_PKG, now XXFND_WORKFLOW_PKG) is
--     dropped, so nothing in this schema can still compile against it.
--   - Data security policies use XXFUSION.XXFND_VPD_PKG.
--   Release 87: KYC is an application registered in COMMON (release 86). COMMON's administrator registers it once,
--   before this install: apex/db/admin/onboard-application.sql with the KYC APEX application ID and code KYC.
--   Registration is what grants this schema the shared objects.
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
            || '2. Register KYC in COMMON: run apex/db/admin/onboard-application.sql as ' || c_shared
            || ' (the KYC APEX application ID, code KYC); registration grants this schema the shared objects.' || chr(10)
            || '3. Come back: App Builder > KYC > Utilities > Supporting Objects > Install Supporting Objects (or Upgrade).');
    end if;

    -- release 76: COMMON of the same release first - its new shared calls must be there (a KYC install started while
    -- the COMMON install still runs, or over an older COMMON, stops here before it changes anything)
    -- release 87: COMMON 86 (the registration routines and MOVE_DOCUMENTS that KYC calls)
    select count(*) into l_n from all_procedures
     where owner = c_shared
       and (object_name, procedure_name) in (('XXFND_APPROVAL_RULE_PKG', 'APPROVAL_ERROR'),
                                             ('XXFND_VPD_PKG', 'ALLOWED_VALUES'),
                                             ('XXFND_PRIVILEGE_PKG', 'REGISTER_FEATURE'),
                                             ('XXFND_ATTACH_PKG', 'MOVE_DOCUMENTS'));
    -- release 102 (KYC 96): COMMON 102 - the HR tables carry the XXHR_ prefix (XXHR_EMPLOYEES, XXHR_ORGANIZATIONS)
    select count(*) + l_n into l_n from all_objects
     where owner = c_shared and object_name = 'XXHR_ORGANIZATIONS' and object_type = 'TABLE';
    -- release 104 (KYC 97): COMMON 104 - the navigation menu kept in COMMON (XXFND_NAV_PKG)
    select count(*) + l_n into l_n from all_objects
     where owner = c_shared and object_name = 'XXFND_NAV_PKG' and object_type = 'PACKAGE';
    if l_n < 6 then
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

    -- release 87: KYC must be registered in COMMON (the registration routines refuse an unknown application)
    execute immediate 'select count(*) from ' || c_shared || '.xxfnd_applications where application_code = ''KYC'''
       into l_n;
    if l_n = 0 then
        raise_application_error(-20905,
            'ACTION NEEDED - KYC is not registered in COMMON. Nothing was installed.' || chr(10)
            || '1. As ' || c_shared || ', run apex/db/admin/onboard-application.sql (the KYC APEX application ID, code KYC).'
            || chr(10)
            || '2. Come back: App Builder > KYC > Utilities > Supporting Objects > Install Supporting Objects (or Upgrade).');
    end if;

    -- release 87: synonyms of shared objects COMMON has removed (their replacement keeps another name)
    for s in (select synonym_name from user_synonyms u
               where u.table_owner = c_shared
                 and (u.synonym_name like 'XXFND\_%' escape '\' or u.synonym_name like 'XXHR\_%' escape '\')
                 and not exists (select 1 from all_objects o
                                  where o.owner = c_shared and o.object_name = u.table_name)) loop
        execute immediate 'drop synonym ' || s.synonym_name;
    end loop;

    -- release 94: the deployment framework's tables are the schema's own (00 creates them). A synonym of COMMON's
    -- XXFND_DROPPED_OBJECTS (made by earlier releases) hid KYC's own log table, so DROP_OBJECT wrote to COMMON's table
    -- and failed on COMMON 88 or later (ORA-41900); it is dropped, and 00 then creates KYC's table.
    for s in (select synonym_name from user_synonyms
               where synonym_name = 'XXFND_DROPPED_OBJECTS' and table_owner = c_shared) loop
        execute immediate 'drop synonym ' || s.synonym_name;
    end loop;

    for o in (select object_name from all_objects
               where owner = c_shared
                 and (object_name like 'XXFND\_%' escape '\' or object_name like 'XXHR\_%' escape '\')
                 and object_type in ('TABLE', 'VIEW', 'SEQUENCE', 'PACKAGE', 'TYPE', 'PROCEDURE', 'FUNCTION')
                 and object_name not in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG', 'XXFND_DROPPED_OBJECTS')) loop
        select count(*) into l_n from user_objects where object_name = o.object_name;
        if l_n = 0 then
            execute immediate 'create synonym ' || o.object_name || ' for ' || c_shared || '.' || o.object_name;
        end if;
    end loop;

    execute immediate 'begin xxfnd_schema_pkg.apply_policies; end;';
    commit;
end;
/
