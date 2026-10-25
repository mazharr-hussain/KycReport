--------------------------------------------------------------------------------
-- 16b KYC requests and cases  (release R13)
-- Module 1 (intake) and Module 2 (investigation, decision) data and logic.
--   XXCMP_REQUESTS            a KYC request (new onboarding, periodic or event-triggered review)
--   XXCMP_REQUEST_ANSWERS     questionnaire answers (requester at intake, officer in the case)
--   XXCMP_CASES               the compliance case opened from a request
--   XXCMP_CASE_DECISIONS      approval history per level
--   XXCMP_SCREENINGS          registry / sanctions / PEP / adverse-media checks
--   XXCMP_DOC_VERIFICATIONS   genuine-and-current check per attached document
--   XXCMP_UBO_DETERMINATIONS  the officer's beneficial-owner decisions
--   XXCMP_CASE_NOTES          investigation notes
--   XXCMP_REQUEST_PKG / XXCMP_CASE_PKG  specifications only (release 74): the bodies are the request component
--                             (16r) and the case component (16s); specs here so both compile in any order
--                             (release 90: the request approval of XXCMP_APPROVAL_PKG is in XXCMP_REQUEST_PKG)
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
-- release 48 (from 15): the requests for information follow APEX approval tasks (no item of the former engine)
declare
    l_count pls_integer;
begin
    select count(*) into l_count from user_constraints where constraint_name = 'XXCMP_RFIS_FK2';
    if l_count > 0 then
        execute immediate 'alter table xxcmp_rfis drop constraint xxcmp_rfis_fk2';
    end if;
    xxfnd_ddl_pkg.add_column('XXCMP_RFIS', 'RESPONSE_TASK_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXCMP_RFIS', 'REVIEW_TASK_ID', 'number');
    select count(*) into l_count from user_tab_columns where table_name = 'XXCMP_RFIS' and column_name = 'WF_ITEM_ID';
    if l_count > 0 then
        execute immediate 'alter table xxcmp_rfis drop column wf_item_id';
    end if;
    execute immediate 'drop table if exists xxcmp_wf_activity_controls cascade constraints purge';
end;
/
