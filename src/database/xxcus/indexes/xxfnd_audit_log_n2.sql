create index xxcus.xxfnd_audit_log_n2 on
    xxcus.xxfnd_audit_log (
        changed_date
    );


-- sqlcl_snapshot {"hash":"10a6ed211c55c56bf241eb4882734bacadb9313e","type":"INDEX","name":"XXFND_AUDIT_LOG_N2","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_AUDIT_LOG_N2</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_AUDIT_LOG</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>CHANGED_DATE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}