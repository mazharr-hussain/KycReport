comment on table xxcus.xxcmp_party_relationships is
    'Ownership and control stack. SUBJECT holds the relationship over OBJECT (subject is shareholder of object). Multi-level cycles are rejected by trigger.'
    ;

comment on column xxcus.xxcmp_party_relationships.latest_ubo_status is
    'Display copy of the latest UBO determination. The authoritative record is the UBO register (Module 2).';


-- sqlcl_snapshot {"hash":"d63456540ecf97f2042c720c9a60931c558c9631","type":"COMMENT","name":"xxcmp_party_relationships","schemaName":"xxcus","sxml":""}