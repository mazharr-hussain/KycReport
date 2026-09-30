create or replace editionable trigger xxcus.xxcmp_questionnaires_aud after
    insert or update or delete on xxcus.xxcmp_questionnaires
    for each row
declare
    l_pk varchar2(400);
begin
    if inserting then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   to_char(:new.questionnaire_code),
                                   'I');
        return;
    elsif deleting then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   to_char(:old.questionnaire_code),
                                   'D');
        return;
    end if;

    l_pk := to_char(:new.questionnaire_code);
    if ( :old.questionnaire_code <> :new.questionnaire_code )
    or (
        :old.questionnaire_code is null
        and :new.questionnaire_code is not null
    )
    or (
        :old.questionnaire_code is not null
        and :new.questionnaire_code is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'QUESTIONNAIRE_CODE',
                                   :old.questionnaire_code,
                                   :new.questionnaire_code);
    end if;

    if ( :old.questionnaire_name <> :new.questionnaire_name )
    or (
        :old.questionnaire_name is null
        and :new.questionnaire_name is not null
    )
    or (
        :old.questionnaire_name is not null
        and :new.questionnaire_name is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'QUESTIONNAIRE_NAME',
                                   :old.questionnaire_name,
                                   :new.questionnaire_name);
    end if;

    if ( :old.audience <> :new.audience )
    or (
        :old.audience is null
        and :new.audience is not null
    )
    or (
        :old.audience is not null
        and :new.audience is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'AUDIENCE',
                                   :old.audience,
                                   :new.audience);
    end if;

    if ( :old.low_risk_max_score <> :new.low_risk_max_score )
    or (
        :old.low_risk_max_score is null
        and :new.low_risk_max_score is not null
    )
    or (
        :old.low_risk_max_score is not null
        and :new.low_risk_max_score is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'LOW_RISK_MAX_SCORE',
                                   to_char(:old.low_risk_max_score,
                                           'TM9'),
                                   to_char(:new.low_risk_max_score,
                                           'TM9'));
    end if;

    if ( :old.medium_risk_max_score <> :new.medium_risk_max_score )
    or (
        :old.medium_risk_max_score is null
        and :new.medium_risk_max_score is not null
    )
    or (
        :old.medium_risk_max_score is not null
        and :new.medium_risk_max_score is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'MEDIUM_RISK_MAX_SCORE',
                                   to_char(:old.medium_risk_max_score,
                                           'TM9'),
                                   to_char(:new.medium_risk_max_score,
                                           'TM9'));
    end if;

    if ( :old.current_version_number <> :new.current_version_number )
    or (
        :old.current_version_number is null
        and :new.current_version_number is not null
    )
    or (
        :old.current_version_number is not null
        and :new.current_version_number is null
    ) then
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'CURRENT_VERSION_NUMBER',
                                   to_char(:old.current_version_number,
                                           'TM9'),
                                   to_char(:new.current_version_number,
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
        xxfnd_audit_pkg.log_change('XXCMP_QUESTIONNAIRES',
                                   l_pk,
                                   'U',
                                   'ENABLED_FLAG',
                                   :old.enabled_flag,
                                   :new.enabled_flag);
    end if;

end;
/

alter trigger xxcus.xxcmp_questionnaires_aud enable;


-- sqlcl_snapshot {"hash":"5f546681fa0a29951cff32e9ae0dccb7ddd5d737","type":"TRIGGER","name":"XXCMP_QUESTIONNAIRES_AUD","schemaName":"XXCUS","sxml":""}