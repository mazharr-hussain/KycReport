create or replace editionable trigger xxcus.xxcmp_questions_aud after
    insert or update or delete on xxcus.xxcmp_questions
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   to_char(:new.question_id),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   to_char(:old.question_id),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.question_id);
    if ( :old.question_id <> :new.question_id )
    or (
        :old.question_id is null
        and :new.question_id is not null
    )
    or (
        :old.question_id is not null
        and :new.question_id is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'QUESTION_ID',
                                   to_char(:old.question_id,
                                           'TM9'),
                                   to_char(:new.question_id,
                                           'TM9'));
    end if;

    if ( :old.questionnaire_code <> :new.questionnaire_code )
    or (
        :old.questionnaire_code is null
        and :new.questionnaire_code is not null
    )
    or (
        :old.questionnaire_code is not null
        and :new.questionnaire_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'QUESTIONNAIRE_CODE',
                                   :old.questionnaire_code,
                                   :new.questionnaire_code);
    end if;

    if ( :old.section_name <> :new.section_name )
    or (
        :old.section_name is null
        and :new.section_name is not null
    )
    or (
        :old.section_name is not null
        and :new.section_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'SECTION_NAME',
                                   :old.section_name,
                                   :new.section_name);
    end if;

    if ( :old.question_text <> :new.question_text )
    or (
        :old.question_text is null
        and :new.question_text is not null
    )
    or (
        :old.question_text is not null
        and :new.question_text is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'QUESTION_TEXT',
                                   :old.question_text,
                                   :new.question_text);
    end if;

    if ( :old.answer_type <> :new.answer_type )
    or (
        :old.answer_type is null
        and :new.answer_type is not null
    )
    or (
        :old.answer_type is not null
        and :new.answer_type is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'ANSWER_TYPE',
                                   :old.answer_type,
                                   :new.answer_type);
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
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'LOOKUP_TYPE',
                                   :old.lookup_type,
                                   :new.lookup_type);
    end if;

    if ( :old.gate_question_flag <> :new.gate_question_flag )
    or (
        :old.gate_question_flag is null
        and :new.gate_question_flag is not null
    )
    or (
        :old.gate_question_flag is not null
        and :new.gate_question_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'GATE_QUESTION_FLAG',
                                   :old.gate_question_flag,
                                   :new.gate_question_flag);
    end if;

    if ( :old.required_flag <> :new.required_flag )
    or (
        :old.required_flag is null
        and :new.required_flag is not null
    )
    or (
        :old.required_flag is not null
        and :new.required_flag is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'REQUIRED_FLAG',
                                   :old.required_flag,
                                   :new.required_flag);
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
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
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
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONS',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxcmp_questions_aud enable;


-- sqlcl_snapshot {"hash":"aef164b838a90c8f644b03a63099ef07b12e1de7","type":"TRIGGER","name":"XXCMP_QUESTIONS_AUD","schemaName":"XXCUS","sxml":""}