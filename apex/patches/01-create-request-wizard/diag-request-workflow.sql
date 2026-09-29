-- Why is a KYC request still "Processing"? Run in SQLcl / SQL Developer as the parsing schema.
-- Replace REQ-000001 with the request number.
set lines 200 pages 100
set verify off
define req = 'REQ-000001'

prompt 1. The request
select request_id, request_status, intake_outcome, intake_score, party_id, workflow_id, submitted_date
  from xxcmp_requests where request_number = '&req';

prompt 2. Its workflow (expect state Completed or Active; Faulted = an activity failed)
select w.workflow_id, w.state, w.workflow_version, w.workflow_version_state, w.is_dev_mode, w.start_time
  from apex_workflows w
 where w.workflow_def_static_id = 'KYC_REQUEST'
   and w.detail_pk = (select to_char(request_id) from xxcmp_requests where request_number = '&req');

prompt 3. Its activities (the one in state Faulted shows the error)
select a.name, a.state, a.start_time, a.end_time, a.retry_count, substr(a.error_message, 1, 300) error_message
  from apex_workflow_activities a
 where a.workflow_id = (select workflow_id from xxcmp_requests where request_number = '&req')
 order by a.start_time;

prompt 4. Tasks created for it (expect DOC_CHECKLIST_REVIEW for Compliance when KYC is required)
select task_id, task_def_static_id, state, subject, created_on
  from apex_tasks
 where detail_pk = (select to_char(request_id) from xxcmp_requests where request_number = '&req')
   and task_def_static_id = 'DOC_CHECKLIST_REVIEW';

prompt 5. Workflow version state in the application (expect Active, not Development)
select workflow_static_id, workflow_version, state
  from apex_appl_workflow_versions
 where application_id = (select application_id from apex_applications where upper(alias) = 'KYC');

prompt 6. Background processing: needs job_queue_processes > 0 (ask your DBA if this errors)
select value job_queue_processes from v$parameter where name = 'job_queue_processes';
