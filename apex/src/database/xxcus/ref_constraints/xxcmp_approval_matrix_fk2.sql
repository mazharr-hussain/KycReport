alter table xxcus.xxcmp_approval_matrix
    add constraint xxcmp_approval_matrix_fk2
        foreign key ( level2_role_code )
            references xxcus.xxfnd_roles ( role_code )
        enable;


-- sqlcl_snapshot {"hash":"826353f2ce8d8122e5a9ff27c6b1565f72f25796","type":"REF_CONSTRAINT","name":"XXCMP_APPROVAL_MATRIX_FK2","schemaName":"XXCUS","sxml":""}