create index xxcus.xxcmp_answer_options_n1 on
    xxcus.xxcmp_answer_options (
        question_id
    );


-- sqlcl_snapshot {"hash":"e7f84a2568cfcb5719d3cd4c654c435db07dd1b6","type":"INDEX","name":"XXCMP_ANSWER_OPTIONS_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_ANSWER_OPTIONS_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_ANSWER_OPTIONS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>QUESTION_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}