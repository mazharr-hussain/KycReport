create unique index xxcus.xxcmp_attachment_rules_u1 on
    xxcus.xxcmp_attachment_rules (
        entity_name,
        category_code,
    nvl(jurisdiction, '#'),
    nvl(entity_type, '#') );


-- sqlcl_snapshot {"hash":"3025678d08d62efbd73dcd776181e87307709e78","type":"INDEX","name":"XXCMP_ATTACHMENT_RULES_U1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_ATTACHMENT_RULES_U1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_ATTACHMENT_RULES</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>ENTITY_NAME</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CATEGORY_CODE</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>NVL(\"JURISDICTION\",'#')</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>NVL(\"ENTITY_TYPE\",'#')</DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}