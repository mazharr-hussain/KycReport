--------------------------------------------------------------------------------
-- Steps 6.3 / 7.6, run as the application schema (proxy) after a deploy: online validation.
--   - every object compiles: no invalid object, no compile error (USER_ERRORS)
--   - the APEX application is installed in this schema, available, with every page of the source
-- Substitution variables: app_id, expected_pages (page files in the built application).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_problems pls_integer := 0;
    l_n        pls_integer;
    l_owner    apex_applications.owner%type;
    l_status   apex_applications.availability_status%type;
    l_pages    apex_applications.pages%type;
    procedure problem(p_text varchar2) is
    begin
        dbms_output.put_line('FAIL ' || p_text);
        l_problems := l_problems + 1;
    end problem;
begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
    for o in (select object_type, object_name from user_objects where status = 'INVALID' order by 1, 2) loop
        problem('invalid ' || o.object_type || ' ' || o.object_name);
    end loop;
    for e in (select name, type, line, text from user_errors where attribute = 'ERROR' order by name, type, sequence) loop
        problem('compile error ' || e.type || ' ' || e.name || ' line ' || e.line || ': ' || substr(e.text, 1, 200));
    end loop;
    select count(*) into l_n from apex_applications where application_id = &app_id;
    if l_n = 0 then
        problem('application &app_id is not installed');
    else
        select owner, availability_status, pages into l_owner, l_status, l_pages
          from apex_applications where application_id = &app_id;
        if l_owner <> user then
            problem('application &app_id parses as ' || l_owner || ', expected ' || user);
        end if;
        if l_status not like 'Available%' then
            problem('application &app_id is not available: ' || l_status);
        end if;
        if l_pages <> &expected_pages then
            problem('application &app_id has ' || l_pages || ' page(s), the source has &expected_pages');
        end if;
    end if;
    if l_problems > 0 then
        raise_application_error(-20004, 'Online validation failed: ' || l_problems || ' problem(s) - see the FAIL lines.');
    end if;
    dbms_output.put_line('online validation passed: no invalid object, application &app_id available with '
        || l_pages || ' page(s)');
end;
/
