create index xxcus.xxfnd_attached_documents_n2 on
    xxcus.xxfnd_attached_documents (
        document_id
    );


-- sqlcl_snapshot {"hash":"7e0a53b79baf6d2e3a8f021ec4c5e7922d00ec2c","type":"INDEX","name":"XXFND_ATTACHED_DOCUMENTS_N2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_ATTACHED_DOCUMENTS_N2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_ATTACHED_DOCUMENTS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>DOCUMENT_ID</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}