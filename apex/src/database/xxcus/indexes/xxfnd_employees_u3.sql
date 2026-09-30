create unique index xxcus.xxfnd_employees_u3 on
    xxcus.xxfnd_employees (
        fusion_person_id
    );


-- sqlcl_snapshot {"hash":"5ed7ca3457f0158ffbf4ce36d4cb8dc1a1979c2b","type":"INDEX","name":"XXFND_EMPLOYEES_U3","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_EMPLOYEES_U3</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_EMPLOYEES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>FUSION_PERSON_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}