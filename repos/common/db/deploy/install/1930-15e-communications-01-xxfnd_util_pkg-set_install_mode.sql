--------------------------------------------------------------------------------
-- 15e Communications (release 74, R27). COMMON only (XXFUSION); every application uses it.
--   XXFND_COMMUNICATIONS: every e-mail with an outside person that belongs to a record (a case, a request for
--   information ...): sent from the application, or a reply received and recorded. Sent now through APEX mail;
--   received e-mails are typed (or pasted) by a person now. The Outlook provision: an Outlook (Microsoft Graph)
--   integration later fills the same table through RECORD_RECEIVED (SOURCE OUTLOOK) and matches replies by
--   CONVERSATION_ID / EXTERNAL_MESSAGE_ID; nothing else changes. Server OUTLOOK_GRAPH (release 86; disabled) and
--   purpose EMAIL_SYNC (manual) are registered for it.
--   Attachments: entity XXFND_COMMUNICATIONS (common attachments), registered by each application that uses it.
-- Release 82: the table is created in 15 and the package is XXFND_NOTIFY_PKG (15); this script keeps the seeds.
-- Idempotent (CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------


-- the Outlook provision (inactive until the integration is built), lookups and data security: COMMON administrators
-- see every row; each application adds its own rule (e.g. KYC's Compliance team)
declare
    procedure lv(p_type in varchar2, p_code in varchar2, p_meaning in varchar2, p_seq in number) is
    begin
        merge into xxfnd_lookup_values t using (select p_type lookup_type, p_code lookup_code from dual) s
           on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
         when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                               values (p_type, p_code, p_meaning, p_seq);
    end lv;
begin
    xxfnd_util_pkg.set_install_mode(true);
    merge into xxfnd_lookup_types t using (select 'COMMUNICATION_STATUS' lookup_type from dual) s
       on (t.lookup_type = s.lookup_type)
     when not matched then insert (lookup_type, meaning) values ('COMMUNICATION_STATUS', 'Communication Statuses');
    lv('COMMUNICATION_STATUS', 'SENT', 'Sent', 10);
    lv('COMMUNICATION_STATUS', 'NOT_SENT', 'Recorded, not sent (e-mail switched off)', 20);
    lv('COMMUNICATION_STATUS', 'FAILED', 'Failed', 30);
    lv('COMMUNICATION_STATUS', 'RECEIVED', 'Received', 40);
    -- release 86: the Outlook server is a workspace server (XXFND_SERVERS; was the endpoint OUTLOOK_GRAPH)
    merge into xxfnd_servers t using (select 'OUTLOOK_GRAPH' server_code from dual) s
       on (t.server_code = s.server_code)
     when not matched then insert (server_code, server_name, server_type, base_url, credential_static_id, enabled_flag,
                                   description)
                           values ('OUTLOOK_GRAPH', 'Outlook (Microsoft Graph)', 'OUTLOOK', 'https://graph.microsoft.com/v1.0',
                                   'XXFND_GRAPH_CRED', 'N',
                                   'Planned: sends and receives the e-mails of the RFI and Notes screens '
                                   || '(XXFND_COMMUNICATIONS). Not built yet: e-mails are sent by APEX mail and replies recorded by hand.');
    merge into xxfnd_integration_purposes t using (select 'EMAIL_SYNC' purpose_code from dual) s
       on (t.purpose_code = s.purpose_code)
     when not matched then insert (purpose_code, application_code, purpose_name, capture_method, approval_status)
                           values ('EMAIL_SYNC', null, 'E-mail with outside parties (Outlook)', 'MANUAL', 'APPROVED');
    -- data security: the Common administrators' rule is seeded by XXFND_SHARE_PKG.SEED_COMMON (19c, run by 20, after the role); applications add theirs
    commit;
    xxfnd_util_pkg.set_install_mode(false);
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
