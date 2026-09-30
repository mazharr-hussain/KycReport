create index xxcus.xxfnd_documents_n2 on
    xxcus.xxfnd_documents (
        base_document_id
    );


-- sqlcl_snapshot {"hash":"dbe44c18f16398a35ab86f526295dc3e4a7cc816","type":"INDEX","name":"XXFND_DOCUMENTS_N2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_DOCUMENTS_N2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_DOCUMENTS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>BASE_DOCUMENT_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}