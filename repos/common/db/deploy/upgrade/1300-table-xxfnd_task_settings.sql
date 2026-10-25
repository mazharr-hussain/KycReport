
--------------------------------------------------------------------------------
-- Deadlines and escalation (Workflow Setup > Deadlines and Escalation)
--------------------------------------------------------------------------------
create table if not exists xxfnd_task_settings (
    task_definition        varchar2(255)  not null,
    due_days               number,
    reminder_days_before   number,
    escalation_role_code   varchar2(30),
    notify_on_create_flag  varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_task_settings_pk primary key (task_definition),
    constraint xxfnd_task_settings_fk1 foreign key (escalation_role_code) references xxfnd_roles (role_code),
    constraint xxfnd_task_settings_ck1 check (due_days > 0),
    constraint xxfnd_task_settings_ck2 check (reminder_days_before >= 0),
    constraint xxfnd_task_settings_ck3 check (notify_on_create_flag in ('Y','N'))
);
comment on table xxfnd_task_settings is 'Per APEX task definition (static ID): due date in days from creation, reminder before it, role that receives overdue tasks, e-mail on creation.';
