create index xxcus.xxfnd_user_roles_n2 on
    xxcus.xxfnd_user_roles (
        role_code
    );


-- sqlcl_snapshot {"hash":"0191cae3697f4675c79c0259f7d9fde24094c825","type":"INDEX","name":"XXFND_USER_ROLES_N2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_USER_ROLES_N2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_USER_ROLES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>ROLE_CODE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}