alter table xxcus.xxcmp_case_notes
    add constraint xxcmp_case_notes_fk2
        foreign key ( related_party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"4e2e5504b876591cac5146af578ccca1ac357952","type":"REF_CONSTRAINT","name":"XXCMP_CASE_NOTES_FK2","schemaName":"XXCUS","sxml":""}