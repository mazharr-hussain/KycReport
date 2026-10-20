
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
    -- The application's object prefix (null = every object of its schema; release 102: several, comma separated, e.g.
    -- XXFND_,XXHR_). In an APEX session: Data Model - Manage.
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
        l_app  varchar2(30) := upper(v('G_ADMIN_APP'));
        l_apps apex_t_varchar2;
    begin
        -- release 90: install mode counts as outside APEX (Supporting Objects run in the App Builder's session)
        if not xxfnd_util_pkg.in_apex_session or xxfnd_vpd_pkg.is_trusted then
            return 'Y';
        elsif nvl(upper(v('APP_ALIAS')), '#') <> 'COMMON' then
            return 'N';
        elsif xxfnd_application_pkg.is_common_admin = 'Y' then
            return case when l_app is null or l_app = 'ALL' or l_app = upper(p_application_code) then 'Y' else 'N' end;
        end if;
        -- release 106: anyone else - the applications whose roles give the privilege of the running page
        l_apps := xxfnd_application_pkg.feature_apps;
        return case when upper(p_application_code) member of l_apps then 'Y' else 'N' end;
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
