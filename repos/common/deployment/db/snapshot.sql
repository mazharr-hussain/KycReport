--------------------------------------------------------------------------------
-- Steps 6.4 (before the upgrade) and 6.6 (after it), run as the application schema (proxy), validation DB only.
-- I-076: no backup schema - the snapshot is a list printed by this block and kept as a file by db/run.sh
-- (LOG_DIR/snapshot-before.txt, -after.txt); db/snapshot_compare.py compares the two.
-- db/run.sh writes the head of this block: "declare ... l_list t_list := t_list('<TABLE>', ...);" - the
-- application's own tables (db/app_objects.py), then appends this file. Per table that exists it prints:
--   T <table> <rows>                        every table
--   R <table> <primary key> <row hash>      every row of a table with a primary key (TAB separated)
-- The row hash covers the comparable columns (no LOB / object types). VPD policies are off while it reads (as the
-- old compare step did) and always switched back on.
--------------------------------------------------------------------------------
    type t_pol is table of user_policies%rowtype;
    l_policies t_pol;
    l_pk     varchar2(32767);
    l_hash   varchar2(32767);
    l_rows   number;
    l_cur    sys_refcursor;
    l_key    varchar2(4000);
    l_h      number;
    l_n      pls_integer;
    procedure policies(p_enable boolean) is
    begin
        for i in 1 .. l_policies.count loop
            dbms_rls.enable_policy(object_schema => user, object_name => l_policies(i).object_name,
                                   policy_name => l_policies(i).policy_name, enable => p_enable);
        end loop;
    end policies;
begin
    select * bulk collect into l_policies from user_policies where enable = 'YES';
    policies(false);
    begin
        for i in 1 .. l_list.count loop
            select count(*) into l_n from user_tables where table_name = l_list(i);
            continue when l_n = 0;
            execute immediate 'select count(*) from "' || l_list(i) || '"' into l_rows;
            dbms_output.put_line('T' || chr(9) || l_list(i) || chr(9) || l_rows);
            l_pk := null;
            for c in (select cc.column_name from user_constraints k
                        join user_cons_columns cc on cc.constraint_name = k.constraint_name and cc.table_name = k.table_name
                       where k.table_name = l_list(i) and k.constraint_type = 'P' order by cc.position) loop
                l_pk := l_pk || case when l_pk is not null then ' || ''|'' || ' end || 'to_char("' || c.column_name || '")';
            end loop;
            continue when l_pk is null or l_rows = 0;
            l_hash := '0';
            for c in (select column_name, column_id from user_tab_cols
                       where table_name = l_list(i) and virtual_column = 'NO' and hidden_column = 'NO'
                         and data_type not in ('CLOB', 'NCLOB', 'BLOB', 'BFILE', 'LONG', 'LONG RAW', 'XMLTYPE', 'JSON')
                         and data_type_owner is null
                       order by column_id) loop
                l_hash := l_hash || ' + nvl(ora_hash("' || c.column_name || '"), 0) * ' || c.column_id;
            end loop;
            open l_cur for 'select substr(' || l_pk || ', 1, 4000), ' || l_hash || ' from "' || l_list(i) || '"';
            loop
                fetch l_cur into l_key, l_h;
                exit when l_cur%notfound;
                dbms_output.put_line('R' || chr(9) || l_list(i) || chr(9) || l_key || chr(9) || l_h);
            end loop;
            close l_cur;
        end loop;
    exception
        when others then
            policies(true);
            raise;
    end;
    policies(true);
end;
/
