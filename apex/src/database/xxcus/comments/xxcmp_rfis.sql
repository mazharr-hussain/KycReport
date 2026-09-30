comment on table xxcus.xxcmp_rfis is
    'Requests for Information raised at document checklist review, investigation or approval return. Attaches generically so it does not depend on Module 1 or 2 tables.'
    ;

comment on column xxcus.xxcmp_rfis.response_task_id is
    'APEX action task RFI_RESPONSE for an internal recipient.';

comment on column xxcus.xxcmp_rfis.response_token_hash is
    'SHA-256 hash of the one-time token emailed to an external party. The token itself is never stored.';

comment on column xxcus.xxcmp_rfis.review_task_id is
    'APEX action task RFI_REVIEW for the Compliance team once a response arrives.';


-- sqlcl_snapshot {"hash":"2de316b6f49e8d6126f748a1a1daf72b92cbd001","type":"COMMENT","name":"xxcmp_rfis","schemaName":"xxcus","sxml":""}