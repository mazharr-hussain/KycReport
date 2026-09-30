create index xxcus.xxfnd_user_roles_n1 on
    xxcus.xxfnd_user_roles (
        employee_id
    );


-- sqlcl_snapshot {"hash":"abbe94854ffb7ce1b55c446323a9208af6bcd83e","type":"INDEX","name":"XXFND_USER_ROLES_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_USER_ROLES_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_USER_ROLES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>EMPLOYEE_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}