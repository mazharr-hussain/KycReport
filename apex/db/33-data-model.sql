--------------------------------------------------------------------------------
-- 33 Data Model (release 89). COMMON only (XXFUSION), after 32 and before 99.
--   The objects of every registered application, read live from the database dictionary: the Object Catalogue
--   (COMMON pages 175 / 176) and the entity-relationship diagram (page 177). An application's objects are the
--   objects of its schema (XXFND_APPLICATIONS.SCHEMA_NAME), narrowed by its optional object prefix
--   (XXFND_DM_APP_SCOPES); its tables may be grouped for the diagram (XXFND_DM_TABLE_GROUPS). IT sees every
--   application, an application's administrators only their own (feature DATA_MODEL managed in the application).
--   The XXFND_DM_*_V views read the DBA_ dictionary views when COMMON's schema has been granted them
--   (apex/db/admin/grant-dictionary-to-xxfusion.sql, by ADMIN; then run this script again: Install Supporting
--   Objects), else the ALL_ views (COMMON's own objects and what it may see of other schemas).
--   XXFND_DATA_MODEL_PKG: the visibility rule, the prefix and group routines, the diagram source (Mermaid text).
-- Idempotent: a re-run changes nothing (the views are rebuilt; a re-run after the grants switches them to DBA_).
--------------------------------------------------------------------------------
declare
    l_new boolean;
begin
    l_new := xxfnd_ddl_pkg.create_table('XXFND_DM_APP_SCOPES', q'~create table xxfnd_dm_app_scopes (
    application_code       varchar2(30)   not null,
    object_prefix          varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_dm_app_scopes_pk primary key (application_code),
    constraint xxfnd_dm_app_scopes_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_dm_app_scopes is 'Release 89: the object prefix of an application in its schema (Data Model): only the objects whose name starts with it are the application''s. No row = every object of the schema.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_DM_APP_SCOPES');
    l_new := xxfnd_ddl_pkg.create_table('XXFND_DM_TABLE_GROUPS', q'~create table xxfnd_dm_table_groups (
    application_code       varchar2(30)   not null,
    table_name             varchar2(128)  not null,
    group_name             varchar2(100)  not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_dm_table_groups_pk primary key (application_code, table_name),
    constraint xxfnd_dm_table_groups_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade
)~');
    if l_new then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_dm_table_groups is 'Release 89: the group (module, area) of an application''s table in the Data Model diagram (XXFND_DATA_MODEL_PKG.REGISTER_TABLE_GROUP).'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_DM_TABLE_GROUPS');
end;
/

create or replace package xxfnd_data_model_pkg authid definer as
    -- Y when the signed-in user may see the application's objects: IT (Common Administrator) every application (or
    -- the one chosen in COMMON's application selector), a delegated administrator only the application that opened
    -- COMMON; outside an APEX session (install, tests) every application.
    function app_visible(p_application_code in varchar2) return varchar2;
    -- Y when the views read the DBA_ dictionary (every schema), N when they read the ALL_ views (COMMON's own
    -- objects and what COMMON may see of other schemas).
    function full_dictionary return varchar2;
    -- The columns of an index: P_DISPLAY Y = as written (function-based columns as their expression), N = the real
    -- columns the index reads (comma separated).
    function index_columns(p_owner in varchar2, p_index_name in varchar2, p_display in varchar2 default 'Y') return varchar2;
    -- The application's object prefix (null = every object of its schema). In an APEX session: Data Model - Manage.
    procedure set_object_prefix(p_application_code in varchar2, p_object_prefix in varchar2);
    -- The group of one of the application's tables in the diagram; added when missing, an administrator's change is kept.
    procedure register_table_group(p_application_code in varchar2, p_table_name in varchar2, p_group_name in varchar2);
    procedure unregister_table_group(p_application_code in varchar2, p_table_name in varchar2);
    -- The prefix and the groups of the application (XXFND_APPLICATION_PKG.DELETE_APPLICATION).
    procedure unregister_application(p_application_code in varchar2);
    -- The diagram of the application as Mermaid text (an erDiagram): P_TABLE given = that table with the tables it
    -- refers to and the tables that refer to it; else P_GROUP given = the tables of the group (tables of other groups
    -- they refer to with their primary key only); else every table and foreign key of the application. Only key
    -- columns (primary, foreign, unique, indexed) are shown.
    function erd_source(p_application_code in varchar2,
                        p_group            in varchar2 default null,
                        p_table            in varchar2 default null) return clob;
end xxfnd_data_model_pkg;
/

-- the views: built on DBA_ when every DBA_ view used here is granted to this schema, else on ALL_
declare
    l_dict varchar2(3) := 'DBA';
    procedure v(p_ddl in varchar2) is
    begin
        execute immediate replace(replace(p_ddl, '#D#', l_dict), '#OWN#', case l_dict when 'DBA' then 'owner' else 'table_schema' end);
    end v;
begin
    for d in (select column_value name from table(apex_t_varchar2(
                  'OBJECTS', 'TAB_COMMENTS', 'COL_COMMENTS', 'TAB_COLS', 'CONSTRAINTS', 'CONS_COLUMNS', 'INDEXES',
                  'IND_COLUMNS', 'IND_EXPRESSIONS', 'TRIGGERS', 'PROCEDURES', 'ARGUMENTS', 'TYPE_ATTRS', 'DEPENDENCIES',
                  'TAB_PRIVS', 'POLICIES'))) loop
        begin
            execute immediate 'select count(*) from sys.dba_' || d.name || ' where 1 = 0';
        exception
            when others then
                l_dict := 'ALL';
        end;
        exit when l_dict = 'ALL';
    end loop;
    dbms_output.put_line('Data Model views read the ' || l_dict || '_ dictionary views.');
    v(q'~create or replace view xxfnd_dm_apps_v as
        select a.application_code, a.application_name, a.schema_name, s.object_prefix
          from xxfnd_applications a
          left join xxfnd_dm_app_scopes s on s.application_code = a.application_code
         where a.schema_name is not null
           and xxfnd_data_model_pkg.app_visible(a.application_code) = 'Y'~');
    v(q'~create or replace view xxfnd_dm_objects_v as
        select p.application_code, o.owner, o.object_name, o.object_type, o.status, o.created, o.last_ddl_time,
               c.comments, g.group_name
          from xxfnd_dm_apps_v p
          join #D#_objects o
            on o.owner = p.schema_name
           and (p.object_prefix is null or o.object_name like replace(p.object_prefix, '_', '\_') || '%' escape '\')
          left join #D#_tab_comments c on c.owner = o.owner and c.table_name = o.object_name and o.object_type in ('TABLE', 'VIEW')
          left join xxfnd_dm_table_groups g on g.application_code = p.application_code and g.table_name = o.object_name
         where o.object_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW', 'PACKAGE', 'PROCEDURE', 'FUNCTION', 'TYPE',
                                 'SEQUENCE', 'TRIGGER')
           and o.secondary = 'N'
           and o.object_name not like 'SYS\_%' escape '\'
           and o.object_name not like 'BIN$%'
           and o.object_name not like 'ISEQ$$%'
           and o.object_name not like 'DR$%'~');
    v(q'~create or replace view xxfnd_dm_columns_v as
        select o.application_code, c.owner, c.table_name, c.column_id, c.column_name,
               case when c.data_type in ('VARCHAR2', 'NVARCHAR2', 'CHAR', 'NCHAR')
                    then c.data_type || '(' || c.char_length || case c.char_used when 'C' then ' CHAR' end || ')'
                    when c.data_type = 'RAW' then 'RAW(' || c.data_length || ')'
                    when c.data_type = 'NUMBER' and c.data_precision is not null
                    then 'NUMBER(' || c.data_precision || case when c.data_scale > 0 then ',' || c.data_scale end || ')'
                    else c.data_type end as data_type,
               c.nullable, c.data_default_vc as data_default, c.identity_column, c.virtual_column, m.comments
          from xxfnd_dm_objects_v o
          join #D#_tab_cols c on c.owner = o.owner and c.table_name = o.object_name and c.hidden_column = 'NO'
          left join #D#_col_comments m on m.owner = c.owner and m.table_name = c.table_name and m.column_name = c.column_name
         where o.object_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW')~');
    v(q'~create or replace view xxfnd_dm_constraints_v as
        select o.application_code, k.owner, k.table_name, k.constraint_name,
               decode(k.constraint_type, 'P', 'Primary key', 'U', 'Unique', 'R', 'Foreign key', 'C', 'Check') as constraint_type,
               k.constraint_type as type_code,
               (select listagg(x.column_name, ', ') within group (order by x.position) from #D#_cons_columns x
                 where x.owner = k.owner and x.constraint_name = k.constraint_name) as column_list,
               r.owner as ref_owner, r.table_name as ref_table,
               (select listagg(x.column_name, ', ') within group (order by x.position) from #D#_cons_columns x
                 where x.owner = r.owner and x.constraint_name = r.constraint_name) as ref_column_list,
               case k.constraint_type when 'R' then k.delete_rule end as delete_rule,
               k.search_condition_vc as condition, k.status
          from xxfnd_dm_objects_v o
          join #D#_constraints k on k.owner = o.owner and k.table_name = o.object_name
          left join #D#_constraints r on r.owner = k.r_owner and r.constraint_name = k.r_constraint_name
         where o.object_type = 'TABLE'
           and k.constraint_type in ('P', 'U', 'R', 'C')
           and not (k.constraint_type = 'C' and k.generated = 'GENERATED NAME' and k.search_condition_vc like '% IS NOT NULL')~');
    v(q'~create or replace view xxfnd_dm_indexes_v as
        select o.application_code, i.table_owner as owner, i.table_name, i.index_name, i.uniqueness, i.index_type,
               xxfnd_data_model_pkg.index_columns(i.owner, i.index_name, 'Y') as column_list,
               xxfnd_data_model_pkg.index_columns(i.owner, i.index_name, 'N') as real_columns
          from xxfnd_dm_objects_v o
          join #D#_indexes i on i.table_owner = o.owner and i.table_name = o.object_name
         where o.object_type = 'TABLE'
           and i.index_type not like 'LOB%'~');
    v(q'~create or replace view xxfnd_dm_triggers_v as
        select o.application_code, t.owner, t.trigger_name, t.table_name, t.trigger_type, t.triggering_event, t.status
          from xxfnd_dm_objects_v o
          join #D#_triggers t on t.owner = o.owner and t.trigger_name = o.object_name
         where o.object_type = 'TRIGGER'~');
    v(q'~create or replace view xxfnd_dm_routines_v as
        select o.application_code, p.owner, o.object_name, o.object_type, p.subprogram_id,
               nvl(p.procedure_name, p.object_name) as routine_name, p.overload,
               (select max(a.data_type) from #D#_arguments a
                 where a.owner = p.owner and a.object_id = p.object_id and a.subprogram_id = p.subprogram_id
                   and a.position = 0 and a.data_level = 0) as returns,
               (select listagg(lower(a.argument_name) || ' ' || lower(a.in_out) || ' '
                               || lower(case when a.type_name is not null and a.data_type in ('OBJECT', 'TABLE', 'VARRAY', 'PL/SQL RECORD', 'PL/SQL TABLE', 'REF')
                                             then nvl2(a.type_owner, a.type_owner || '.', null) || a.type_name else a.data_type end)
                               || case a.defaulted when 'Y' then ' (optional)' end, ', ' on overflow truncate '...' with count)
                       within group (order by a.position)
                  from #D#_arguments a
                 where a.owner = p.owner and a.object_id = p.object_id and a.subprogram_id = p.subprogram_id
                   and a.position > 0 and a.data_level = 0) as parameters
          from xxfnd_dm_objects_v o
          join #D#_procedures p on p.owner = o.owner and p.object_name = o.object_name and p.object_type = o.object_type
         where o.object_type in ('PACKAGE', 'PROCEDURE', 'FUNCTION')
           and (p.procedure_name is not null or o.object_type <> 'PACKAGE')~');
    v(q'~create or replace view xxfnd_dm_type_attrs_v as
        select o.application_code, t.owner, t.type_name, t.attr_no, t.attr_name, t.attr_type_name, t.length, t.precision, t.scale
          from xxfnd_dm_objects_v o
          join #D#_type_attrs t on t.owner = o.owner and t.type_name = o.object_name
         where o.object_type = 'TYPE'~');
    v(q'~create or replace view xxfnd_dm_dependencies_v as
        select distinct o.application_code, d.owner, d.name, o.object_type as type, d.referenced_owner, d.referenced_name,
               d.referenced_type
          from xxfnd_dm_objects_v o
          join #D#_dependencies d on d.owner = o.owner and d.name = o.object_name
                                 and d.type in (o.object_type, o.object_type || ' BODY')
         where d.referenced_owner not in ('SYS', 'PUBLIC')
           and not (d.referenced_owner = d.owner and d.referenced_name = d.name)~');
    v(q'~create or replace view xxfnd_dm_grants_v as
        select o.application_code, g.#OWN# as owner, g.table_name as object_name, g.grantee,
               listagg(g.privilege, ', ') within group (order by g.privilege) as privileges
          from xxfnd_dm_objects_v o
          join #D#_tab_privs g on g.#OWN# = o.owner and g.table_name = o.object_name
         group by o.application_code, g.#OWN#, g.table_name, g.grantee~');
    v(q'~create or replace view xxfnd_dm_policies_v as
        select o.application_code, p.object_owner as owner, p.object_name, p.policy_name,
               p.pf_owner || '.' || nvl2(p.package, p.package || '.', null) || p.function as policy_function,
               rtrim(case p.sel when 'YES' then 'select, ' end || case p.ins when 'YES' then 'insert, ' end
                     || case p.upd when 'YES' then 'update, ' end || case p.del when 'YES' then 'delete, ' end, ', ') as statements
          from xxfnd_dm_objects_v o
          join #D#_policies p on p.object_owner = o.owner and p.object_name = o.object_name~');
end;
/
comment on table xxfnd_dm_objects_v is 'Release 89: the objects of every registered application the user may see (Data Model, COMMON pages 175-177).';

create or replace package body xxfnd_data_model_pkg as

    g_dict varchar2(3);

    -- the dictionary the views were built on (DBA or ALL)
    function dict return varchar2 is
        l_n pls_integer;
    begin
        if g_dict is null then
            select count(*) into l_n from user_dependencies
             where name = 'XXFND_DM_OBJECTS_V' and referenced_name = 'DBA_OBJECTS';
            g_dict := case when l_n > 0 then 'DBA' else 'ALL' end;
        end if;
        return g_dict;
    end dict;

    function full_dictionary return varchar2 is
    begin
        return case dict when 'DBA' then 'Y' else 'N' end;
    end full_dictionary;

    function app_visible(p_application_code in varchar2) return varchar2 is
        l_app varchar2(30) := upper(v('G_ADMIN_APP'));
    begin
        -- release 90: install mode counts as outside APEX (Supporting Objects run in the App Builder's session)
        if not xxfnd_util_pkg.in_apex_session or xxfnd_vpd_pkg.is_trusted then
            return 'Y';
        elsif nvl(upper(v('APP_ALIAS')), '#') <> 'COMMON' then
            return 'N';
        elsif xxfnd_application_pkg.is_common_admin = 'Y' then
            return case when l_app is null or l_app = 'ALL' or l_app = upper(p_application_code) then 'Y' else 'N' end;
        end if;
        return case when xxfnd_application_pkg.delegated_app = upper(p_application_code) then 'Y' else 'N' end;
    end app_visible;

    function index_columns(p_owner in varchar2, p_index_name in varchar2, p_display in varchar2 default 'Y') return varchar2 is
        type t_cols is table of varchar2(4000);
        l_names t_cols;
        l_pos   apex_t_number;
        l_expr  varchar2(32767);
        l_out   apex_t_varchar2 := apex_t_varchar2();
    begin
        execute immediate 'select column_name, column_position from ' || dict || '_ind_columns
                            where index_owner = :o and index_name = :i order by column_position'
            bulk collect into l_names, l_pos using p_owner, p_index_name;
        for i in 1 .. l_names.count loop
            if l_names(i) like 'SYS\_NC%' escape '\' then
                -- a function-based column: its expression (a LONG in the dictionary, read here)
                begin
                    execute immediate 'select column_expression from ' || dict || '_ind_expressions
                                        where index_owner = :o and index_name = :i and column_position = :p'
                        into l_expr using p_owner, p_index_name, l_pos(i);
                exception
                    when no_data_found then
                        l_expr := l_names(i);
                end;
                if p_display = 'Y' then
                    apex_string.push(l_out, l_expr);
                else
                    for c in (select distinct regexp_substr(l_expr, '"([A-Z0-9_$#]+)"', 1, level, null, 1) col
                                from dual connect by level <= regexp_count(l_expr, '"[A-Z0-9_$#]+"')) loop
                        if c.col is not null and c.col not member of l_out then
                            apex_string.push(l_out, c.col);
                        end if;
                    end loop;
                end if;
            elsif p_display = 'Y' or l_names(i) not member of l_out then
                apex_string.push(l_out, l_names(i));
            end if;
        end loop;
        return apex_string.join(l_out, ', ');
    end index_columns;

    procedure check_manage is
    begin
        if xxfnd_util_pkg.in_apex_session and xxfnd_privilege_pkg.has_privilege('DATA_MODEL', 'MANAGE') = false then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
    end check_manage;

    procedure set_object_prefix(p_application_code in varchar2, p_object_prefix in varchar2) is
        l_code xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
    begin
        check_manage;
        if app_visible(l_code) = 'N' then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
        if trim(p_object_prefix) is null then
            delete from xxfnd_dm_app_scopes where application_code = l_code;
        else
            merge into xxfnd_dm_app_scopes t
            using (select l_code application_code, upper(trim(p_object_prefix)) object_prefix from dual) s
               on (t.application_code = s.application_code)
             when matched then update set t.object_prefix = s.object_prefix
             when not matched then insert (application_code, object_prefix) values (s.application_code, s.object_prefix);
        end if;
    end set_object_prefix;

    procedure register_table_group(p_application_code in varchar2, p_table_name in varchar2, p_group_name in varchar2) is
        l_code xxfnd_applications.application_code%type := xxfnd_application_pkg.registered_code(p_application_code);
    begin
        merge into xxfnd_dm_table_groups t
        using (select l_code application_code, upper(trim(p_table_name)) table_name, trim(p_group_name) group_name from dual) s
           on (t.application_code = s.application_code and t.table_name = s.table_name)
         when not matched then insert (application_code, table_name, group_name)
                               values (s.application_code, s.table_name, s.group_name);
    end register_table_group;

    procedure unregister_table_group(p_application_code in varchar2, p_table_name in varchar2) is
    begin
        xxfnd_application_pkg.remove_registered(p_application_code, 'Table group', 'XXFND_DM_TABLE_GROUPS',
            apex_t_varchar2('APPLICATION_CODE', 'TABLE_NAME'),
            apex_t_varchar2(xxfnd_application_pkg.registered_code(p_application_code), upper(trim(p_table_name))));
    end unregister_table_group;

    procedure unregister_application(p_application_code in varchar2) is
    begin
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Table groups', 'XXFND_DM_TABLE_GROUPS');
        xxfnd_application_pkg.remove_all_registered(p_application_code, 'Object prefix', 'XXFND_DM_APP_SCOPES');
    end unregister_application;

    ---------------------------------------------------------------- the diagram (Mermaid erDiagram text, not markup)
    function erd_source(p_application_code in varchar2,
                        p_group            in varchar2 default null,
                        p_table            in varchar2 default null) return clob is
        type t_map  is table of varchar2(4000) index by varchar2(300);
        type t_list is table of apex_t_varchar2 index by varchar2(130);
        l_code   varchar2(30) := upper(p_application_code);
        l_out    clob;
        l_keys   t_map;                                     -- table.column -> PK, FK, UK
        l_ixs    t_map;                                     -- table.column -> its (non primary key) indexes
        l_null   t_map;                                     -- table.column -> Y / N
        l_type   t_map;                                     -- table.column -> data type
        l_cols   t_list;                                    -- table -> its columns in order
        l_pk     apex_t_varchar2 := apex_t_varchar2();      -- primary key constraint names
        l_own    apex_t_varchar2 := apex_t_varchar2();      -- tables drawn with their key columns
        l_stub   apex_t_varchar2 := apex_t_varchar2();      -- other tables drawn with their primary key only
        l_seen   apex_t_varchar2 := apex_t_varchar2();
        l_detail boolean := p_table is not null or p_group is not null;
        type t_fk is record (table_name varchar2(130), ref_table varchar2(130), constraint_name varchar2(130), column_list varchar2(4000));
        type t_fks is table of t_fk;
        l_fks    t_fks;
        procedure w(p_line in varchar2) is
        begin
            dbms_lob.append(l_out, p_line || chr(10));
        end w;
        function nm(p_name in varchar2) return varchar2 is
        begin
            return regexp_replace(p_name, '[^A-Za-z0-9_]', '_');
        end nm;
        procedure add(p_map in out nocopy t_map, p_key in varchar2, p_value in varchar2) is
        begin
            if not p_map.exists(p_key) then
                p_map(p_key) := p_value;
            elsif instr(', ' || p_map(p_key) || ', ', ', ' || p_value || ', ') = 0 then
                p_map(p_key) := p_map(p_key) || ', ' || p_value;
            end if;
        end add;
        procedure entity(p_table in varchar2, p_stub in boolean) is
            l_any boolean := false;
            l_k   varchar2(300);
            l_key varchar2(100);
        begin
            w('    ' || nm(p_table) || ' {');
            if l_cols.exists(p_table) then
                for i in 1 .. l_cols(p_table).count loop
                    l_k   := p_table || '.' || l_cols(p_table)(i);
                    l_key := case when l_keys.exists(l_k) then l_keys(l_k) end;
                    if (p_stub and instr(l_key, 'PK') > 0) or (not p_stub and (l_key is not null or l_ixs.exists(l_k))) then
                        w('        ' || nvl(lower(regexp_substr(l_type(l_k), '^[A-Za-z0-9_]+')), 'x') || ' ' || nm(l_cols(p_table)(i))
                          || case when p_stub then ' PK' when l_key is not null then ' ' || l_key end
                          || case when not p_stub and l_ixs.exists(l_k) then ' "IX ' || l_ixs(l_k) || '"' end);
                        l_any := true;
                    end if;
                end loop;
            end if;
            if not l_any then
                w('        x no_key');
            end if;
            w('    }');
        end entity;
    begin
        if app_visible(l_code) = 'N' then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
        -- the dictionary is read once per diagram
        for c in (select table_name, column_name, data_type, nullable from xxfnd_dm_columns_v
                   where application_code = l_code order by table_name, column_id) loop
            if not l_cols.exists(c.table_name) then
                l_cols(c.table_name) := apex_t_varchar2();
            end if;
            apex_string.push(l_cols(c.table_name), c.column_name);
            l_type(c.table_name || '.' || c.column_name) := c.data_type;
            l_null(c.table_name || '.' || c.column_name) := c.nullable;
        end loop;
        for k in (select table_name, constraint_name, type_code, column_list from xxfnd_dm_constraints_v
                   where application_code = l_code and type_code in ('P', 'R', 'U')
                   order by decode(type_code, 'P', 1, 'R', 2, 3)) loop
            if k.type_code = 'P' then apex_string.push(l_pk, k.constraint_name); end if;
            for c in (select trim(column_value) col from table(apex_string.split(k.column_list, ','))) loop
                add(l_keys, k.table_name || '.' || c.col, case k.type_code when 'P' then 'PK' when 'R' then 'FK' else 'UK' end);
            end loop;
        end loop;
        for i in (select table_name, index_name, real_columns from xxfnd_dm_indexes_v where application_code = l_code) loop
            if i.index_name not member of l_pk then
                for c in (select trim(column_value) col from table(apex_string.split(i.real_columns, ','))) loop
                    add(l_ixs, i.table_name || '.' || c.col, lower(replace(i.index_name, 'XXFND_')));
                end loop;
            end if;
        end loop;
        select table_name, ref_table, constraint_name, column_list bulk collect into l_fks
          from xxfnd_dm_constraints_v
         where application_code = l_code and type_code = 'R'
         order by ref_table, table_name, constraint_name;
        dbms_lob.createtemporary(l_out, true);
        w('erDiagram');
        -- the tables to draw in full
        if p_table is not null then
            apex_string.push(l_own, upper(p_table));
            for i in 1 .. l_fks.count loop
                if l_fks(i).table_name = upper(p_table) and l_fks(i).ref_table not member of l_own then
                    apex_string.push(l_own, l_fks(i).ref_table);
                elsif l_fks(i).ref_table = upper(p_table) and l_fks(i).table_name not member of l_own then
                    apex_string.push(l_own, l_fks(i).table_name);
                end if;
            end loop;
        elsif p_group is not null then
            select object_name bulk collect into l_own from xxfnd_dm_objects_v
             where application_code = l_code and object_type = 'TABLE' and group_name = p_group order by object_name;
        end if;
        if l_detail then
            for i in 1 .. l_own.count loop
                entity(l_own(i), false);
            end loop;
        end if;
        -- the foreign keys (every one of the application, or the ones touching the drawn tables)
        for i in 1 .. l_fks.count loop
            if not l_detail or l_fks(i).table_name member of l_own or l_fks(i).ref_table member of l_own then
                declare
                    l_mand boolean := true;
                begin
                    for c in (select trim(column_value) col from table(apex_string.split(l_fks(i).column_list, ','))) loop
                        if not l_null.exists(l_fks(i).table_name || '.' || c.col) or l_null(l_fks(i).table_name || '.' || c.col) = 'Y' then
                            l_mand := false;
                        end if;
                    end loop;
                    if l_detail then
                        if l_fks(i).table_name not member of l_own and l_fks(i).table_name not member of l_stub then
                            apex_string.push(l_stub, l_fks(i).table_name);
                        end if;
                        if l_fks(i).ref_table not member of l_own and l_fks(i).ref_table not member of l_stub then
                            apex_string.push(l_stub, l_fks(i).ref_table);
                        end if;
                    end if;
                    if l_fks(i).table_name not member of l_seen then apex_string.push(l_seen, l_fks(i).table_name); end if;
                    if l_fks(i).ref_table not member of l_seen then apex_string.push(l_seen, l_fks(i).ref_table); end if;
                    w('    ' || nm(l_fks(i).ref_table) || case when l_mand then ' ||' else ' o|' end || '--o{ '
                      || nm(l_fks(i).table_name) || ' : "' || lower(regexp_replace(l_fks(i).constraint_name, '^.*_(FK[0-9]*)$', '\1'))
                      || ' (' || lower(l_fks(i).column_list) || ')"');
                end;
            end if;
        end loop;
        if l_detail then
            for i in 1 .. l_stub.count loop
                entity(l_stub(i), true);
            end loop;
        else
            -- the overview: the tables without a foreign key, with their primary key
            for t in (select object_name from xxfnd_dm_objects_v
                       where application_code = l_code and object_type = 'TABLE' order by object_name) loop
                if t.object_name not member of l_seen then
                    entity(t.object_name, true);
                end if;
            end loop;
        end if;
        return l_out;
    end erd_source;

end xxfnd_data_model_pkg;
/

-- the feature (Platform; IT at install), its pages, the diagram groups of COMMON's tables and COMMON's prefix
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_privilege_pkg.register_feature(p_application_code => 'COMMON', p_feature_code => 'DATA_MODEL',
        p_feature_name => 'Data Model', p_feature_group => 'PLATFORM', p_display_sequence => 70, p_admin_flag => 'Y',
        p_home_page_id => 175, p_icon_css => 'fa-sitemap',
        p_description => 'The database objects of every registered application, read live from the dictionary: the object catalogue and the entity-relationship diagram.');
    xxfnd_privilege_pkg.register_privilege('COMMON', 'DATA_MODEL', 'VIEW');
    xxfnd_privilege_pkg.register_privilege('COMMON', 'DATA_MODEL', 'MANAGE');
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'DATA_MODEL', 175, 'Objects', 10);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'DATA_MODEL', 176);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'DATA_MODEL', 177, 'Diagram', 20);
    xxfnd_privilege_pkg.add_role_privilege('COMMON', 'COMMON_ADMIN', 'DATA_MODEL.VIEW');
    xxfnd_privilege_pkg.add_role_privilege('COMMON', 'COMMON_ADMIN', 'DATA_MODEL.MANAGE');
    declare
        l_n pls_integer;
        procedure g(p_table in varchar2, p_group in varchar2) is
        begin
            xxfnd_data_model_pkg.register_table_group('COMMON', p_table, p_group);
        end g;
    begin
        select count(*) into l_n from xxfnd_dm_app_scopes where application_code = 'COMMON';
        if l_n = 0 then
            xxfnd_data_model_pkg.set_object_prefix('COMMON', 'XXFND_');
        end if;
        -- COMMON's tables by module (the six modules of COMMON)
        g('XXFND_APPLICATIONS', 'Platform');
        g('XXFND_APPLICATION_FUNCTIONS', 'Platform');
        g('XXFND_APP_MENU_ENTRIES', 'Platform');
        g('XXFND_SETUP_TYPES', 'Platform');
        g('XXFND_SETUP_TYPE_APPS', 'Platform');
        g('XXFND_MESSAGES', 'Platform');
        g('XXFND_ERROR_LOG', 'Platform');
        g('XXFND_SCHEMA_RELEASES', 'Platform');
        g('XXFND_DROPPED_OBJECTS', 'Platform');
        g('XXFND_FEATURES', 'Security');
        g('XXFND_FEATURE_PAGES', 'Security');
        g('XXFND_PRIVILEGES', 'Security');
        g('XXFND_ROLES', 'Security');
        g('XXFND_ROLE_PRIVILEGES', 'Security');
        g('XXFND_USERS', 'Security');
        g('XXFND_USER_ROLES', 'Security');
        g('XXFND_EMPLOYEES', 'Security');
        g('XXFND_DATA_SECURITY_RULES', 'Security');
        g('XXFND_DATA_RULE_ASSIGNMENTS', 'Security');
        g('XXFND_SOD_RULES', 'Security');
        g('XXFND_AUDIT_LOG', 'Security');
        g('XXFND_LOOKUP_TYPES', 'Reference Data');
        g('XXFND_LOOKUP_VALUES', 'Reference Data');
        g('XXFND_LOOKUP_VALUES_TL', 'Reference Data');
        g('XXFND_VALUE_SETS', 'Reference Data');
        g('XXFND_DF_FLEXFIELDS', 'Reference Data');
        g('XXFND_DF_FLEXFIELDS_TL', 'Reference Data');
        g('XXFND_DF_CONTEXTS', 'Reference Data');
        g('XXFND_DF_CONTEXTS_TL', 'Reference Data');
        g('XXFND_DF_SEGMENTS', 'Reference Data');
        g('XXFND_DF_SEGMENTS_TL', 'Reference Data');
        g('XXFND_DOCUMENT_ENTITIES', 'Documents and Records');
        g('XXFND_DOCUMENT_ENTITIES_TL', 'Documents and Records');
        g('XXFND_DOCUMENT_CATEGORIES', 'Documents and Records');
        g('XXFND_DOCUMENT_CATEGORIES_TL', 'Documents and Records');
        g('XXFND_DOCUMENTS', 'Documents and Records');
        g('XXFND_DOCUMENTS_TL', 'Documents and Records');
        g('XXFND_DOCUMENT_FILES', 'Documents and Records');
        g('XXFND_ATTACHED_DOCUMENTS', 'Documents and Records');
        g('XXFND_ATTACHMENT_FUNCTIONS', 'Documents and Records');
        g('XXFND_ATTACHMENT_BLOCKS', 'Documents and Records');
        g('XXFND_ATTACHMENT_BLK_ENTITIES', 'Documents and Records');
        g('XXFND_DOC_CATEGORY_USAGES', 'Documents and Records');
        g('XXFND_ENTITY_CONTAINERS', 'Documents and Records');
        g('XXFND_STORAGE_CONFIG', 'Documents and Records');
        g('XXFND_RETENTION_POLICIES', 'Documents and Records');
        g('XXFND_WORKFLOW_PROCESSES', 'Workflow');
        g('XXFND_TASK_SETTINGS', 'Workflow');
        g('XXFND_TASK_ALERTS', 'Workflow');
        g('XXFND_WF_DELEGATIONS', 'Workflow');
        g('XXFND_CONFIG_TABLES', 'Workflow');
        g('XXFND_APPROVAL_TYPES', 'Workflow');
        g('XXFND_APPROVAL_TYPE_ATTRS', 'Workflow');
        g('XXFND_APPROVAL_RULES', 'Workflow');
        g('XXFND_APPROVAL_RULE_CONDS', 'Workflow');
        g('XXFND_APPROVAL_RULE_STEPS', 'Workflow');
        g('XXFND_APPROVAL_TXNS', 'Workflow');
        g('XXFND_APPROVAL_TXN_STEPS', 'Workflow');
        g('XXFND_RFIS', 'Workflow');
        g('XXFND_RFI_ROUNDS', 'Workflow');
        g('XXFND_NOTIFY_EVENTS', 'Workflow');
        g('XXFND_NOTIFY_CHANNELS', 'Workflow');
        g('XXFND_NOTIFY_RECIPIENT_TYPES', 'Workflow');
        g('XXFND_NOTIFY_RULES', 'Workflow');
        g('XXFND_NOTIFICATION_TEMPLATES', 'Workflow');
        g('XXFND_NOTIFICATION_TEMPLATES_TL', 'Workflow');
        g('XXFND_NOTIFICATIONS', 'Workflow');
        g('XXFND_COMMUNICATIONS', 'Workflow');
        g('XXFND_CONTACT_SOURCES', 'Workflow');
        g('XXFND_SERVERS', 'Integrations');
        g('XXFND_SERVER_TESTS', 'Integrations');
        g('XXFND_INTEGRATION_PURPOSES', 'Integrations');
        g('XXFND_INTEGRATION_CALLS', 'Integrations');
        g('XXFND_TRANSMISSIONS', 'Integrations');
    end;
    -- every registered application gets the new common function and its menu entry (only what is missing)
    for a in (select application_code from xxfnd_applications where application_code <> 'COMMON') loop
        xxfnd_application_pkg.ensure_menu(a.application_code);
    end loop;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
