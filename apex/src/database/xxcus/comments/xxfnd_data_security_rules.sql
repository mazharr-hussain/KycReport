comment on table xxcus.xxfnd_data_security_rules is
    'Row access per role and table. A user sees the union of the rows allowed by the enabled rules of their active roles; no rule = no rows (enforced by XXFND_VPD_PKG).'
    ;

comment on column xxcus.xxfnd_data_security_rules.value_list is
    'COLUMN_IN_LIST: comma-separated values, e.g. AE,SA.';


-- sqlcl_snapshot {"hash":"fee8969b2b1fb8763f4e8b50c1bae5aee3e1280e","type":"COMMENT","name":"xxfnd_data_security_rules","schemaName":"xxcus","sxml":""}