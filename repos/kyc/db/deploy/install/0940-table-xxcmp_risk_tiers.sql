begin

    if xxfnd_ddl_pkg.create_table('XXCMP_RISK_TIERS', q'~create table xxcmp_risk_tiers (
    risk_tier              varchar2(30)   not null,
    model_code             varchar2(30)   default 'KYC' not null,
    min_score              number         not null,
    review_months          number         not null,
    approved_min_score     number,
    approved_review_months number,
    approval_status        varchar2(30)   default 'DRAFT' not null,
    approved_by            varchar2(255),
    approved_date          timestamp,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      not null,
    last_updated_by        varchar2(255)  not null,
    last_update_date       timestamp      not null,
    last_update_login      varchar2(255),
    object_version_number  number         default 1 not null,
    constraint xxcmp_risk_tiers_pk primary key (risk_tier),
    constraint xxcmp_risk_tiers_ck1 check (approval_status in ('DRAFT','PENDING_APPROVAL','APPROVED','REJECTED')),
    constraint xxcmp_risk_tiers_ck2 check (min_score >= 0 and review_months between 1 and 120)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxcmp_risk_tiers is 'Risk tiers of the model: the score from which each applies and its review interval (months). Maker-checker; APPROVED_* = in use.'~');
    end if;
end;
/
