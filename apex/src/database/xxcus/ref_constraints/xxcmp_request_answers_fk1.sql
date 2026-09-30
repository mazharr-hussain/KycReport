alter table xxcus.xxcmp_request_answers
    add constraint xxcmp_request_answers_fk1
        foreign key ( request_id )
            references xxcus.xxcmp_requests ( request_id )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"90454a46cf02534ed6ac95f640b44518e2df84f8","type":"REF_CONSTRAINT","name":"XXCMP_REQUEST_ANSWERS_FK1","schemaName":"XXCUS","sxml":""}