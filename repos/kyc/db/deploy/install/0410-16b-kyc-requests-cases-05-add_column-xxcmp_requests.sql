
-- Counterparty selection (an existing party chosen by the requester, or a new one created with the request).
-- The counterparty columns are shared by organisations and individuals (16f): JURISDICTION = country /
-- nationality, REGISTRATION_NUMBER = registration / ID number, ENTITY_TYPE = entity / ID type,
-- INCORPORATION_DATE = incorporation / birth date.
begin
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'PARTY_SELECTION',     q'[varchar2(10) default 'NEW']');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'INCORPORATION_DATE',  'date');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_ACK_FLAG',      q'[varchar2(1) default 'N']');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_STATUS',        'varchar2(20)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_RESOLVED_BY',   'varchar2(255)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_RESOLVED_DATE', 'timestamp');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'MATCH_NOTE',          'varchar2(1000)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CONTACT_NAME',        'varchar2(240)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CONTACT_EMAIL',       'varchar2(320)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'CONTACT_PHONE',       'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'LAST_ACTION_DATE',    'date');
    -- release 26: the type of the counterparty's number, and what the counterparty is to the company
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'REGISTRATION_TYPE',   'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXCMP_REQUESTS', 'BUSINESS_RELATIONSHIP', 'varchar2(30)');
end;
/
comment on column xxcmp_requests.party_selection is 'EXISTING: the requester chose a party from the party list; NEW: a counterparty created with the request (party status Pending until the request is approved).';
comment on column xxcmp_requests.match_status is 'SELECTED (existing party chosen), NEW (party created with the request), MERGED (Compliance merged it into an existing party). Older values: PENDING, CONFIRMED_NEW.';
create index if not exists xxcmp_parties_n4 on xxcmp_parties (upper(replace(registration_number, ' ')));
create index if not exists xxcmp_requests_n2 on xxcmp_requests (party_id);
comment on table xxcmp_requests is 'KYC request from a requesting department, or a periodic / event-triggered review. A new counterparty is created as a party (Pending) with the request.';
