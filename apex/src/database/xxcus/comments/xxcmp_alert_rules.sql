comment on table xxcus.xxcmp_alert_rules is
    'Monitoring rules: what raises an alert, how many days ahead (or of grace), for which risk tier, who is notified and whether an early review starts automatically.'
    ;

comment on column xxcus.xxcmp_alert_rules.days_before is
    'REVIEW_DUE / DOCUMENT_EXPIRY: days ahead; REVIEW_OVERDUE / SLA_BREACH: days of grace; ADVERSE_SCREENING: not used.';

comment on column xxcus.xxcmp_alert_rules.start_review_flag is
    'Y: the daily run also starts an event-triggered review (DOCUMENT_EXPIRY once expired, ADVERSE_SCREENING).';


-- sqlcl_snapshot {"hash":"6311e56787556f419ca195a50c035db67c6705d7","type":"COMMENT","name":"xxcmp_alert_rules","schemaName":"xxcus","sxml":""}