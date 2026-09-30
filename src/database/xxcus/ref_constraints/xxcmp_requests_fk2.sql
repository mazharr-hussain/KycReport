alter table xxcus.xxcmp_requests
    add constraint xxcmp_requests_fk2
        foreign key ( parent_request_id )
            references xxcus.xxcmp_requests ( request_id )
        enable;


-- sqlcl_snapshot {"hash":"28b0b1cbc39494f4ada66550037e37c9c97a91db","type":"REF_CONSTRAINT","name":"XXCMP_REQUESTS_FK2","schemaName":"XXCUS","sxml":""}