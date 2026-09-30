alter table xxcus.xxcmp_request_answers
    add constraint xxcmp_request_answers_fk4
        foreign key ( answer_option_id )
            references xxcus.xxcmp_answer_options ( answer_option_id )
        enable;


-- sqlcl_snapshot {"hash":"a866e3e70268bd13db67a2808fb5b35b6138734a","type":"REF_CONSTRAINT","name":"XXCMP_REQUEST_ANSWERS_FK4","schemaName":"XXCUS","sxml":""}