-- Releases 87 / 88 checks, part 2 of 3 (run as XXCUS, an application's schema, after r87_common_test.sql): the
-- application registers itself (ONBOARD_SELF), changes COMMON data only through the routines and only for its own
-- applications, sees only its own setup and the shared rows, and gives COMMON the contacts of its records.
set serveroutput on feedback off
declare
    l_n   number;
    l_txt varchar2(4000);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
    procedure expect_error(p_code in number, p_text in varchar2, p_block in varchar2) is
    begin
        execute immediate p_block;
        check_(false, p_text || ' (no error)');
    exception
        when others then
            check_(sqlcode = p_code or (p_code = -1031 and sqlcode = -41900), p_text || ' (' || sqlcode || case when sqlcode <> p_code then ' ' || sqlerrm end || ')');
    end expect_error;
begin
    ---------------------------------------------------------------- 87: basic onboarding from the application's install
    expect_error(-20194, 'an alias that is not an application of the schema is refused',
                 q'~begin xxfusion.xxfnd_onboard_pkg.onboard_self('XXCUS', 'R87NONE'); end;~');
    xxfusion.xxfnd_onboard_pkg.onboard_self('XXCUS', 'R86DEL', 'ADMIN');
    commit;
    check_(xxfusion.xxfnd_onboard_pkg.is_onboarded('R86DEL') = 'Y', 'ONBOARD_SELF registers the application of the schema');
    select count(*) into l_n from xxfusion.xxfnd_app_menu_entries where application_code = 'R86DEL';
    check_(l_n > 0, 'with its menu entries (' || l_n || ')');
    xxfusion.xxfnd_onboard_pkg.onboard_self('XXCUS', 'R86DEL', 'ADMIN');
    commit;
    check_(true, 'a re-run of ONBOARD_SELF is accepted');

    ---------------------------------------------------------------- 87: the caller changes only its own applications
    expect_error(-20192, 'an application schema cannot change COMMON''s own setup',
                 q'~begin xxfusion.xxfnd_lookup_pkg.register_lookup_type('COMMON', 'R87_NOT_MINE', 'x'); end;~');
    xxfusion.xxfnd_lookup_pkg.register_lookup_type('R86DEL', 'R87_DEL_LT', 'R87 delete test lookup');
    xxfusion.xxfnd_lookup_pkg.register_lookup_value('R86DEL', 'R87_DEL_LT', 'X', 'X');
    xxfusion.xxfnd_application_pkg.register_menu_entry('R86DEL', 'R87_HOME', 'Home', 'APP_PAGE', 1);
    commit;
    check_(true, 'its own application''s rows are registered');

    ---------------------------------------------------------------- 88 C10: no direct write
    expect_error(-1031, 'a direct INSERT into a COMMON table is refused',
                 q'~insert into xxfusion.xxfnd_lookup_types (lookup_type, meaning) values ('R87_DIRECT', 'x')~');
    expect_error(-1031, 'a direct UPDATE is refused',
                 q'~update xxfusion.xxfnd_lookup_types set meaning = meaning where lookup_type = 'R87_DEL_LT'~');

    ---------------------------------------------------------------- 87: setup per application, shared rows for all
    select count(*) into l_n from xxfusion.xxfnd_lookup_types where application_code = 'R86DEL';
    check_(l_n = 1, 'the application sees its own setup');
    select count(*) into l_n from xxfusion.xxfnd_lookup_types where application_code is null;
    check_(l_n > 0, 'and the shared rows (' || l_n || ')');
    select count(*) into l_n from xxfusion.xxfnd_lookup_types
     where application_code is not null
       and application_code not in (select application_code from xxfusion.xxfnd_applications where schema_name = 'XXCUS');
    check_(l_n = 0, 'never another application''s setup (' || l_n || ')');

    ---------------------------------------------------------------- 88 C6: the contacts of a record
    execute immediate q'~create or replace view r87_contacts_v as
        select '1' as pk1_value, 'Test Contact' as contact_name, 'contact@example.com' as email_address from dual
        union all select '1', 'No Mail', null from dual~';
    execute immediate 'grant select on r87_contacts_v to xxfusion';
    expect_error(-20197, 'a view without the contact columns is refused',
                 q'~begin xxfusion.xxfnd_notify_pkg.register_contact_source('R86DEL', 'R87_ENTITY', 'USER_TABLES'); end;~');
    xxfusion.xxfnd_notify_pkg.register_contact_source('R86DEL', 'R87_ENTITY', 'R87_CONTACTS_V', 'R87 test');
    commit;
    select count(*), max(email_address) into l_n, l_txt from table(xxfusion.xxfnd_notify_pkg.contacts('R87_ENTITY', '1'));
    check_(l_n = 1 and l_txt = 'contact@example.com', 'the record''s contacts with an address are offered (' || l_n || ')');
    select count(*) into l_n from table(xxfusion.xxfnd_notify_pkg.contacts('R87_ENTITY', '2'));
    check_(l_n = 0, 'another record has none');
    expect_error(-20186, 'another application''s contact source is refused',
                 q'~begin xxfusion.xxfnd_notify_pkg.register_contact_source('R86TEST', 'R87_ENTITY', 'R87_CONTACTS_V'); end;~');
end;
/
