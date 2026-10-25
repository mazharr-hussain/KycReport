--------------------------------------------------------------------------------
-- 16u Risk model (release 74, R16). KYC only (XXCUS). The specification is 16u0.
--   Business users maintain the model on page 167 (Risk Model); every change is approved by a second person
--   (maker-checker, CONFIG_CHANGE task) before it scores cases. Each row keeps its last approved values (the
--   APPROVED_* columns, set when the change is approved), so the model in use never changes while a change waits.
--   XXCMP_RISK_FACTORS    what adds to a case's risk score: points (a SCORE factor: % of the questionnaire score),
--                         and the tier it forces (e.g. a FATF black-listed country or a confirmed sanctions match).
--   XXCMP_RISK_COUNTRIES  the country lists the country factors use: FATF black list (call for action), FATF grey
--                         list (increased monitoring) and the company's own list; seeded with the FATF lists known
--                         at build time - Compliance keeps them current (fatf-gafi.org) after each FATF plenary.
--   XXCMP_RISK_TIERS      the score from which a tier applies, and its review interval (months).
--   XXCMP_CASE_RISK_SCORES  how a case's score was made up (kept on submit for approval and on Recalculate).
-- The model only suggests a tier: the officer still classifies the case (shown next to the suggestion).
-- Idempotent (tables only when missing; seed rows only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    if xxfnd_ddl_pkg.create_table('XXCMP_RISK_FACTORS', q'~create table xxcmp_risk_factors (
    factor_code            varchar2(30)   not null,
    model_code             varchar2(30)   default 'KYC' not null,
    factor_name            varchar2(200)  not null,
    description            varchar2(1000),
    factor_type            varchar2(30)   default 'FLAG' not null,
    points                 number         not null,
    force_tier             varchar2(30),
    enabled_flag           varchar2(1)    default 'Y' not null,
    display_sequence       number         default 10 not null,
    approved_points        number,
    approved_force_tier    varchar2(30),
    approved_enabled_flag  varchar2(1),
    approval_status        varchar2(30)   default 'DRAFT' not null,
    approved_by            varchar2(255),
    approved_date          timestamp,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxcmp_risk_factors_pk primary key (factor_code),
    constraint xxcmp_risk_factors_ck1 check (factor_type in ('FLAG','SCORE')),
    constraint xxcmp_risk_factors_ck2 check (enabled_flag in ('Y','N')),
    constraint xxcmp_risk_factors_ck3 check (approval_status in ('DRAFT','PENDING_APPROVAL','APPROVED','REJECTED')),
    constraint xxcmp_risk_factors_ck4 check (points >= 0)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxcmp_risk_factors is 'Risk model factors (maker-checker). FLAG: points when the condition holds; SCORE: % of the questionnaire score. APPROVED_* = the values in use.'~');
    end if;
end;
/
