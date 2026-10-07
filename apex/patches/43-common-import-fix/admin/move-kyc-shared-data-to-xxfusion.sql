--------------------------------------------------------------------------------
-- ONE-TIME ADMIN SCRIPT: move KYC's shared data from XXCUS to XXFUSION (release 57).
--   Not part of any application package. Run it ONCE as ADMIN (Database Actions > SQL, or SQL Workshop as a user
--   with the ADMIN privileges), AFTER importing the COMMON application and BEFORE importing KYC. Only for a KYC
--   installed before release 54; a new installation does not need it.
--   A. VALIDATE - checks everything first and changes nothing. If any check fails it stops with ORA-20904 and lists
--      every problem: nothing was changed. Fix them and run the script again.
--        - XXFUSION is ready (COMMON installed: XXFUSION.XXFND_SHARE_PKG);
--        - every shared table and column of XXCUS exists in XXFUSION;
--        - every shared object XXCUS would drop exists in XXFUSION (nothing is dropped without its replacement;
--          flexfield _DFV views are regenerated instead);
--        - every table the XXCMP_ foreign keys reference exists in XXFUSION.
--   B. PERFORM
--        1. the foreign keys of XXCMP_ tables to shared tables are kept in XXCUS.XXCMP_SHARED_FKS;
--        2. the data moves to XXFUSION (xxfnd_share_pkg.import_schema: all keys kept, row counts compared);
--        3. only then XXCUS's copy is dropped (tables, views, packages, types, sequences, jobs, flexfield views);
--        4. a synonym in XXCUS for every shared object; 5. the foreign keys on the XXFUSION tables;
--        6. XXCUS's data security policies use XXFUSION.XXFND_VPD_PKG;
--        7. the flexfield _DFV views are regenerated in XXFUSION; XXCMP_SHARED_FKS is dropped; XXCUS recompiled.
--   XXCUS.XXFND_SCHEMA_RELEASES / XXFND_DDL_PKG stay (release tracking per schema).
-- Safe to re-run after a failure (each step checks what is already done); on a moved XXCUS it changes nothing.
--------------------------------------------------------------------------------
set serveroutput on
declare
    c_shared constant varchar2(128) := 'XXFUSION';
    c_app    constant varchar2(128) := 'XXCUS';
    c_policy constant varchar2(30)  := 'XXFND_DATA_SECURITY';
    l_n        pls_integer;
    l_copy     boolean;
    l_problems varchar2(32767);

    function local_object(p_name in varchar2) return boolean is
    begin
        return p_name in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG');
    end local_object;

    procedure problem(p_text in varchar2) is
    begin
        if length(l_problems) > 3000 then
            return;
        end if;
        l_problems := l_problems || chr(10) || '- ' || p_text;
    end problem;
