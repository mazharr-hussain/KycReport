--------------------------------------------------------------------------------
-- 16f Party and request redesign (release 23)
--   One column per organisation / individual pair (the label changes with the party type):
--     JURISDICTION        Country / Nationality        (NATIONALITY dropped)
--     REGISTRATION_NUMBER Registration No. / ID Number (ID_NUMBER dropped)
--     ENTITY_TYPE         Entity Type / ID Type        (ID_TYPE dropped)
--     INCORPORATION_DATE  Incorporation / Birth date   (DATE_OF_BIRTH dropped)
--   on XXCMP_PARTIES and XXCMP_REQUESTS; contact persons without CONTACT_TYPE / CONTACT_VALUE;
--   relationships without OFFICER_CORRECTED_FLAG / LATEST_UBO_STATUS; request statuses
--   Draft, In Progress, Information Needed, Approved, Rejected, Cancelled; party status.
-- Data is moved before a column is dropped. Every step checks the current state first, so the
-- script is safe on install (04/16b still create the older shape) and on every upgrade.
--------------------------------------------------------------------------------
declare
    function has_col(p_table in varchar2, p_column in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*) into l_count from user_tab_columns where table_name = p_table and column_name = p_column;
        return l_count > 0;
    end has_col;

    function has_cons(p_name in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*) into l_count from user_constraints where constraint_name = p_name;
        return l_count > 0;
    end has_cons;

    procedure run(p_sql in varchar2) is
    begin
        execute immediate p_sql;
    end run;

    procedure drop_col(p_table in varchar2, p_column in varchar2) is
    begin
        if has_col(p_table, p_column) then
            run('alter table ' || p_table || ' drop column ' || p_column);
        end if;
    end drop_col;

    procedure drop_cons(p_table in varchar2, p_name in varchar2) is
    begin
        if has_cons(p_name) then
            run('alter table ' || p_table || ' drop constraint ' || p_name);
        end if;
    end drop_cons;

    -- an individual's values move into the organisation column of the pair (where still empty)
    procedure merge_pairs(p_table in varchar2) is
    begin
        if has_col(p_table, 'NATIONALITY') then
            run('update ' || p_table || q'[ set jurisdiction = nvl(nationality, jurisdiction) where party_type = 'PERSON']');
        end if;
        if has_col(p_table, 'ID_NUMBER') then
            run('update ' || p_table || q'[ set registration_number = nvl(registration_number, id_number) where party_type = 'PERSON']');
        end if;
        if has_col(p_table, 'ID_TYPE') then
            run('update ' || p_table || q'[ set entity_type = nvl(entity_type, id_type) where party_type = 'PERSON']');
        end if;
        if has_col(p_table, 'DATE_OF_BIRTH') then
            run('update ' || p_table || q'[ set incorporation_date = nvl(incorporation_date, date_of_birth) where party_type = 'PERSON']');
        end if;
        drop_col(p_table, 'NATIONALITY');
        drop_col(p_table, 'ID_NUMBER');
        drop_col(p_table, 'ID_TYPE');
        drop_col(p_table, 'DATE_OF_BIRTH');
    end merge_pairs;
