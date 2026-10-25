
begin
    if xxfnd_ddl_pkg.create_table('XXCMP_APPROVAL_MATRIX', q'~create table xxcmp_approval_matrix (
    risk_tier              varchar2(30)   not null,
    required_levels        number(1)      not null,
    level1_role_code       varchar2(30)   not null,
    level2_role_code       varchar2(30),
    sar_gate_flag          varchar2(1)    default 'N' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_approval_matrix_pk primary key (risk_tier),
    constraint xxcmp_approval_matrix_fk1 foreign key (level1_role_code) references xxfusion.xxfnd_roles (role_code),
    constraint xxcmp_approval_matrix_fk2 foreign key (level2_role_code) references xxfusion.xxfnd_roles (role_code),
    constraint xxcmp_approval_matrix_ck1 check (required_levels in (1,2)),
    constraint xxcmp_approval_matrix_ck2 check (
        (required_levels = 1 and level2_role_code is null) or
        (required_levels = 2 and level2_role_code is not null and level2_role_code <> level1_role_code)),
    constraint xxcmp_approval_matrix_ck3 check (sar_gate_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxcmp_approval_matrix is 'Approval levels and roles by risk tier. Enhanced KYC always takes the HIGH row regardless of tier (applied in XXCMP_APPROVAL logic, Module 2).'~');
    end if;
end;
/
