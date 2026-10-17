
begin
    if xxfnd_ddl_pkg.create_table('XXCMP_CONCLUSION_TEMPLATES', q'~create table xxcmp_conclusion_templates (
    risk_tier              varchar2(30)   not null,
    template_name          varchar2(240)  not null,
    template_text          clob           not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_conclusion_templates_pk primary key (risk_tier),
    constraint xxcmp_conclusion_templates_ck1 check (enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxcmp_conclusion_templates is 'Pre-filled Compliance Report conclusion by risk tier. Tokens: #PARTY_NAME#, #REQUEST_NUMBER#, #RISK_TIER#, #RISK_FACTORS#.'~');
    end if;
end;
/
