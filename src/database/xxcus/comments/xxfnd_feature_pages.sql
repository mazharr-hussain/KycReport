comment on table xxcus.xxfnd_feature_pages is
    'Which feature an APEX page belongs to. Page authorization checks the privilege of this feature.';

comment on column xxcus.xxfnd_feature_pages.tab_label is
    'Tab shown on every list page of the same feature; null = not a tab (forms, dialogs).';


-- sqlcl_snapshot {"hash":"43cfa5443a1872856b1ad684a4c34b73b9f6ccdd","type":"COMMENT","name":"xxfnd_feature_pages","schemaName":"xxcus","sxml":""}