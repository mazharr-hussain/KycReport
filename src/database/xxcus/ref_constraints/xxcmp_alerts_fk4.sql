alter table xxcus.xxcmp_alerts
    add constraint xxcmp_alerts_fk4
        foreign key ( review_request_id )
            references xxcus.xxcmp_requests ( request_id )
        enable;


-- sqlcl_snapshot {"hash":"e1f64a73fc9fbd367dd6cbdf1fc841819e0acae5","type":"REF_CONSTRAINT","name":"XXCMP_ALERTS_FK4","schemaName":"XXCUS","sxml":""}