begin
    ---------------------------------------------------------------- parties
    -- identity document numbers are up to 100 characters (the function-based index is rebuilt around it)
    for c in (select 1 from user_tab_columns
               where table_name = 'XXCMP_PARTIES' and column_name = 'REGISTRATION_NUMBER' and data_length < 100) loop
        for i in (select index_name from user_indexes where index_name = 'XXCMP_PARTIES_N4') loop
            run('drop index xxcmp_parties_n4');
        end loop;
        run('alter table xxcmp_parties modify (registration_number varchar2(100))');
    end loop;
    for i in (select 1 from dual where not exists (select 1 from user_indexes where index_name = 'XXCMP_PARTIES_N4')) loop
        run(q'[create index xxcmp_parties_n4 on xxcmp_parties (upper(replace(registration_number, ' ')))]');
    end loop;
    -- the old rule "organisation fields only for organisations" no longer applies: the columns are shared
    drop_cons('XXCMP_PARTIES', 'XXCMP_PARTIES_CK4');
    merge_pairs('XXCMP_PARTIES');
    if not has_cons('XXCMP_PARTIES_CK5') then
        run(q'[alter table xxcmp_parties add constraint xxcmp_parties_ck5
                   check (party_status in ('PENDING','APPROVED','REJECTED','CANCELLED'))]');
    end if;

    ---------------------------------------------------------------- requests (the counterparty typed on the request)
    merge_pairs('XXCMP_REQUESTS');
    -- statuses: Draft, In Progress, Information Needed, Approved, Rejected, Cancelled
    for c in (select constraint_name from user_constraints
               where constraint_name = 'XXCMP_REQUESTS_CK3' and search_condition_vc like '%SUBMITTED%') loop
        run('alter table xxcmp_requests drop constraint xxcmp_requests_ck3');
    end loop;
    run(q'[update xxcmp_requests set request_status = 'IN_PROGRESS' where request_status = 'SUBMITTED']');
    run(q'[update xxcmp_requests set request_status = 'APPROVED'    where request_status = 'COMPLETED']');
    if not has_cons('XXCMP_REQUESTS_CK3') then
        run(q'[alter table xxcmp_requests add constraint xxcmp_requests_ck3
                   check (request_status in ('DRAFT','IN_PROGRESS','INFO_NEEDED','APPROVED','REJECTED','CANCELLED'))]');
    end if;
    run(q'[update xxcmp_requests set last_action_date = cast(coalesce(completed_date, submitted_date, last_update_date) as date)
            where last_action_date is null]');

    ---------------------------------------------------------------- contact persons
    if has_col('XXCMP_PARTY_CONTACTS', 'CONTACT_TYPE') then
        -- the party's main email / phone / website from its older contact rows (only where still empty)
        run(q'[update xxcmp_parties p
                  set email = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                                 from xxcmp_party_contacts c
                                where c.party_id = p.party_id and c.contact_type = 'EMAIL' and c.enabled_flag = 'Y')
                where p.email is null]');
        run(q'[update xxcmp_parties p
                  set phone = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                                 from xxcmp_party_contacts c
                                where c.party_id = p.party_id and c.contact_type in ('PHONE', 'MOBILE') and c.enabled_flag = 'Y')
                where p.phone is null]');
        run(q'[update xxcmp_parties p
                  set website = (select max(c.contact_value) keep (dense_rank first order by c.primary_flag desc, c.party_contact_id)
                                   from xxcmp_party_contacts c
                                  where c.party_id = p.party_id and c.contact_type = 'WEBSITE' and c.enabled_flag = 'Y')
                where p.website is null]');
        -- every older row becomes a contact person (nothing is lost): its email / phone, and a name
        run(q'[update xxcmp_party_contacts
                  set email = nvl(email, case when contact_type = 'EMAIL' then contact_value end),
                      phone = nvl(phone, case when contact_type in ('PHONE', 'MOBILE') then contact_value end),
                      contact_name = nvl(contact_name, contact_value)
                where contact_type <> 'PERSON']');
        -- one primary contact person per party (before: one per contact type)
        run(q'[update xxcmp_party_contacts c set primary_flag = 'N'
                where primary_flag = 'Y'
                  and party_contact_id <> (select max(k.party_contact_id) keep (dense_rank first
                                                  order by case when k.contact_type = 'PERSON' then 0 else 1 end, k.party_contact_id)
                                             from xxcmp_party_contacts k where k.party_id = c.party_id and k.primary_flag = 'Y')]');
        for i in (select index_name from user_indexes where index_name = 'XXCMP_PARTY_CONTACTS_U1') loop
            run('drop index xxcmp_party_contacts_u1');
        end loop;
        drop_col('XXCMP_PARTY_CONTACTS', 'CONTACT_TYPE');
        drop_col('XXCMP_PARTY_CONTACTS', 'CONTACT_VALUE');
    end if;
    for i in (select 1 from dual where not exists (select 1 from user_indexes where index_name = 'XXCMP_PARTY_CONTACTS_U1')) loop
        run('create unique index xxcmp_party_contacts_u1 on xxcmp_party_contacts (case when primary_flag = ''Y'' then party_id end)');
    end loop;
    run(q'[update xxcmp_party_contacts set contact_name = 'Contact' where contact_name is null]');
    for c in (select 1 from user_tab_columns
               where table_name = 'XXCMP_PARTY_CONTACTS' and column_name = 'CONTACT_NAME' and nullable = 'Y') loop
        run('alter table xxcmp_party_contacts modify (contact_name not null)');
    end loop;

    ---------------------------------------------------------------- owners / officers
    drop_col('XXCMP_PARTY_RELATIONSHIPS', 'OFFICER_CORRECTED_FLAG');
    drop_col('XXCMP_PARTY_RELATIONSHIPS', 'LATEST_UBO_STATUS');

    ---------------------------------------------------------------- next KYC date of parties with an approved case
    run(q'[update xxcmp_parties p
              set next_kyc_date = (select max(c.next_review_date) keep (dense_rank last order by c.closed_date)
                                     from xxcmp_cases c where c.party_id = p.party_id and c.decision = 'APPROVED')
            where p.next_kyc_date is null
              and exists (select 1 from xxcmp_cases c where c.party_id = p.party_id and c.decision = 'APPROVED')]');

    ---------------------------------------------------------------- release 26: an individual's ID type moves to REGISTRATION_TYPE
    run(q'[update xxcmp_parties set registration_type = entity_type, entity_type = null
            where party_type = 'PERSON' and entity_type is not null and registration_type is null]');
    run(q'[update xxcmp_requests set registration_type = entity_type, entity_type = null
            where party_type = 'PERSON' and entity_type is not null and registration_type is null]');
    commit;
end;
/
comment on table xxcmp_party_contacts is 'Contact persons of a party (name, job title, email, phone); one primary per party.';
comment on column xxcmp_parties.jurisdiction is 'Organisation: country of incorporation. Individual: nationality.';
comment on column xxcmp_parties.registration_number is 'Organisation: registration number. Individual: identity document number.';
comment on column xxcmp_parties.entity_type is 'Organisation: entity type, the category (lookup ENTITY_TYPE). Individual: empty.';
comment on column xxcmp_parties.registration_type is 'Type of REGISTRATION_NUMBER. Organisation: registration type (lookup REGISTRATION_TYPE). Individual: identity document type (lookup ID_DOCUMENT_TYPE).';
comment on column xxcmp_parties.incorporation_date is 'Organisation: date of incorporation. Individual: date of birth.';
comment on column xxcmp_requests.last_action_date is 'When the request last moved: saved, submitted, information requested / given, approved, rejected, cancelled.';
