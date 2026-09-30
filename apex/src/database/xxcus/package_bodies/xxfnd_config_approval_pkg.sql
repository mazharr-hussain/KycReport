create or replace package body xxcus.xxfnd_config_approval_pkg as

    procedure rows_of (
        p_detail_pk in varchar2,
        p_table     out varchar2,
        p_keys      out apex_t_varchar2
    ) is

        l_table varchar2(128) := substr(p_detail_pk,
                                        1,
                                        instr(p_detail_pk, ':') - 1);
        l_key   varchar2(150) := substr(p_detail_pk,
                                      instr(p_detail_pk, ':') + 1);
    begin
        if l_table = 'XXCMP_QUESTIONS' then
            p_table := 'XXCMP_ANSWER_OPTIONS';
            select
                to_char(answer_option_id)
            bulk collect
            into p_keys
            from
                xxcmp_answer_options
            where
                    question_id = to_number(l_key)
                and approval_status = 'PENDING_APPROVAL';

        else
            p_table := l_table;
            p_keys := apex_t_varchar2(l_key);
        end if;
    end rows_of;

    procedure request (
        p_table_name in varchar2,
        p_key        in varchar2
    ) is

        l_detail_pk varchar2(200) := upper(p_table_name)
                                     || ':'
                                     || p_key;
        l_title     varchar2(4000);
        l_type      varchar2(100);
        l_task_id   number;
        l_open      pls_integer;
    begin
        if upper(p_table_name) = 'XXCMP_QUESTIONS' then
            for r in (
                select
                    answer_option_id
                from
                    xxcmp_answer_options
                where
                        question_id = to_number(p_key)
                    and approval_status in ( 'DRAFT', 'REJECTED' )
            ) loop
                xxfnd_approval_pkg.submit('XXCMP_ANSWER_OPTIONS',
                                          to_char(r.answer_option_id));
            end loop;
        else
            xxfnd_approval_pkg.submit(
                upper(p_table_name),
                p_key
            );
        end if;

        select
            count(*)
        into l_open
        from
            apex_tasks
        where
                task_def_static_id = 'CONFIG_CHANGE'
            and detail_pk = l_detail_pk
            and state_code in ( 'UNASSIGNED', 'ASSIGNED', 'INFO_REQUESTED' );

        if l_open = 0 then
            select
                max(change_type),
                max(change_title)
            into
                l_type,
                l_title
            from
                xxfnd_config_changes_v
            where
                detail_pk = l_detail_pk;

            if l_type is null then
                raise_application_error(-20125, 'There is nothing to approve for '
                                                || l_detail_pk
                                                || '.');
            end if;

            l_task_id := xxfnd_task_pkg.create_task(
                p_task_definition => 'CONFIG_CHANGE',
                p_detail_pk       => l_detail_pk,
                p_subject         => substr(l_type
                                    || ': '
                                    || l_title, 1, 1000)
            );

        end if;

    end request;

    procedure approve (
        p_detail_pk in varchar2
    ) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        if is_pending(p_detail_pk) = 'N' then
            raise_application_error(-20126, 'This change is no longer waiting for approval. Ask a workflow administrator to cancel the task.'
            );
        end if;

        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1..l_keys.count loop
            xxfnd_approval_pkg.approve(l_table,
                                       l_keys(i));
        end loop;

    end approve;

    procedure reject (
        p_detail_pk in varchar2,
        p_reason    in varchar2
    ) is
        l_table varchar2(128);
        l_keys  apex_t_varchar2;
    begin
        rows_of(p_detail_pk, l_table, l_keys);
        for i in 1..l_keys.count loop
            xxfnd_approval_pkg.reject(l_table,
                                      l_keys(i),
                                      nvl(p_reason, 'Rejected by the approver.'));
        end loop;

    end reject;

    function is_pending (
        p_detail_pk in varchar2
    ) return varchar2 is
        l_count pls_integer;
    begin
        select
            count(*)
        into l_count
        from
            xxfnd_config_changes_v
        where
            detail_pk = p_detail_pk;

        return
            case
                when l_count > 0 then
                    'Y'
                else
                    'N'
            end;
    end is_pending;

end xxfnd_config_approval_pkg;
/


-- sqlcl_snapshot {"hash":"0ecf2c863b7cd06fb2cf9d367ea7f8db1a73eb61","type":"PACKAGE_BODY","name":"XXFND_CONFIG_APPROVAL_PKG","schemaName":"XXCUS","sxml":""}