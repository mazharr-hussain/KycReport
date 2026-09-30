--------------------------------------------------------------------------------
-- 16d Parties (party feature: pages 20-23)
--   Party-level contact details (email, phone, website, fax) on XXCMP_PARTIES.
--   Contact persons on XXCMP_PARTY_CONTACTS (name, job title, email, phone).
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
end;
/
comment on column xxcmp_parties.email is 'Main email of the party (contact persons are in XXCMP_PARTY_CONTACTS).';
comment on column xxcmp_parties.merged_into_party_id is 'Set when Compliance merged this duplicate into another party; the party is then disabled.';
comment on column xxcmp_party_contacts.contact_type is 'PERSON for a contact person (name, job title, email, phone); EMAIL/PHONE/... rows are from before release 18.';

-- contact type for contact persons
merge into xxfnd_lookup_values t
using (select 'CONTACT_TYPE' lookup_type, 'PERSON' lookup_code from dual) s
   on (t.lookup_type = s.lookup_type and t.lookup_code = s.lookup_code)
 when not matched then insert (lookup_type, lookup_code, meaning, display_sequence)
                       values ('CONTACT_TYPE', 'PERSON', 'Contact Person', 5);

-- one-off: the main email / phone / website of a party from its older contact rows (only where still empty)
update xxcmp_parties p
   set email = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                  from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'EMAIL' and c.enabled_flag = 'Y')
 where p.email is null
   and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'EMAIL' and c.enabled_flag = 'Y');
update xxcmp_parties p
   set phone = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                  from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type in ('PHONE', 'MOBILE') and c.enabled_flag = 'Y')
 where p.phone is null
   and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type in ('PHONE', 'MOBILE') and c.enabled_flag = 'Y');
update xxcmp_parties p
   set website = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                    from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'WEBSITE' and c.enabled_flag = 'Y')
 where p.website is null
   and exists (select 1 from xxcmp_party_contacts c where c.party_id = p.party_id and c.contact_type = 'WEBSITE' and c.enabled_flag = 'Y');
commit;
