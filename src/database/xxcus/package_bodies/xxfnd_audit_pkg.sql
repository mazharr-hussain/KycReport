create or replace package body xxcus.xxfnd_audit_pkg as

    g_reason varchar2(1000);

    procedure set_change_reason (
        p_reason in varchar2
    ) is
    begin
        g_reason := substr(p_reason, 1, 1000);
    end set_change_reason;

    function get_change_reason return varchar2 is
    begin
        return g_reason;
    end get_change_reason;

    procedure clear_change_reason is
    begin
        g_reason := null;
    end clear_change_reason;

    procedure log_change (
        p_table_name in varchar2,
        p_pk_value   in varchar2,
        p_action     in varchar2,
        p_column     in varchar2 default null,
        p_old_value  in varchar2 default null,
        p_new_value  in varchar2 default null
    ) is
    begin
        insert into xxfnd_audit_log (
            table_name,
            pk_value,
            action_code,
            column_name,
            old_value,
            new_value,
            change_reason,
            changed_by
        ) values
            ( p_table_name,
              p_pk_value,
              p_action,
              p_column,
              substr(p_old_value, 1, 4000),
              substr(p_new_value, 1, 4000),
              g_reason,
              xxfnd_util_pkg.current_user );

    end log_change;

    function col_to_char (
        p_ref       in varchar2,
        p_data_type in varchar2
    ) return varchar2 is
    begin
        return
            case
                when p_data_type like 'TIMESTAMP%' then
                    'to_char('
                    || p_ref
                    || ', ''YYYY-MM-DD HH24:MI:SS.FF'')'
                when p_data_type = 'DATE'   then
                    'to_char('
                    || p_ref
                    || ', ''YYYY-MM-DD HH24:MI:SS'')'
                when p_data_type = 'NUMBER' then
                    'to_char('
                    || p_ref
                    || ', ''TM9'')'
                else
                    p_ref
            end;
    end col_to_char;

    procedure create_audit_trigger (
        p_table_name in varchar2
    ) is

        l_table  varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_trg    varchar2(128) := substr(l_table, 1, 124)
                               || '_AUD';
        l_pk_new varchar2(4000);
        l_pk_old varchar2(4000);
        l_body   clob;
    begin
        for c in (
            select
                cc.column_name
            from
                     user_constraints uc
                join user_cons_columns cc on cc.constraint_name = uc.constraint_name
            where
                    uc.table_name = l_table
                and uc.constraint_type = 'P'
            order by
                cc.position
        ) loop
            l_pk_new := l_pk_new
                        ||
                case
                    when l_pk_new is not null then
                        ' || ''|'' || '
                end
                        || 'to_char(:new.'
                        || c.column_name
                        || ')';

            l_pk_old := l_pk_old
                        ||
                case
                    when l_pk_old is not null then
                        ' || ''|'' || '
                end
                        || 'to_char(:old.'
                        || c.column_name
                        || ')';

        end loop;

        if l_pk_new is null then
            raise_application_error(-20101, l_table || ' has no primary key; cannot generate audit trigger.');
        end if;

        l_body := 'create or replace trigger '
                  || l_trg
                  || '
            after insert or update or delete on '
                  || l_table
                  || '
            for each row
            declare
                l_pk varchar2(400);
            begin
                if inserting then
                    xxfnd_audit_pkg.log_change('''
                  || l_table
                  || ''', '
                  || l_pk_new
                  || ', ''I'');
                    return;
                elsif deleting then
                    xxfnd_audit_pkg.log_change('''
                  || l_table
                  || ''', '
                  || l_pk_old
                  || ', ''D'');
                    return;
                end if;
                l_pk := '
                  || l_pk_new
                  || ';
';

        for c in (
            select
                column_name,
                data_type
            from
                user_tab_columns
            where
                    table_name = l_table
                and data_type not in ( 'CLOB', 'BLOB', 'NCLOB', 'LONG', 'LONG RAW',
                                       'RAW', 'JSON' )
                and column_name not in ( 'CREATED_BY', 'CREATION_DATE', 'LAST_UPDATED_BY', 'LAST_UPDATE_DATE', 'LAST_UPDATE_LOGIN',
                                         'OBJECT_VERSION_NUMBER' )
            order by
                column_id
        ) loop
            l_body := l_body
                      || '
                if (:old.'
                      || c.column_name
                      || ' <> :new.'
                      || c.column_name
                      || ')
                   or (:old.'
                      || c.column_name
                      || ' is null and :new.'
                      || c.column_name
                      || ' is not null)
                   or (:old.'
                      || c.column_name
                      || ' is not null and :new.'
                      || c.column_name
                      || ' is null) then
                    xxfnd_audit_pkg.log_change('''
                      || l_table
                      || ''', l_pk, ''U'', '''
                      || c.column_name
                      || ''',
                        '
                      || col_to_char(':old.' || c.column_name, c.data_type)
                      || ',
                        '
                      || col_to_char(':new.' || c.column_name, c.data_type)
                      || ');
                end if;';
        end loop;

        l_body := l_body || '
            end;';
        execute immediate l_body;
    end create_audit_trigger;

    procedure create_config_audit_triggers is

        type t_names is
            table of varchar2(128);
        l_tables t_names := t_names('XXFND_LOOKUP_TYPES', 'XXFND_LOOKUP_VALUES', 'XXFND_EMPLOYEES', 'XXFND_ROLES', 'XXFND_USER_ROLES'
        ,
                                    'XXFND_SOD_RULES', 'XXFND_NOTIFICATION_TEMPLATES', 'XXFND_RETENTION_POLICIES', 'XXFND_INTEGRATION_ENDPOINTS'
                                    , 'XXFND_INTEGRATION_PURPOSES',
                                    'XXFND_DOCUMENT_ENTITIES', 'XXFND_DOCUMENT_CATEGORIES', 'XXFND_ATTACHMENT_FUNCTIONS', 'XXFND_ATTACHMENT_BLOCKS'
                                    , 'XXFND_ATTACHMENT_BLK_ENTITIES',
                                    'XXFND_DOC_CATEGORY_USAGES', 'XXFND_STORAGE_CONFIG', 'XXFND_WF_DELEGATIONS', 'XXFND_VALUE_SETS', 'XXFND_DF_FLEXFIELDS'
                                    ,
                                    'XXFND_DF_CONTEXTS', 'XXFND_DF_SEGMENTS', 'XXCMP_QUESTIONNAIRES', 'XXCMP_QUESTIONS', 'XXCMP_ANSWER_OPTIONS'
                                    ,
                                    'XXCMP_CONCLUSION_TEMPLATES', 'XXCMP_APPROVAL_MATRIX', 'XXCMP_ATTACHMENT_RULES');
    begin
        for i in 1..l_tables.count loop
            create_audit_trigger(l_tables(i));
        end loop;
    end create_config_audit_triggers;

end xxfnd_audit_pkg;
/


-- sqlcl_snapshot {"hash":"77a6f131b22a0350ea81a76389ec2a66b16c1943","type":"PACKAGE_BODY","name":"XXFND_AUDIT_PKG","schemaName":"XXCUS","sxml":""}