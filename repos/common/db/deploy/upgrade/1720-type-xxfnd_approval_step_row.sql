
create or replace type xxfnd_approval_step_row force as object (
    position       number,
    step_name      varchar2(100),
    approver_type  varchar2(10),
    role_code      varchar2(30),
    user_name      varchar2(255),
    source         varchar2(10),
    added_by       varchar2(255),
    added_comment  varchar2(4000),
    step_state     varchar2(10)
);
/
