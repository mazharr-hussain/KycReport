create index xxcus.xxcmp_questions_n1 on
    xxcus.xxcmp_questions (
        questionnaire_code,
        display_sequence
    );


-- sqlcl_snapshot {"hash":"8d09b06d19bdf6ed8ae1de616cbae54ed5a34d72","type":"INDEX","name":"XXCMP_QUESTIONS_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_QUESTIONS_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_QUESTIONS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>QUESTIONNAIRE_CODE</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>DISPLAY_SEQUENCE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}