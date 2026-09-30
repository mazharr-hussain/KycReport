alter table xxcus.xxcmp_case_notes
    add constraint xxcmp_case_notes_fk1
        foreign key ( case_id )
            references xxcus.xxcmp_cases ( case_id )
        enable;


-- sqlcl_snapshot {"hash":"76ab485d910e22a64f7ad3b745aedff39b02dc08","type":"REF_CONSTRAINT","name":"XXCMP_CASE_NOTES_FK1","schemaName":"XXCUS","sxml":""}