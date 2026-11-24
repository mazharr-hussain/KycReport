declare
    l_new boolean;
begin

    for t in (select column_value t from table(apex_t_varchar2('XXFND_USER_APPLICATIONS', 'XXFND_ROLE_MEMBERS',
                  'XXHR_ORGANIZATIONS', 'XXFND_DATA_DIMENSIONS', 'XXFND_DATA_OBJECTS', 'XXFND_ROLE_DATA_ACCESS',
                  'XXFND_ASSIGNMENT_VALUES'))) loop
        xxfnd_schema_pkg.create_who_trigger(t.t);
    end loop;

end;
/
