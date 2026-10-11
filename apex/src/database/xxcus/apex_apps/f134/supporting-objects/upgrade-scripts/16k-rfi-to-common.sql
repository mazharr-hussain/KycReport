--------------------------------------------------------------------------------
-- 16k KYC requests for information use the common RFI workflow (release 74). KYC only (XXCUS).
--   KYC's RFIs so far (XXCMP_RFIS) are copied once into the common XXFND_RFIS / XXFND_RFI_ROUNDS with the same
--   IDs and numbers, so their open tasks, links and attachments keep working. XXCMP_RFIS itself is not changed: it
--   stays as history. New RFIs are only in the common tables.
-- Idempotent: an RFI already copied is skipped; a re-run copies nothing.
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    xxfnd_vpd_pkg.begin_trusted;
    insert into xxfnd_rfis (rfi_id, rfi_number, application_code, entity_name, pk1_value, recipient_type,
                            recipient_user_name, recipient_name, recipient_email, recipient_reference, rfi_category,
                            description, continue_other_work_flag, rfi_status, round_no, due_date, response_token_hash,
                            token_expiry_date, response_text, responded_date, resolved_date, resolution_notes,
                            response_task_id, review_task_id, created_by, creation_date, last_updated_by,
                            last_update_date)
    select r.rfi_id, r.rfi_number, 'KYC', r.entity_name, r.pk1_value,
           case r.recipient_type when 'EXTERNAL_PARTY' then 'EXTERNAL' else 'USER' end,
           r.recipient_user_name, c.contact_name, c.email, to_char(r.recipient_party_contact_id), r.rfi_category,
           r.description, r.continue_other_work_flag,
           -- an answered RFI waiting for its review
           case when r.rfi_status in ('WAITING_FOR_INFORMATION', 'ON_HOLD_PENDING') and r.responded_date is not null
                then 'RESPONDED' else r.rfi_status end,
           1, r.due_date, r.response_token_hash, r.token_expiry_date, r.response_text, r.responded_date, r.resolved_date,
           r.resolution_notes, r.response_task_id, r.review_task_id, r.created_by, r.creation_date, r.last_updated_by,
           r.last_update_date
      from xxcmp_rfis r
      left join xxcmp_party_contacts c on c.party_contact_id = r.recipient_party_contact_id
     where not exists (select 1 from xxfnd_rfis f where f.rfi_id = r.rfi_id);
    l_n := sql%rowcount;

    insert into xxfnd_rfi_rounds (rfi_id, round_no, question, asked_by, asked_date, response_text, responded_by,
                                  responded_date, review_outcome, review_notes, reviewed_date)
    select r.rfi_id, 1, r.description, r.created_by, r.creation_date, r.response_text,
           case when r.responded_date is not null then nvl(r.recipient_user_name, f.recipient_name) end, r.responded_date,
           case when r.rfi_status in ('RESOLVED', 'REJECTED_RETURNED', 'CANCELLED') then r.rfi_status end,
           r.resolution_notes, r.resolved_date
      from xxcmp_rfis r
      join xxfnd_rfis f on f.rfi_id = r.rfi_id
     where not exists (select 1 from xxfnd_rfi_rounds o where o.rfi_id = r.rfi_id);

    if l_n > 0 then
        xxfnd_rfi_pkg.sync_sequences;
    end if;
    xxfnd_vpd_pkg.end_trusted;
    commit;
exception
    when others then
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
