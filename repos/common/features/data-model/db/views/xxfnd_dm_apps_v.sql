
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
           -- release 102: one prefix or several, comma separated (COMMON: XXFND_,XXHR_)
           and (p.object_prefix is null
                or exists (select 1 from table(apex_string.split(p.object_prefix, ',')) x
                            where trim(x.column_value) is not null
                              and o.object_name like replace(trim(x.column_value), '_', '\_') || '%' escape '\'))
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
