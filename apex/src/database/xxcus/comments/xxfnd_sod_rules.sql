comment on table xxcus.xxfnd_sod_rules is
    'Role pairs that one person may not both exercise within CONFLICT_SCOPE. Stored in canonical order so a pair cannot be entered twice.'
    ;

comment on column xxcus.xxfnd_sod_rules.conflict_scope is
    'Lookup SOD_SCOPE, e.g. SAME_RECORD (same case) or GLOBAL (never both roles).';


-- sqlcl_snapshot {"hash":"ea2384a08af538ebad9b6d175402b3874248ceb6","type":"COMMENT","name":"xxfnd_sod_rules","schemaName":"xxcus","sxml":""}