begin
    select count(*) into l_n from dba_tables where owner = c_app and table_name = 'XXFND_LOOKUP_TYPES';
    l_copy := l_n > 0;

    ------------------------------------------------------------------ A. validate (no changes)
    select count(*) into l_n from dba_objects
     where owner = c_shared and object_name = 'XXFND_SHARE_PKG' and object_type = 'PACKAGE';
    if l_n = 0 then
        problem('The shared objects are not available in ' || c_shared || ': import the COMMON application first'
                || ' (same release, parsing schema ' || c_shared || ', Install Supporting Objects: Yes).');
    end if;
    if l_copy and l_problems is null then
        for c in (select s.table_name, s.column_name from dba_tab_columns s
                   join dba_tables t on t.owner = s.owner and t.table_name = s.table_name
                  where s.owner = c_app and s.table_name like 'XXFND\_%' escape '\'
                    and s.table_name <> 'XXFND_SCHEMA_RELEASES'
                    and not exists (select 1 from dba_tab_columns d
                                     where d.owner = c_shared and d.table_name = s.table_name
                                       and d.column_name = s.column_name)
                  order by 1, 2) loop
            problem('Column ' || c.table_name || '.' || c.column_name || ' is missing in ' || c_shared
                    || ' (import the latest COMMON application first).');
        end loop;
        for o in (select object_type, object_name from dba_objects o
                   where owner = c_app and object_name like 'XXFND\_%' escape '\'
                     and object_type in ('VIEW', 'PACKAGE', 'PROCEDURE', 'FUNCTION', 'TYPE', 'TABLE', 'SEQUENCE')
                     and object_name not in ('XXFND_SCHEMA_RELEASES', 'XXFND_DDL_PKG')
                     -- flexfield views are generated from the flexfield setup (step 7), not copied
                     and not (object_type = 'VIEW' and object_name like '%\_DFV' escape '\')
                     and not exists (select 1 from dba_objects a
                                      where a.owner = c_shared and a.object_name = o.object_name)
                   order by 1, 2) loop
            problem(initcap(o.object_type) || ' ' || o.object_name || ' would be dropped but does not exist in '
                    || c_shared || ' (import the latest COMMON application first).');
        end loop;
        for f in (select distinct c.constraint_name, r.table_name from dba_constraints c
                    join dba_constraints r on r.constraint_name = c.r_constraint_name and r.owner = c.r_owner
                   where c.owner = c_app and c.constraint_type = 'R' and r.owner = c_app
                     and c.table_name not like 'XXFND\_%' escape '\'
                     and r.table_name like 'XXFND\_%' escape '\'
                     and not exists (select 1 from dba_tables a where a.owner = c_shared and a.table_name = r.table_name)
                   order by 1) loop
            problem('Foreign key ' || f.constraint_name || ' references ' || f.table_name || ', which is missing in '
                    || c_shared || '.');
        end loop;
    end if;
    if l_problems is not null then
        raise_application_error(-20904,
            'ACTION NEEDED - the one-time move of the shared data to ' || c_shared || ' was not started. '
            || 'Nothing was changed.' || l_problems || chr(10)
            || 'Then run this script again.');
    end if;

    ------------------------------------------------------------------ B. perform
    execute immediate q'[
        create table if not exists xxcus.xxcmp_shared_fks (
            constraint_name  varchar2(128)  not null,
            table_name       varchar2(128)  not null,
            ddl              varchar2(4000) not null,
            constraint xxcmp_shared_fks_pk primary key (constraint_name))]';

    if l_copy then
        -- 1. the foreign keys to the shared tables
        execute immediate q'[
        insert into xxcus.xxcmp_shared_fks (constraint_name, table_name, ddl)
        select c.constraint_name, c.table_name,
               'alter table ' || c.table_name || ' add constraint ' || c.constraint_name || ' foreign key ('
               || (select listagg(cc.column_name, ', ') within group (order by cc.position)
                     from dba_cons_columns cc where cc.owner = c.owner and cc.constraint_name = c.constraint_name)
               || ') references ]' || c_shared || q'[.' || r.table_name || ' ('
               || (select listagg(rc.column_name, ', ') within group (order by rc.position)
                     from dba_cons_columns rc where rc.owner = r.owner and rc.constraint_name = r.constraint_name)
               || ')' || case c.delete_rule when 'CASCADE' then ' on delete cascade'
                                            when 'SET NULL' then ' on delete set null' end
          from dba_constraints c
          join dba_constraints r on r.constraint_name = c.r_constraint_name and r.owner = c.r_owner
         where c.owner = 'XXCUS' and c.constraint_type = 'R'
           and c.table_name not like 'XXFND\_%' escape '\'
           and r.table_name like 'XXFND\_%' escape '\'
           and r.owner = 'XXCUS'
           and c.constraint_name not in (select constraint_name from xxcus.xxcmp_shared_fks)]';
        commit;

        -- 2. the data (validated again inside: columns, row counts; moved once). The workspace lets the move
        --    re-seed COMMON's first administrators (the workspace administrators).
        begin
            apex_util.set_workspace(c_app);
        exception
            when others then
                null;
        end;
        for t in (select table_name from dba_tables where owner = c_app and table_name like 'XXFND\_%' escape '\') loop
            continue when local_object(t.table_name);
            execute immediate 'grant select on ' || c_app || '.' || t.table_name || ' to ' || c_shared;
        end loop;
        execute immediate 'call ' || c_shared || '.xxfnd_share_pkg.import_schema(:s)' using c_app;

        -- 3. only now: drop XXCUS's copy
        for j in (select job_name from dba_scheduler_jobs where owner = c_app and job_name like 'XXFND\_%' escape '\') loop
            dbms_scheduler.drop_job(c_app || '.' || j.job_name, force => true);
        end loop;
        for o in (select object_type, object_name from dba_objects
                   where owner = c_app and (object_name like 'XXFND\_%' escape '\'
                          or (object_type = 'VIEW' and object_name like '%\_DFV' escape '\'))
                     and object_type in ('VIEW', 'PACKAGE', 'PROCEDURE', 'FUNCTION', 'TYPE', 'TABLE', 'SEQUENCE')
                   order by decode(object_type, 'VIEW', 1, 'PACKAGE', 2, 'PROCEDURE', 2, 'FUNCTION', 2,
                                                'TABLE', 3, 'SEQUENCE', 4, 'TYPE', 5)) loop
            continue when local_object(o.object_name);
            execute immediate 'drop ' || o.object_type || ' ' || c_app || '.' || o.object_name
                || case o.object_type when 'TABLE' then ' cascade constraints purge' when 'TYPE' then ' force' end;
        end loop;
    end if;

    -- 4. synonyms for the shared objects
    for o in (select object_name from dba_objects
               where owner = c_shared and object_name like 'XXFND\_%' escape '\'
                 and object_type in ('TABLE', 'VIEW', 'SEQUENCE', 'PACKAGE', 'TYPE', 'PROCEDURE', 'FUNCTION')) loop
        continue when local_object(o.object_name);
        select count(*) into l_n from dba_objects where owner = c_app and object_name = o.object_name;
        if l_n = 0 then
            execute immediate 'create synonym ' || c_app || '.' || o.object_name || ' for ' || c_shared || '.' || o.object_name;
        end if;
    end loop;

    -- 5. the foreign keys, now on the XXFUSION tables
    declare
        type t_fk is record (constraint_name varchar2(128), ddl varchar2(4000));
        type t_fks is table of t_fk;
        l_fks t_fks;
    begin
        execute immediate 'select constraint_name, ddl from xxcus.xxcmp_shared_fks' bulk collect into l_fks;
        for i in 1 .. l_fks.count loop
            select count(*) into l_n from dba_constraints where owner = c_app and constraint_name = l_fks(i).constraint_name;
            if l_n = 0 then
                execute immediate replace(l_fks(i).ddl, 'alter table ', 'alter table ' || c_app || '.');
            end if;
            execute immediate 'delete from xxcus.xxcmp_shared_fks where constraint_name = :c' using l_fks(i).constraint_name;
            commit;
        end loop;
    end;

    -- 6. data security policies use XXFUSION's policy function (as xxfnd_schema_pkg.apply_policies)
    for p in (select object_name from dba_policies
               where object_owner = c_app and policy_name = c_policy and pf_owner <> c_shared) loop
        dbms_rls.drop_policy(object_schema => c_app, object_name => p.object_name, policy_name => c_policy);
        dbms_rls.add_policy(object_schema   => c_app, object_name => p.object_name, policy_name => c_policy,
                            function_schema => c_shared, policy_function => 'XXFND_VPD_PKG.POLICY',
                            statement_types => 'SELECT,INSERT,UPDATE,DELETE', update_check => true,
                            policy_type     => dbms_rls.dynamic);
    end loop;

    -- 7. flexfield views from the moved setup (an XXCMP_ table not yet granted to XXFUSION is generated when the
    --    KYC import has granted it: Descriptive Flexfields > Recreate view, or the next COMMON upgrade)
    execute immediate 'call ' || c_shared || '.xxfnd_dff_setup_pkg.generate_all_dfv_views()';
    -- done: the work table goes
    execute immediate 'drop table if exists xxcus.xxcmp_shared_fks purge';
    -- XXCUS's own code now compiles against the synonyms
    dbms_utility.compile_schema(c_app, compile_all => false);
    dbms_output.put_line('Done: the shared data is in ' || c_shared || '; ' || c_app || ' uses synonyms. Now import KYC.');
end;
/
