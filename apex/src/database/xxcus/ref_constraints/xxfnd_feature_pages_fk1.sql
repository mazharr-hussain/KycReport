alter table xxcus.xxfnd_feature_pages
    add constraint xxfnd_feature_pages_fk1
        foreign key ( feature_code )
            references xxcus.xxfnd_features ( feature_code )
        enable;


-- sqlcl_snapshot {"hash":"f42f06f7c7f208f67f56d00136b68d5aaae5a9ce","type":"REF_CONSTRAINT","name":"XXFND_FEATURE_PAGES_FK1","schemaName":"XXCUS","sxml":""}