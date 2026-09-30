create or replace editionable trigger xxcus.xxfnd_wf_delegations_aud after
    insert or update or delete on xxcus.xxfnd_wf_delegations
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   to_char(:new.delegation_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   to_char(:old.delegation_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.delegation_id);
    if ( :old.delegation_id <> :new.delegation_id )
    or (
        :old.delegation_id is null
        and :new.delegation_id is not null
    )
    or (
        :old.delegation_id is not null
        and :new.delegation_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'DELEGATION_ID',
                                   to_char(:old.delegation_id,
                                           'TM9'),
                                   to_char(:new.delegation_id,
                                           'TM9'));
    end if;

    if ( :old.delegator_user_name <> :new.delegator_user_name )
    or (
        :old.delegator_user_name is null
        and :new.delegator_user_name is not null
    )
    or (
        :old.delegator_user_name is not null
        and :new.delegator_user_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'DELEGATOR_USER_NAME',
                                   :old.delegator_user_name,
                                   :new.delegator_user_name);
    end if;

    if ( :old.delegate_user_name <> :new.delegate_user_name )
    or (
        :old.delegate_user_name is null
        and :new.delegate_user_name is not null
    )
    or (
        :old.delegate_user_name is not null
        and :new.delegate_user_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'DELEGATE_USER_NAME',
                                   :old.delegate_user_name,
                                   :new.delegate_user_name);
    end if;

    if ( :old.task_definition <> :new.task_definition )
    or (
        :old.task_definition is null
        and :new.task_definition is not null
    )
    or (
        :old.task_definition is not null
        and :new.task_definition is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'TASK_DEFINITION',
                                   :old.task_definition,
                                   :new.task_definition);
    end if;

    if ( :old.start_date <> :new.start_date )
    or (
        :old.start_date is null
        and :new.start_date is not null
    )
    or (
        :old.start_date is not null
        and :new.start_date is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'START_DATE',
                                   to_char(:old.start_date,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.start_date,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

    if ( :old.end_date <> :new.end_date )
    or (
        :old.end_date is null
        and :new.end_date is not null
    )
    or (
        :old.end_date is not null
        and :new.end_date is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'END_DATE',
                                   to_char(:old.end_date,
                                           'YYYY-MM-DD HH24:MI:SS'),
                                   to_char(:new.end_date,
                                           'YYYY-MM-DD HH24:MI:SS'));
    end if;

    if ( :old.reason <> :new.reason )
    or (
        :old.reason is null
        and :new.reason is not null
    )
    or (
        :old.reason is not null
        and :new.reason is null
    ) then
        xxfnd_audit_pkg.log_change('XXFND_WF_DELEGATIONS',
                                   l_pk,
                                   'U',
                                   'REASON',
                                   :old.reason,
                                   :new.reason);
    end if;

end;
/

alter trigger xxcus.xxfnd_wf_delegations_aud enable;


-- sqlcl_snapshot {"hash":"77be5651a5d401337beae21c92b18e2c66ae3dba","type":"TRIGGER","name":"XXFND_WF_DELEGATIONS_AUD","schemaName":"XXCUS","sxml":""}