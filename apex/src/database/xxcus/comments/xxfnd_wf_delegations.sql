comment on table xxcus.xxfnd_wf_delegations is
    'Delegations (vacation rules): tasks of the delegator are also offered to the delegate between the dates. Read by XXFND_TASK_PKG.VACATION_RULE.'
    ;

comment on column xxcus.xxfnd_wf_delegations.task_definition is
    'Task definition static ID; null = every task.';


-- sqlcl_snapshot {"hash":"54d8c9830ee60a7731fd5889883729331ab2843e","type":"COMMENT","name":"xxfnd_wf_delegations","schemaName":"xxcus","sxml":""}