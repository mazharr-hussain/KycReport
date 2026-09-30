create unique index xxcus.xxfnd_user_roles_u1 on
    xxcus.xxfnd_user_roles (
        case
            when
                end_date_active
            is null then
                    employee_id
        end,
        case
            when
                end_date_active
            is null then
                    role_code
        end
    );


-- sqlcl_snapshot {"hash":"1134a015785eecbbd3ac08bfdbbc76033df94888","type":"INDEX","name":"XXFND_USER_ROLES_U1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_USER_ROLES_U1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_USER_ROLES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>CASE  WHEN \"END_DATE_ACTIVE\" IS NULL THEN \"EMPLOYEE_ID\" END </DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>CASE  WHEN \"END_DATE_ACTIVE\" IS NULL THEN \"ROLE_CODE\" END </DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}