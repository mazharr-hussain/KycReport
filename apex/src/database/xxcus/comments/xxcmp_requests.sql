comment on table xxcus.xxcmp_requests is
    'KYC request from a requesting department, or a periodic / event-triggered review. Counterparty details are captured on the request; on evaluation the request is linked to an existing party or a new one.'
    ;

comment on column xxcus.xxcmp_requests.match_ack_flag is
    'Y: the requester saw possible existing parties and declared none of them is the counterparty.';

comment on column xxcus.xxcmp_requests.match_status is
    'SELECTED (existing party chosen), NEW (no possible match: new party created), PENDING (possible matches: Compliance decides), MERGED (Compliance linked it to an existing party), CONFIRMED_NEW (Compliance confirmed a new party).'
    ;

comment on column xxcus.xxcmp_requests.party_selection is
    'EXISTING: the requester chose a party from the party list; NEW: a counterparty not yet known.';


-- sqlcl_snapshot {"hash":"fa2a59fb2c060a6b5f227cc13ea97f75537b005e","type":"COMMENT","name":"xxcmp_requests","schemaName":"xxcus","sxml":""}