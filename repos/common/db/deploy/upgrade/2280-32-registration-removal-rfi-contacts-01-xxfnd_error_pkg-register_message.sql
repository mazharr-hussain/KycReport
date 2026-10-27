--------------------------------------------------------------------------------
-- 32 Removing registrations, RFI documents and deadlines, contacts of a record (release 88). COMMON only (XXFUSION),
--   after 31 and before 99.
--   C8 / C9: every REGISTER_* routine has its UNREGISTER_* routine in the same package (the application's own rows
--     only, through XXFND_APPLICATION_PKG.REMOVE_REGISTERED), and DELETE_APPLICATION removes the setup an application
--     registered (each component's UNREGISTER_APPLICATION) - only business data still blocks it.
--   C5: the Information Request page 143 keeps the documents of the RFI (attachment page COMMON_RFI, entity
--     XXFND_RFIS); its tasks get a due date (the RFI's own, else the task setting) and their task settings.
--   C6: the contacts of a record (XXFND_NOTIFY_PKG.REGISTER_CONTACT_SOURCE) are offered as recipients on page 46.
--   C10: REGISTER_RULE (several approval rules per type); the applications are granted SELECT / EXECUTE only.
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_error_pkg.register_message('XXFND_REG_IN_USE',
        '{1} {2} is still used by the application''s data and cannot be removed.', -20196);
    xxfnd_error_pkg.register_message('XXFND_CONTACT_SOURCE_VIEW',
        'View {1} of schema {2} needs the columns PK1_VALUE, CONTACT_NAME and EMAIL_ADDRESS, and SELECT on it granted to COMMON.', -20197);
    commit;
end;
/

-- C5: the documents of an RFI on page 143 (region "documents"; add and replace, no remove) and the RFI task settings
-- (no due days: the RFI's own due date applies to the answer; IT sets the rest in Task Settings), added when missing
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_attach_pkg.register_attachment_page(p_application_code    => 'COMMON',
                                              p_function_code       => 'COMMON_RFI',
                                              p_function_name       => 'Information Request - documents of the RFI',
                                              p_page_id             => 143,
                                              p_block_code          => 'DOCUMENTS',
                                              p_region_static_id    => 'documents',
                                              p_entity_name         => 'XXFND_RFIS',
                                              p_pk1_page_item       => 'RFI_ID',
                                              p_block_name          => 'Documents',
                                              p_insert_allowed_flag => 'Y',
                                              p_update_allowed_flag => 'Y',
                                              p_delete_allowed_flag => 'N');
    xxfnd_workflow_pkg.register_task_setting(p_application_code     => 'COMMON',
                                             p_task_definition      => 'RFI_RESPONSE',
                                             p_reminder_days_before => 1,
                                             p_description          => 'Provide the requested information: due on the RFI''s due date.');
    xxfnd_workflow_pkg.register_task_setting(p_application_code     => 'COMMON',
                                             p_task_definition      => 'RFI_REVIEW',
                                             p_description          => 'Review the information received.');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
