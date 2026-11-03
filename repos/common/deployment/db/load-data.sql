--------------------------------------------------------------------------------
-- Steps 4.2b, 5.3 and 5.7, run as the application schema (proxy): the test data file (db/load_data.py puts the rows
-- in at --DATA--). Every row: MERGE on the table's primary key - inserted when missing, updated when there. The
-- validation database only. Mode strict: a missing table / column or a row that does not load fails the step (all
-- reasons printed first); tolerant: they are reported (INFO) and left out.
--------------------------------------------------------------------------------
set define off verify off feedback off serveroutput on size unlimited
declare
    l_mode     constant varchar2(10) := '&mode';
    l_data     clob;
    type t_cols is table of varchar2(32767) index by varchar2(128);
    type t_seen is table of boolean index by varchar2(300);
    type t_list is table of varchar2(1000);
    type t_pol is table of user_policies%rowtype;
    l_row      t_cols;
    l_table    varchar2(128);
    l_rowno    varchar2(20);
    l_reported t_seen;
    l_fail     pls_integer := 0;
    l_info     pls_integer := 0;
    l_merged   pls_integer := 0;
    l_tables   t_seen;
    l_triggers t_list := t_list();
    l_always   t_list := t_list();
    l_policies t_pol;
    l_max_key  number := 0;
    l_key      number;

    procedure problem(p_text varchar2) is
    begin
        if l_mode = 'strict' then
            dbms_output.put_line('FAIL ' || p_text); l_fail := l_fail + 1;
        else
            dbms_output.put_line('INFO left out: ' || p_text); l_info := l_info + 1;
        end if;
    end problem;

    procedure once(p_key varchar2, p_text varchar2) is
    begin
        if not l_reported.exists(p_key) then l_reported(p_key) := true; problem(p_text); end if;
    end once;

    procedure merge_row(p_table varchar2, p_rowno varchar2, p_cols in out nocopy t_cols) is
        l_n      pls_integer;
        l_type   varchar2(128);
        l_col    varchar2(128);
        l_sel    varchar2(32767);
        l_on     varchar2(4000);
        l_set    varchar2(32767);
        l_ins    varchar2(32767);
        l_val    varchar2(32767);
        l_binds  t_list := t_list();
        l_names  t_list := t_list();
        l_pk     t_seen;
        l_cur    integer;
        l_dummy  integer;
    begin
        select count(*) into l_n from user_tables where table_name = p_table;
        if l_n = 0 then
            once(p_table, 'table ' || p_table || ' is not in the database'); return;
        end if;
        l_tables(p_table) := true;
        for k in (select cc.column_name from user_constraints c
                    join user_cons_columns cc on cc.constraint_name = c.constraint_name and cc.table_name = c.table_name
                   where c.table_name = p_table and c.constraint_type = 'P') loop
            l_pk(k.column_name) := true;
            if not p_cols.exists(k.column_name) then
                problem(p_table || ' row ' || p_rowno || ': no value for its key column ' || k.column_name); return;
            end if;
        end loop;
        if l_pk.count = 0 then once(p_table || '#pk', p_table || ' has no primary key - its rows cannot be merged'); return; end if;
        -- the WHO columns a row does not give
        for w in (select column_name from user_tab_columns
                   where table_name = p_table and column_name in ('CREATED_BY', 'LAST_UPDATED_BY', 'CREATION_DATE', 'LAST_UPDATE_DATE')) loop
            if not p_cols.exists(w.column_name) then
                p_cols(w.column_name) := case when w.column_name like '%\_BY' escape '\' then 'TEST_DATA'
                                              else to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') end;
            end if;
        end loop;
        l_col := p_cols.first;
        while l_col is not null loop
            begin
                select data_type into l_type from user_tab_columns where table_name = p_table and column_name = l_col;
            exception
                when no_data_found then l_type := null;
            end;
            if l_type is null then
                once(p_table || '.' || l_col, 'column ' || p_table || '.' || l_col || ' is not in the database');
            else
                l_val := p_cols(l_col);
                l_binds.extend; l_binds(l_binds.count) := l_val;
                l_names.extend; l_names(l_names.count) := l_col;
                l_sel := l_sel || case when l_sel is not null then ', ' end || case
                    when l_type = 'DATE' then 'to_date(rpad(:b' || l_binds.count || ', 19, '' 00:00:00''), ''YYYY-MM-DD HH24:MI:SS'')'
                    when l_type like 'TIMESTAMP%' then 'to_timestamp(rpad(:b' || l_binds.count || ', 19, '' 00:00:00''), ''YYYY-MM-DD HH24:MI:SS'')'
                    when l_type in ('NUMBER', 'FLOAT', 'BINARY_DOUBLE', 'BINARY_FLOAT') then 'to_number(:b' || l_binds.count || ')'
                    when l_type = 'CLOB' then 'to_clob(:b' || l_binds.count || ')'
                    when l_type = 'BLOB' then 'to_blob(hextoraw(substr(:b' || l_binds.count || ', 5)))'
                    else ':b' || l_binds.count end || ' "' || l_col || '"';
                l_ins := l_ins || case when l_ins is not null then ', ' end || '"' || l_col || '"';
                if l_pk.exists(l_col) then
                    l_on := l_on || case when l_on is not null then ' and ' end || 't."' || l_col || '" = s."' || l_col || '"';
                elsif l_col not in ('CREATED_BY', 'CREATION_DATE') then
                    l_set := l_set || case when l_set is not null then ', ' end || 't."' || l_col || '" = s."' || l_col || '"';
                end if;
            end if;
            l_col := p_cols.next(l_col);
        end loop;
        l_cur := dbms_sql.open_cursor;
        begin
            dbms_sql.parse(l_cur, 'merge into "' || p_table || '" t using (select ' || l_sel || ' from dual) s on (' || l_on || ')'
                || case when l_set is not null then ' when matched then update set ' || l_set end
                || ' when not matched then insert (' || l_ins || ') values ('
                || regexp_replace(l_ins, '"([A-Z0-9_$#]+)"', 's."\1"') || ')', dbms_sql.native);
            for i in 1 .. l_binds.count loop
                dbms_sql.bind_variable(l_cur, ':b' || i, l_binds(i), 32767);
            end loop;
            l_dummy := dbms_sql.execute(l_cur);
            dbms_sql.close_cursor(l_cur);
            l_merged := l_merged + 1;
        exception
            when others then
                if dbms_sql.is_open(l_cur) then dbms_sql.close_cursor(l_cur); end if;
                problem(p_table || ' row ' || p_rowno || ': ' || sqlerrm);
        end;
    end merge_row;

    procedure policies(p_enable boolean) is
    begin
        for i in 1 .. l_policies.count loop
            dbms_rls.enable_policy(object_schema => user, object_name => l_policies(i).object_name,
                                   policy_name => l_policies(i).policy_name, enable => p_enable);
        end loop;
    end policies;

    procedure switch_back is   -- triggers, identities and policies as they were (also when the load fails)
    begin
        for i in 1 .. l_triggers.count loop execute immediate 'alter trigger "' || l_triggers(i) || '" enable'; end loop;
        l_triggers.delete;
        for i in 1 .. l_always.count loop
            execute immediate 'alter table ' || l_always(i) || ' generated always as identity (start with limit value))';
        end loop;
        l_always.delete;
        policies(true);
    end switch_back;

    procedure parse_data is
        l_pos   integer := 1;
        l_end   integer;
        l_line  varchar2(32767);
        l_p1    integer;
        l_p2    integer;
        l_p3    integer;
        l_no    varchar2(20);
        l_tab   varchar2(128);
    begin
        loop
            l_end := dbms_lob.instr(l_data, chr(10), l_pos);
            exit when l_end = 0 or l_end is null;
            l_line := dbms_lob.substr(l_data, l_end - l_pos, l_pos);
            l_pos  := l_end + 1;
            l_p1 := instr(l_line, '|'); l_p2 := instr(l_line, '|', l_p1 + 1); l_p3 := instr(l_line, '|', l_p2 + 1);
            l_no  := substr(l_line, 1, l_p1 - 1);
            l_tab := substr(l_line, l_p1 + 1, l_p2 - l_p1 - 1);
            if l_rowno is not null and l_no <> l_rowno then
                merge_row(l_table, l_rowno, l_row); l_row.delete;
            end if;
            l_rowno := l_no; l_table := l_tab;
            l_row(substr(l_line, l_p2 + 1, l_p3 - l_p2 - 1)) :=
                replace(replace(replace(substr(l_line, l_p3 + 1), '\\', chr(1)), '\n', chr(10)), chr(1), '\');
        end loop;
        if l_rowno is not null then merge_row(l_table, l_rowno, l_row); end if;
    end parse_data;
begin
    execute immediate q'~alter session set nls_numeric_characters = '.,'~';
    dbms_lob.createtemporary(l_data, true);
    --DATA--
    select * bulk collect into l_policies from user_policies where enable = 'YES';
    policies(false);
    begin
        for g in (select trigger_name from user_triggers where status = 'ENABLED' and base_object_type = 'TABLE') loop
            execute immediate 'alter trigger "' || g.trigger_name || '" disable';
            l_triggers.extend; l_triggers(l_triggers.count) := g.trigger_name;
        end loop;
        for i in (select table_name, column_name from user_tab_identity_cols where generation_type = 'ALWAYS') loop
            execute immediate 'alter table "' || i.table_name || '" modify ("' || i.column_name || '" generated by default as identity)';
            l_always.extend; l_always(l_always.count) := '"' || i.table_name || '" modify ("' || i.column_name || '"';
        end loop;
        parse_data;
        if l_fail > 0 then
            rollback;
            raise_application_error(-20004, 'The test data did not load: ' || l_fail || ' problem(s) - see the FAIL lines.');
        end if;
        commit;
    exception
        when others then
            rollback;
            switch_back;
            raise;
    end;
    switch_back;
    -- identities and sequences past the loaded keys, so the application's own inserts do not collide with them
    for i in (select c.table_name, c.column_name, t.default_on_null from user_tab_identity_cols c
                join user_tab_columns t on t.table_name = c.table_name and t.column_name = c.column_name
               where c.generation_type = 'BY DEFAULT') loop
        execute immediate 'alter table "' || i.table_name || '" modify ("' || i.column_name || '" generated by default'
            || case i.default_on_null when 'YES' then ' on null' end || ' as identity (start with limit value))';
    end loop;
    for k in (select c.table_name, cc.column_name from user_constraints c
                join user_cons_columns cc on cc.constraint_name = c.constraint_name and cc.table_name = c.table_name
                join user_tab_columns tc on tc.table_name = c.table_name and tc.column_name = cc.column_name
               where c.constraint_type = 'P' and tc.data_type = 'NUMBER'
                 and (select count(*) from user_cons_columns x where x.constraint_name = c.constraint_name) = 1) loop
        execute immediate 'select nvl(max("' || k.column_name || '"), 0) from "' || k.table_name || '"' into l_key;
        l_max_key := greatest(l_max_key, l_key);
    end loop;
    for s in (select sequence_name from user_sequences
               where last_number <= l_max_key and sequence_name not like 'ISEQ$$%') loop
        execute immediate 'alter sequence "' || s.sequence_name || '" restart start with ' || (l_max_key + 1);
    end loop;
    dbms_output.put_line('test data: ' || l_merged || ' row(s) inserted or updated in ' || l_tables.count || ' table(s)'
        || case when l_info > 0 then '; ' || l_info || ' left out (INFO lines)' end);
    dbms_lob.freetemporary(l_data);
    dbms_utility.compile_schema(schema => user, compile_all => false);   -- what the DDL above invalidated
end;
/
