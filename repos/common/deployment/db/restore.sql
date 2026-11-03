--------------------------------------------------------------------------------
-- Step 5.3, run as the application schema (proxy) after the LAST release is installed: puts the backed-up data back
-- into the old release's tables, so the upgrade (5.4) runs over real data. Validation database only.
--   - only tables that exist in both; only columns that exist in both (virtual / hidden columns left out)
--   - foreign keys and triggers are disabled during the load and enabled (validated) after it
--   - identity columns and sequences are moved past the restored keys, so the upgrade's own inserts do not collide
--   - a table that cannot be loaded (e.g. a NOT NULL column the backup does not have) is reported and left as the
--     old install created it
--   - every foreign key is validated again; child rows without their parent (a production database never has them -
--     they come from earlier test runs or a table kept as installed) are deleted and reported. When such a row is itself
--     the parent of rows whose key is already back on (ORA-02292), those keys are switched off again and checked in the
--     next pass, so their rows go too. A key still invalid after 10 passes is enabled for new rows only (NOVALIDATE)
--     and reported - the step completes, every reason printed
-- Substitution variables: bkp_schema, restore_exclude (comma list of tables never restored).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_bkp      constant varchar2(128) := dbms_assert.simple_sql_name(upper('&bkp_schema'));
    l_exclude  constant varchar2(4000) := ',' || upper(replace('&restore_exclude', ' ')) || ',';
    l_cols     varchar2(32767);
    l_rows     number;
    l_total    number := 0;
    l_loaded   pls_integer := 0;
    l_skipped  pls_integer := 0;
    l_max_key  number := 0;
    l_key      number;
    type t_list is table of varchar2(1000);
    l_fks      t_list := t_list();
    l_fk_names t_list := t_list();                      -- constraint names, same order as l_fks
    l_fk_sql   t_list := t_list();                      -- the enable statements (l_fks: null once validated)
    l_pending  pls_integer;
    l_orphans  number;
    l_deleted  number := 0;
    l_triggers t_list := t_list();
    l_always   t_list := t_list();
    l_fk_fail  pls_integer := 0;
    type t_pol is table of user_policies%rowtype;
    l_policies t_pol;
    -- VPD policies off for this step (the DDL above invalidates the policy package: ORA-28112 / ORA-04061);
    -- always switched back on, also when the step fails
    procedure policies(p_enable boolean) is
    begin
        for i in 1 .. l_policies.count loop
            dbms_rls.enable_policy(object_schema => user, object_name => l_policies(i).object_name,
                                   policy_name => l_policies(i).policy_name, enable => p_enable);
        end loop;
    end policies;
    -- deletes the rows of the key's table whose (complete) foreign key has no parent row (MATCH SIMPLE: a key with
    -- a null column is valid)
    procedure delete_orphans(p_constraint varchar2, p_count out number) is
        l_table  varchar2(128);
        l_parent varchar2(128);
        l_filled varchar2(4000);
        l_join   varchar2(4000);
    begin
        for k in (select c.table_name, p.table_name as parent_table, cc.column_name, pc.column_name as parent_column
                    from user_constraints c
                    join user_cons_columns cc on cc.constraint_name = c.constraint_name
                    join user_constraints p on p.constraint_name = c.r_constraint_name
                    join user_cons_columns pc on pc.constraint_name = p.constraint_name and pc.position = cc.position
                   where c.constraint_name = p_constraint
                   order by cc.position) loop
            l_table  := k.table_name;
            l_parent := k.parent_table;
            l_filled := l_filled || ' and c."' || k.column_name || '" is not null';
            l_join   := l_join || ' and p."' || k.parent_column || '" = c."' || k.column_name || '"';
        end loop;
        execute immediate 'delete from "' || l_table || '" c where 1 = 1' || l_filled
            || ' and not exists (select 1 from "' || l_parent || '" p where 1 = 1' || l_join || ')';
        p_count := sql%rowcount;
        commit;
    end delete_orphans;
    -- delete_orphans for key i; rows that are parents of rows under a key already back on (ORA-02292): that key is
    -- switched off again and marked to be checked in the next pass, then the delete is retried
    procedure clear_orphans(i pls_integer, p_count out number) is
        e_child exception;
        pragma exception_init(e_child, -2292);
        l_table varchar2(128);
    begin
        select table_name into l_table from user_constraints where constraint_name = l_fk_names(i);
        for attempt in 1 .. 20 loop
            begin
                delete_orphans(l_fk_names(i), p_count);
                return;
            exception
                when e_child then
                    rollback;
                    if attempt = 20 then raise; end if;
                    for k in (select ch.table_name, ch.constraint_name from user_constraints ch
                                join user_constraints pa on pa.constraint_name = ch.r_constraint_name
                               where ch.constraint_type = 'R' and ch.status = 'ENABLED' and pa.table_name = l_table) loop
                        execute immediate 'alter table "' || k.table_name || '" disable constraint "' || k.constraint_name || '"';
                        for j in 1 .. l_fk_names.count loop
                            if l_fk_names(j) = k.constraint_name then l_fks(j) := l_fk_sql(j); end if;
                        end loop;
                        dbms_output.put_line('INFO ' || k.constraint_name || ' off again: its parent rows in ' || l_table
                            || ' have no parent themselves');
                    end loop;
            end;
        end loop;
    end clear_orphans;
