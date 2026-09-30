#!/usr/bin/env python3
"""Chunk 4 pages built from the reusable patterns in pagegen.py:
145/146 Deadlines and Escalation, 147 Process Catalogue (Workflow Setup tabs)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pagegen import col, item, list_page, form_page

PAGES = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'src', 'pages')


def write(name, text):
    with open(os.path.join(PAGES, name), 'w') as f:
        f.write(text)


# 145 Deadlines and Escalation ------------------------------------------------
write('p00145-deadlines-and-escalation.apx', list_page(
    145, 'Deadlines and Escalation', 'DEADLINES-AND-ESCALATION', 'administration',
    'When each kind of task is due, when its owners get a reminder, and which role receives it once overdue. '
    'The daily Task deadlines automation sends the reminders and escalations.',
    '''select q.*,
       apex_page.get_url(p_page => 146, p_items => 'P146_TASK_DEFINITION', p_values => q.task_definition, p_clear_cache => '146') as open_url
  from (
        select s.task_definition,
               nvl(t.name, s.task_definition) as task_name,
               s.due_days,
               s.reminder_days_before,
               r.role_name as escalation_role,
               s.notify_on_create_flag,
               s.description
          from xxfnd_task_settings s
          left join apex_appl_taskdefs t on t.static_id = s.task_definition and t.application_id = :APP_ID
          left join xxfnd_roles r on r.role_code = s.escalation_role_code
       ) q''',
    [col('TASK_DEFINITION', 'Task Definition', 10, kind='hidden', pk=True),
     col('TASK_NAME', 'Task', 20, link='OPEN_URL'),
     col('DUE_DAYS', 'Due (days)', 30, dtype='NUMBER'),
     col('REMINDER_DAYS_BEFORE', 'Reminder (days before)', 40, dtype='NUMBER'),
     col('ESCALATION_ROLE', 'Escalate To', 50),
     col('NOTIFY_ON_CREATE_FLAG', 'E-mail on Creation', 60),
     col('DESCRIPTION', 'Description', 70),
     col('OPEN_URL', 'Open Url', 80, kind='hidden')],
    create_label='Add Task Deadline', form_page=146))

write('p00146-task-deadline.apx', form_page(
    146, 'Task Deadline', 'TASK-DEADLINE', 'administration',
    'Due date, reminder and escalation for one kind of task. Applies to tasks created from now on.',
    'XXFND_TASK_SETTINGS', 'TASK_DEFINITION',
    [item(146, 'TASK_DEFINITION', 'selectList', 'Task', 10, 'TASK_DEFINITION', required=True, pk=True,
          lov=('shared', 'lov-task-definitions', '- Select -'),
          read_only_sql="select 1 from xxfnd_task_settings where task_definition = :P146_TASK_DEFINITION",
          help_text='The APEX task definition.'),
     item(146, 'DUE_DAYS', 'numberField', 'Due (days)', 20, 'DUE_DAYS', dtype='number',
          help_text='Days from creation until the task is due. Empty = no due date.'),
     item(146, 'REMINDER_DAYS_BEFORE', 'numberField', 'Reminder (days before due)', 30, 'REMINDER_DAYS_BEFORE',
          dtype='number', help_text='Days before the due date when the owners are reminded. Empty = no reminder.'),
     item(146, 'ESCALATION_ROLE_CODE', 'selectList', 'Escalate To', 40, 'ESCALATION_ROLE_CODE',
          lov=('shared', 'lov-roles', '- No escalation -'),
          help_text='Role whose members are told when the task is overdue.'),
     item(146, 'NOTIFY_ON_CREATE_FLAG', 'switch', 'E-mail on Creation', 50, 'NOTIFY_ON_CREATE_FLAG', default='Y',
          help_text='E-mail the potential owners when a task is created.'),
     item(146, 'DESCRIPTION', 'textarea', 'Description', 60, 'DESCRIPTION', max_len=1000, height=3)],
    delete=True))

# 147 Process Catalogue (read-only) -------------------------------------------
write('p00147-process-catalogue.apx', list_page(
    147, 'Process Catalogue', 'PROCESS-CATALOGUE', 'administration',
    'The workflows and task definitions of this application. Their shape is maintained by developers '
    '(App Builder) and deployed as a release; their parameters are maintained on the other Workflow Setup tabs.',
    '''select 'Workflow' as component_type,
       w.name,
       w.static_id,
       w.title as description,
       cast(null as varchar2(30)) as task_type,
       w.last_updated_on
  from apex_appl_workflows w
 where w.application_id = :APP_ID
union all
select 'Task Definition',
       t.name,
       t.static_id,
       t.subject,
       t.task_type,
       t.last_updated_on
  from apex_appl_taskdefs t
 where t.application_id = :APP_ID''',
    [col('COMPONENT_TYPE', 'Type', 10),
     col('NAME', 'Name', 20),
     col('STATIC_ID', 'Static ID', 30),
     col('DESCRIPTION', 'Title / Subject', 40),
     col('TASK_TYPE', 'Task Type', 50),
     col('LAST_UPDATED_ON', 'Last Changed', 60, dtype='DATE', fmt='SINCE')]))
print('chunk 4 pages written')
