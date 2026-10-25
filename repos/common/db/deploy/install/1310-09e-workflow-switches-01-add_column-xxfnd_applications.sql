--------------------------------------------------------------------------------
-- 09e Workflow and e-mail switches (release 73). COMMON only (XXFUSION). Early, so the shared packages that
--   follow (15 notifications) can ask it.
--   - XXFND_WORKFLOW_PROCESSES: one row per workflow process (APEX workflow static ID) of each registered
--     application. WORKFLOW_ENABLED_FLAG N = the approval is skipped and the record is auto-approved
--     ("Auto-approved (workflow disabled)"); EMAIL_ENABLED_FLAG N = no e-mails for the process.
--   - XXFND_APPLICATIONS.EMAIL_ENABLED_FLAG: e-mail on / off for an application; the COMMON row is the instance.
--   An e-mail is sent only when the instance, the application and the process all have e-mail on. Tasks and
--   in-application notifications do not depend on the e-mail switches.
--   Release 82: the switch routines are in XXFND_WORKFLOW_PKG (15).
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_APPLICATIONS', 'EMAIL_ENABLED_FLAG', q'~varchar2(1) default 'Y' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APPLICATIONS', 'XXFND_APPLICATIONS_CK_EMAIL', q'~check (email_enabled_flag in ('Y','N'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_applications.email_enabled_flag is 'E-mail on / off for the application (the COMMON row: for the whole instance).'~');
end;
/
