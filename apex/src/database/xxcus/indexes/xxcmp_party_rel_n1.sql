create index xxcus.xxcmp_party_rel_n1 on
    xxcus.xxcmp_party_relationships (
        subject_party_id
    );


-- sqlcl_snapshot {"hash":"3587feb86126339fda23caa3658ce17d5e267225","type":"INDEX","name":"XXCMP_PARTY_REL_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_PARTY_REL_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_PARTY_RELATIONSHIPS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>SUBJECT_PARTY_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}