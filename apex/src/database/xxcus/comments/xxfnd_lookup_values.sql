comment on table xxcus.xxfnd_lookup_values is
    'Lookup values (FND_LOOKUP_VALUES). Parent columns support dependent (cascading) values.';

comment on column xxcus.xxfnd_lookup_values.tag is
    'One extra attribute for a value, e.g. a jurisdiction''s UBO threshold. Needs more than one? Use a dedicated table.';


-- sqlcl_snapshot {"hash":"edfc98a5e94ffbe79808abe720429c74d6d3d52d","type":"COMMENT","name":"xxfnd_lookup_values","schemaName":"xxcus","sxml":""}