create unique index xxcus.xxfnd_df_contexts_u1 on
    xxcus.xxfnd_df_contexts (
        case
            global_flag
            when 'Y' then
                    descriptive_flexfield_code
        end
    );


-- sqlcl_snapshot {"hash":"eb45210e7e2295fe207b6a750585c8fc49cd656b","type":"INDEX","name":"XXFND_DF_CONTEXTS_U1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_DF_CONTEXTS_U1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_DF_CONTEXTS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>CASE \"GLOBAL_FLAG\" WHEN 'Y' THEN \"DESCRIPTIVE_FLEXFIELD_CODE\" END </DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}