begin
    select * bulk collect into l_policies from user_policies where enable = 'YES';
    policies(false);
    begin
    -- foreign keys and triggers off for the load
    for c in (select table_name, constraint_name from user_constraints
               where constraint_type = 'R' and status = 'ENABLED') loop
        execute immediate 'alter table "' || c.table_name || '" disable constraint "' || c.constraint_name || '"';
        l_fks.extend; l_fks(l_fks.count) := '"' || c.table_name || '" enable validate constraint "' || c.constraint_name || '"';
        l_fk_sql.extend; l_fk_sql(l_fk_sql.count) := l_fks(l_fks.count);
        l_fk_names.extend; l_fk_names(l_fk_names.count) := c.constraint_name;
    end loop;
    for g in (select trigger_name from user_triggers where status = 'ENABLED' and base_object_type = 'TABLE') loop
        execute immediate 'alter trigger "' || g.trigger_name || '" disable';
        l_triggers.extend; l_triggers(l_triggers.count) := g.trigger_name;
    end loop;
    -- GENERATED ALWAYS identities accept the backed-up keys only while they are BY DEFAULT
    for i in (select table_name, column_name from user_tab_identity_cols where generation_type = 'ALWAYS') loop
        execute immediate 'alter table "' || i.table_name || '" modify ("' || i.column_name
            || '" generated by default as identity)';
        l_always.extend; l_always(l_always.count) := '"' || i.table_name || '" modify ("' || i.column_name || '"';
    end loop;

    for t in (select b.table_name from all_tables b
               where b.owner = l_bkp
                 and exists (select 1 from user_tables u where u.table_name = b.table_name)
                 and instr(l_exclude, ',' || b.table_name || ',') = 0
               order by b.table_name) loop
        l_cols := null;
        for c in (select u.column_name from user_tab_cols u
                   where u.table_name = t.table_name and u.virtual_column = 'NO' and u.hidden_column = 'NO'
                     and exists (select 1 from all_tab_cols b
                                  where b.owner = l_bkp and b.table_name = u.table_name and b.column_name = u.column_name)
                   order by u.column_id) loop
            l_cols := l_cols || case when l_cols is not null then ', ' end || '"' || c.column_name || '"';
        end loop;
        savepoint before_table;
        begin
            execute immediate 'delete from "' || t.table_name || '"';
            execute immediate 'insert into "' || t.table_name || '" (' || l_cols || ') select ' || l_cols
                || ' from ' || l_bkp || '."' || t.table_name || '"';
            l_rows   := sql%rowcount;
            l_total  := l_total + l_rows;
            l_loaded := l_loaded + 1;
        exception
            when others then
                rollback to before_table;
                l_skipped := l_skipped + 1;
                dbms_output.put_line('INFO not restored (kept as installed): ' || t.table_name || ' - ' || sqlerrm);
        end;
    end loop;
    commit;

    -- foreign keys back on, validated. A production database never holds child rows without their parent, so rows
    -- the backup holds without one (left by earlier test runs, or a parent table kept as installed) are deleted and
    -- reported; several passes, because deleting orphans can orphan their own children.
    for pass in 1 .. 10 loop
        l_pending := 0;
        for i in 1 .. l_fks.count loop
            if l_fks(i) is not null then
                begin
                    execute immediate 'alter table ' || l_fks(i);
                    l_fks(i) := null;                                   -- validated
                exception
                    when others then
                        l_pending := l_pending + 1;
                        clear_orphans(i, l_orphans);
                        l_deleted := l_deleted + l_orphans;
                        dbms_output.put_line('INFO orphan rows deleted for ' || l_fk_names(i) || ': ' || l_orphans
                            || ' (' || sqlerrm || ')');
                end;
            end if;
        end loop;
        exit when l_pending = 0;
    end loop;
    for i in 1 .. l_fks.count loop                                      -- still not valid after 10 passes
        if l_fks(i) is not null then
            l_fk_fail := l_fk_fail + 1;
            dbms_output.put_line('INFO key not validated: ' || l_fk_names(i));
            execute immediate 'alter table ' || replace(l_fks(i), ' enable validate ', ' enable novalidate ');
        end if;
    end loop;
    for i in 1 .. l_triggers.count loop
        execute immediate 'alter trigger "' || l_triggers(i) || '" enable';
    end loop;
    for i in 1 .. l_always.count loop
        execute immediate 'alter table ' || l_always(i) || ' generated always as identity (start with limit value))';
    end loop;
    for i in (select c.table_name, c.column_name, t.default_on_null from user_tab_identity_cols c
                join user_tab_columns t on t.table_name = c.table_name and t.column_name = c.column_name
               where c.generation_type = 'BY DEFAULT') loop
        execute immediate 'alter table "' || i.table_name || '" modify ("' || i.column_name || '" generated by default'
            || case i.default_on_null when 'YES' then ' on null' end || ' as identity (start with limit value))';
    end loop;

    -- sequences: past the highest restored single-column numeric primary key
    for k in (select c.table_name, cc.column_name from user_constraints c
                join user_cons_columns cc on cc.constraint_name = c.constraint_name and cc.table_name = c.table_name
                join user_tab_columns tc on tc.table_name = c.table_name and tc.column_name = cc.column_name
               where c.constraint_type = 'P' and tc.data_type = 'NUMBER'
                 and (select count(*) from user_cons_columns x where x.constraint_name = c.constraint_name) = 1) loop
        execute immediate 'select nvl(max("' || k.column_name || '"), 0) from "' || k.table_name || '"' into l_key;
        l_max_key := greatest(l_max_key, l_key);
    end loop;
    for s in (select sequence_name from user_sequences
               where last_number <= l_max_key and sequence_name not like 'ISEQ$$%') loop   -- identities: above
        execute immediate 'alter sequence "' || s.sequence_name || '" restart start with ' || (l_max_key + 1);
    end loop;

    dbms_output.put_line('restored ' || l_loaded || ' table(s), ' || l_total || ' row(s) from ' || l_bkp
        || case when l_skipped > 0 then '; ' || l_skipped || ' table(s) kept as installed' end
        || case when l_deleted > 0 then '; ' || l_deleted || ' orphan row(s) deleted' end
        || case when l_fk_fail > 0 then '; ' || l_fk_fail || ' key(s) not validated' end);
    exception
        when others then
            policies(true);
            raise;
    end;
    policies(true);
    dbms_utility.compile_schema(schema => user, compile_all => false);   -- what the DDL above invalidated
end;
/
