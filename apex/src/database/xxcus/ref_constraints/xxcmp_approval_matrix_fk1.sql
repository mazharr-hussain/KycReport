alter table xxcus.xxcmp_approval_matrix
    add constraint xxcmp_approval_matrix_fk1
        foreign key ( level1_role_code )
            references xxcus.xxfnd_roles ( role_code )
        enable;


-- sqlcl_snapshot {"hash":"2eef867734168f3071e5f011a4b12a3365a383a8","type":"REF_CONSTRAINT","name":"XXCMP_APPROVAL_MATRIX_FK1","schemaName":"XXCUS","sxml":""}