comment on table xxcus.xxfnd_storage_config is
    'Where files are stored: Oracle UCM (WebCenter Content) or SharePoint. The most specific row wins (entity + category, then entity, then category, then the default row with both null); PRIORITY breaks ties.'
    ;

comment on column xxcus.xxfnd_storage_config.folder_path_template is
    'Folder for new files. Tokens: #ENTITY_NAME#, #PK1_VALUE#..#PK5_VALUE#, #CATEGORY_CODE#, #YYYY#.';


-- sqlcl_snapshot {"hash":"84b48f2f70dfc32687a64c8f32bfbc9084dabaf7","type":"COMMENT","name":"xxfnd_storage_config","schemaName":"xxcus","sxml":""}