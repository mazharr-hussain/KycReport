comment on table xxcus.xxcmp_answer_options is
    'Answers with risk weight, critical-escalation and waiver flags. Only APPROVED rows are used for scoring; a scoring change needs a second person''s approval.'
    ;

comment on column xxcus.xxcmp_answer_options.risk_points is
    'Copied onto each response answer at submission, so later changes never rewrite a past case''s score.';


-- sqlcl_snapshot {"hash":"c483837af6b2aa9b2c3edb0409d29ddd86ad591b","type":"COMMENT","name":"xxcmp_answer_options","schemaName":"xxcus","sxml":""}