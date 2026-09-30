alter table xxcus.xxcmp_rfis
    add constraint xxcmp_rfis_fk3
        foreign key ( recipient_party_contact_id )
            references xxcus.xxcmp_party_contacts ( party_contact_id )
        enable;


-- sqlcl_snapshot {"hash":"14e987bfc3dc71f43d14138b075be505e51cdf02","type":"REF_CONSTRAINT","name":"XXCMP_RFIS_FK3","schemaName":"XXCUS","sxml":""}