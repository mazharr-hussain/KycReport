create index xxcus.xxcmp_party_rel_n2 on
    xxcus.xxcmp_party_relationships (
        object_party_id
    );


-- sqlcl_snapshot {"hash":"10cdd1c5c28e84dd7bd79d4fd6a3fe28ce59918b","type":"INDEX","name":"XXCMP_PARTY_REL_N2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_PARTY_REL_N2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_PARTY_RELATIONSHIPS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>OBJECT_PARTY_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}