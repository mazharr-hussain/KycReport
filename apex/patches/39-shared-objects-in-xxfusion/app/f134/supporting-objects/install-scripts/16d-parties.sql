--------------------------------------------------------------------------------
-- 16d Parties (party feature: pages 20-23)
--   Party-level contact details (email, phone, website, fax) on XXCMP_PARTIES.
--   Contact persons on XXCMP_PARTY_CONTACTS (name, job title, email, phone).
--   Party status (Pending from a request, Approved, Rejected, Cancelled) and the next KYC date.
--   (The one-off moves of older data and the dropped columns are in 16f.)
--   (XXCMP_PARTY_PKG is in 16e: it uses the request and case tables created in 16b.)
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'EMAIL',                'varchar2(320)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'PHONE',                'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'WEBSITE',              'varchar2(500)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'FAX',                  'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'MERGED_INTO_PARTY_ID', 'number');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'MERGE_NOTE',           'varchar2(1000)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_CONTACTS', 'JOB_TITLE',            'varchar2(240)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_CONTACTS', 'EMAIL',                'varchar2(320)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_CONTACTS', 'PHONE',                'varchar2(50)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'PARTY_STATUS',         q'[varchar2(30) default 'APPROVED' not null]');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'NEXT_KYC_DATE',        'date');
    -- release 26: the type of the registration / ID number (organisation: lookup REGISTRATION_TYPE, individual:
    -- lookup ID_DOCUMENT_TYPE); ENTITY_TYPE is the organisation's category only
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'REGISTRATION_TYPE',    'varchar2(30)');
    -- release 40: headquarters address (organisation) / address (individual)
    xxfnd_ddl_pkg.add_column('XXCMP_PARTIES',        'ADDRESS',              'varchar2(1000)');
end;
/
comment on column xxcmp_parties.address is 'Headquarters address of an organisation; address of an individual.';
comment on column xxcmp_parties.email is 'Main email of the party (contact persons are in XXCMP_PARTY_CONTACTS).';
comment on column xxcmp_parties.merged_into_party_id is 'Set when Compliance merged this duplicate into another party; the party is then disabled.';
comment on column xxcmp_parties.party_status is 'PENDING: created from a KYC request, not yet approved; APPROVED; REJECTED / CANCELLED with its request.';
comment on column xxcmp_parties.next_kyc_date is 'When the party''s KYC is due again: set when a KYC case is approved (risk tier review months, PEP cap).';
