create or replace editionable trigger xxcus.xxcmp_answer_options_aud after
    insert or update or delete on xxcus.xxcmp_answer_options
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   to_char(:new.answer_option_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   to_char(:old.answer_option_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.answer_option_id);
    if ( :old.answer_option_id <> :new.answer_option_id )
    or (
        :old.answer_option_id is null
        and :new.answer_option_id is not null
    )
    or (
        :old.answer_option_id is not null
        and :new.answer_option_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'ANSWER_OPTION_ID',
                                   to_char(:old.answer_option_id,
                                           'TM9'),
                                   to_char(:new.answer_option_id,
                                           'TM9'));
    end if;

    if ( :old.question_id <> :new.question_id )
    or (
        :old.question_id is null
        and :new.question_id is not null
    )
    or (
        :old.question_id is not null
        and :new.question_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'QUESTION_ID',
                                   to_char(:old.question_id,
                                           'TM9'),
                                   to_char(:new.question_id,
                                           'TM9'));
    end if;

    if ( :old.lookup_type <> :new.lookup_type )
    or (
        :old.lookup_type is null
        and :new.lookup_type is not null
    )
    or (
        :old.lookup_type is not null
        and :new.lookup_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'LOOKUP_TYPE',
                                   :old.lookup_type,
                                   :new.lookup_type);
    end if;

    if ( :old.lookup_code <> :new.lookup_code )
    or (
        :old.lookup_code is null
        and :new.lookup_code is not null
    )
    or (
        :old.lookup_code is not null
        and :new.lookup_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'LOOKUP_CODE',
                                   :old.lookup_code,
                                   :new.lookup_code);
    end if;

    if ( :old.answer_label <> :new.answer_label )
    or (
        :old.answer_label is null
        and :new.answer_label is not null
    )
    or (
        :old.answer_label is not null
        and :new.answer_label is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'ANSWER_LABEL',
                                   :old.answer_label,
                                   :new.answer_label);
    end if;

    if ( :old.risk_points <> :new.risk_points )
    or (
        :old.risk_points is null
        and :new.risk_points is not null
    )
    or (
        :old.risk_points is not null
        and :new.risk_points is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'RISK_POINTS',
                                   to_char(:old.risk_points,
                                           'TM9'),
                                   to_char(:new.risk_points,
                                           'TM9'));
    end if;

    if ( :old.critical_flag <> :new.critical_flag )
    or (
        :old.critical_flag is null
        and :new.critical_flag is not null
    )
    or (
        :old.critical_flag is not null
        and :new.critical_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'CRITICAL_FLAG',
                                   :old.critical_flag,
                                   :new.critical_flag);
    end if;

    if ( :old.waiver_qualifying_flag <> :new.waiver_qualifying_flag )
    or (
        :old.waiver_qualifying_flag is null
        and :new.waiver_qualifying_flag is not null
    )
    or (
        :old.waiver_qualifying_flag is not null
        and :new.waiver_qualifying_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'WAIVER_QUALIFYING_FLAG',
                                   :old.waiver_qualifying_flag,
                                   :new.waiver_qualifying_flag);
    end if;

    if ( :old.display_sequence <> :new.display_sequence )
    or (
        :old.display_sequence is null
        and :new.display_sequence is not null
    )
    or (
        :old.display_sequence is not null
        and :new.display_sequence is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'DISPLAY_SEQUENCE',
                                   to_char(:old.display_sequence,
                                           'TM9'),
                                   to_char(:new.display_sequence,
                                           'TM9'));
    end if;

    if ( :old.enabled_flag <> :new.enabled_flag )
    or (
        :old.enabled_flag is null
        and :new.enabled_flag is not null
    )
    or (
        :old.enabled_flag is not null
        and :new.enabled_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

    if ( :old.approval_status <> :new.approval_status )
    or (
        :old.approval_status is null
        and :new.approval_status is not null
    )
    or (
        :old.approval_status is not null
        and :new.approval_status is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'APPROVAL_STATUS',
                                   :old.approval_status,
                                   :new.approval_status);
    end if;

    if ( :old.approved_by <> :new.approved_by )
    or (
        :old.approved_by is null
        and :new.approved_by is not null
    )
    or (
        :old.approved_by is not null
        and :new.approved_by is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'APPROVED_BY',
                                   :old.approved_by,
                                   :new.approved_by);
    end if;

    if ( :old.approved_date <> :new.approved_date )
    or (
        :old.approved_date is null
        and :new.approved_date is not null
    )
    or (
        :old.approved_date is not null
        and :new.approved_date is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_ANSWER_OPTIONS',
                                   l_pk,
                                   'U',
                                   'APPROVED_DATE',
                                   to_char(:old.approved_date,
                                           'YYYY-MM-DD HH24:MI:SS.FF'),
                                   to_char(:new.approved_date,
                                           'YYYY-MM-DD HH24:MI:SS.FF'));
    end if;

end;
/

alter trigger xxcus.xxcmp_answer_options_aud enable;


-- sqlcl_snapshot {"hash":"185393be597799945e64887c5721db1d31d49ed2","type":"TRIGGER","name":"XXCMP_ANSWER_OPTIONS_AUD","schemaName":"XXCUS","sxml":""}