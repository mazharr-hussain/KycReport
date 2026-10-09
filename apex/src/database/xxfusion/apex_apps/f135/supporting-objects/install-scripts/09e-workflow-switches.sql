--------------------------------------------------------------------------------
-- 09e Workflow and e-mail switches (release 73). COMMON only (XXFUSION). Early, so the shared packages that
--   follow (15 notifications) can ask it.
--   - XXFND_WORKFLOW_PROCESSES: one row per workflow process (APEX workflow static ID) of each registered
--     application. WORKFLOW_ENABLED_FLAG N = the approval is skipped and the record is auto-approved
--     ("Auto-approved (workflow disabled)"); EMAIL_ENABLED_FLAG N = no e-mails for the process.
--   - XXFND_APPLICATIONS.EMAIL_ENABLED_FLAG: e-mail on / off for an application; the COMMON row is the instance.
--   An e-mail is sent only when the instance, the application and the process all have e-mail on. Tasks and
--   in-application notifications do not depend on the e-mail switches.
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'EMAIL_ENABLED_FLAG', q'~varchar2(1) default 'Y' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPLICATIONS', 'XXFND_APPLICATIONS_CK_EMAIL', q'~check (email_enabled_flag in ('Y','N'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_applications.email_enabled_flag is 'E-mail on / off for the application (the COMMON row: for the whole instance).'~');

    if xxfnd_ddl_pkg.create_table('XXFND_WORKFLOW_PROCESSES', q'~create table xxfnd_workflow_processes (
    application_code       varchar2(30)   not null,
    process_code           varchar2(255)  not null,
    process_name           varchar2(255),
    workflow_enabled_flag  varchar2(1)    default 'Y' not null,
    email_enabled_flag     varchar2(1)    default 'Y' not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_workflow_processes_pk primary key (application_code, process_code),
    constraint xxfnd_workflow_processes_fk1 foreign key (application_code)
        references xxfnd_applications (application_code) on delete cascade,
    constraint xxfnd_workflow_processes_ck1 check (workflow_enabled_flag in ('Y','N')),
    constraint xxfnd_workflow_processes_ck2 check (email_enabled_flag in ('Y','N'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_workflow_processes is 'Workflow processes (APEX workflow static ID) per application: approval workflow on / off (off = auto-approved) and e-mail on / off.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_WORKFLOW_PROCESSES');
end;
/

create or replace package xxfnd_workflow_switch_pkg authid definer as
    c_auto_approved constant varchar2(100) := 'Auto-approved (workflow disabled)';
    -- Y when the approval workflow of the process is on for the application (default: the running one); Y when
    -- the process is not registered.
    function workflow_enabled(p_process_code in varchar2, p_application_code in varchar2 default null) return varchar2;
    -- Y when e-mail is on for the instance, the application (default: the running one) and the process (when given).
    function email_enabled(p_process_code in varchar2 default null, p_application_code in varchar2 default null) return varchar2;
    -- The workflow process (static ID) an APEX task belongs to, else null.
    function process_of_task(p_task_id in number) return varchar2;
    -- One row per APEX workflow of every registered application (new ones on, existing rows kept).
    procedure sync_processes;
end xxfnd_workflow_switch_pkg;
/

create or replace package body xxfnd_workflow_switch_pkg as

    function app_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        if p_application_code is not null then
            return upper(p_application_code);
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'))
            or apex_application_id = to_number(v('APP_ID'));
        return l_code;
    end app_code;

    function workflow_enabled(p_process_code in varchar2, p_application_code in varchar2 default null) return varchar2 is
        l_flag xxfnd_workflow_processes.workflow_enabled_flag%type;
        l_app  xxfnd_applications.application_code%type := app_code(p_application_code);
    begin
        select max(workflow_enabled_flag) into l_flag from xxfnd_workflow_processes
         where application_code = l_app and process_code = upper(p_process_code);
        return nvl(l_flag, 'Y');
    end workflow_enabled;

    function email_enabled(p_process_code in varchar2 default null, p_application_code in varchar2 default null) return varchar2 is
        l_app  xxfnd_applications.application_code%type := app_code(p_application_code);
        l_inst varchar2(1);
        l_appf varchar2(1);
        l_proc varchar2(1);
    begin
        select max(email_enabled_flag) into l_inst from xxfnd_applications where application_code = 'COMMON';
        select max(email_enabled_flag) into l_appf from xxfnd_applications where application_code = l_app;
        if p_process_code is not null then
            select max(email_enabled_flag) into l_proc from xxfnd_workflow_processes
             where application_code = l_app and process_code = upper(p_process_code);
        end if;
        return case when nvl(l_inst, 'Y') = 'Y' and nvl(l_appf, 'Y') = 'Y' and nvl(l_proc, 'Y') = 'Y' then 'Y' else 'N' end;
    end email_enabled;

    function process_of_task(p_task_id in number) return varchar2 is
        l_code varchar2(255);
    begin
        select max(w.workflow_def_static_id) into l_code
          from apex_tasks t
          join apex_workflows w on w.workflow_id = t.workflow_id
         where t.task_id = p_task_id;
        return upper(l_code);
    end process_of_task;

    procedure sync_processes is
    begin
        merge into xxfnd_workflow_processes d
        using (select a.application_code, upper(w.static_id) process_code, max(w.name) process_name
                 from apex_appl_workflows w
                 join xxfnd_applications a on a.apex_application_id = w.application_id
                group by a.application_code, upper(w.static_id)) s
           on (d.application_code = s.application_code and d.process_code = s.process_code)
         when matched then update set d.process_name = s.process_name
                            where decode(d.process_name, s.process_name, 0, 1) = 1
         when not matched then insert (application_code, process_code, process_name)
                               values (s.application_code, s.process_code, s.process_name);
    end sync_processes;

end xxfnd_workflow_switch_pkg;
/
