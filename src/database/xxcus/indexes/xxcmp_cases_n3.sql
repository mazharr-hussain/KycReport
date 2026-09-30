create index xxcus.xxcmp_cases_n3 on
    xxcus.xxcmp_cases (
        next_review_date
    );


-- sqlcl_snapshot {"hash":"d01ab00b5e4d39f05129019a2513ffebdfa80c52","type":"INDEX","name":"XXCMP_CASES_N3","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_CASES_N3</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_CASES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>NEXT_REVIEW_DATE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}