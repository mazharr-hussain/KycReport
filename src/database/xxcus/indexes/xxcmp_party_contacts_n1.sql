create index xxcus.xxcmp_party_contacts_n1 on
    xxcus.xxcmp_party_contacts (
        party_id
    );


-- sqlcl_snapshot {"hash":"18cdf942b29c0cf743f5630c81abbf0d42cd9ec8","type":"INDEX","name":"XXCMP_PARTY_CONTACTS_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_PARTY_CONTACTS_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_PARTY_CONTACTS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>PARTY_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}