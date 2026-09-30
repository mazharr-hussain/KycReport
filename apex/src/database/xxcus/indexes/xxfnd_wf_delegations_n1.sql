create index xxcus.xxfnd_wf_delegations_n1 on
    xxcus.xxfnd_wf_delegations (
        delegator_user_name,
        start_date,
        end_date
    );


-- sqlcl_snapshot {"hash":"304e3e0a31449ef1e255d1871f86c02aebfaf859","type":"INDEX","name":"XXFND_WF_DELEGATIONS_N1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_WF_DELEGATIONS_N1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXFND_WF_DELEGATIONS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>DELEGATOR_USER_NAME</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>START_DATE</NAME>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>END_DATE</NAME>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}