-- Release 96: removes what r96_security_ui_setup.sql and the browser test added (run as XXFUSION)
begin
    delete from xxfnd_assignment_values where data_object_code = 'R96_PATHS'
        or user_role_id in (select ur.user_role_id from xxfnd_user_roles ur join xxfnd_users u on u.user_id = ur.user_id
                             where u.user_name = 'REQ1' and ur.role_code = 'REQUESTER');
    delete from xxfnd_role_data_access where role_code = 'REQUESTER' and access_level = 'VALUES';
    delete from xxfnd_data_objects where data_object_code = 'R96_PATHS';
    update xxfnd_data_objects set dimension_code = null, dimension_column = null where data_object_code = 'XXCMP_REQUESTS';
    commit;
end;
/
exit
