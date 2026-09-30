comment on table xxcus.xxcmp_questionnaires is
    'Requester intake questionnaires (scored, drive routing) and the Officer investigation questionnaire (unscored, informs a manual classification).'
    ;

comment on column xxcus.xxcmp_questionnaires.current_version_number is
    'Raised when an approved scoring change goes live. Responses snapshot the version they were scored against.';


-- sqlcl_snapshot {"hash":"bba15e1fa73bcb8d1c2faa8e15626739974a2058","type":"COMMENT","name":"xxcmp_questionnaires","schemaName":"xxcus","sxml":""}