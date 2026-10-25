
--==============================================================================
-- 0.0  KYC RULES ENGINE
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXCMP_QUESTIONNAIRES', q'~create table xxcmp_questionnaires (
    questionnaire_code     varchar2(30)   not null,
    questionnaire_name     varchar2(240)  not null,
    audience               varchar2(20)   not null,
    low_risk_max_score     number,
    medium_risk_max_score  number,
    current_version_number number         default 1 not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_questionnaires_pk primary key (questionnaire_code),
    constraint xxcmp_questionnaires_ck1 check (audience in ('REQUESTER','OFFICER')),
    constraint xxcmp_questionnaires_ck2 check (enabled_flag in ('Y','N')),
    constraint xxcmp_questionnaires_ck3 check (
        low_risk_max_score is null or medium_risk_max_score is null or medium_risk_max_score >= low_risk_max_score),
    constraint xxcmp_questionnaires_ck4 check (
        audience = 'REQUESTER' or (low_risk_max_score is null and medium_risk_max_score is null))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table  xxcmp_questionnaires is 'Requester intake questionnaires (scored, drive routing) and the Officer investigation questionnaire (unscored, informs a manual classification).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxcmp_questionnaires.current_version_number is 'Raised when an approved scoring change goes live. Responses snapshot the version they were scored against.'~');
    end if;
end;
/
