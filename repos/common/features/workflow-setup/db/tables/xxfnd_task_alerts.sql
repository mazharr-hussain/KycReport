
create table if not exists xxfnd_task_alerts (
    task_id                number         not null,
    alert_type             varchar2(30)   not null,
    sent_date              timestamp      default systimestamp not null,
    constraint xxfnd_task_alerts_pk primary key (task_id, alert_type),
    constraint xxfnd_task_alerts_ck1 check (alert_type in ('REMINDER','ESCALATION'))
);
comment on table xxfnd_task_alerts is 'Deadline reminders and escalations already sent, so each goes out once per task.';
