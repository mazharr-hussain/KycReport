alter table xxcus.xxcmp_party_contacts
    add constraint xxcmp_party_contacts_fk1
        foreign key ( party_id )
            references xxcus.xxcmp_parties ( party_id )
        enable;


-- sqlcl_snapshot {"hash":"6e41841ec72b6827bfb1c873bfd7a49bf6728c25","type":"REF_CONSTRAINT","name":"XXCMP_PARTY_CONTACTS_FK1","schemaName":"XXCUS","sxml":""}