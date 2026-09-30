alter table xxcus.xxcmp_screenings
    add constraint xxcmp_screenings_fk2
        foreign key ( party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"2a4f62834177390e171d418fdf2bd4235108fe83","type":"REF_CONSTRAINT","name":"XXCMP_SCREENINGS_FK2","schemaName":"XXCUS","sxml":""}