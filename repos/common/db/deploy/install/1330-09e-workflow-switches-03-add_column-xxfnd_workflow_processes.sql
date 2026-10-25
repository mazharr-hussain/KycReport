begin
    xxfnd_schema_pkg.create_who_trigger('XXFND_WORKFLOW_PROCESSES');
    -- release 82: who acts on the process - RULE (the Approval Setup rules decide) or CHOSEN (the user who starts it
    -- chooses, e.g. the recipient of a request for information); before XXFND_WORKFLOW_PKG (15) reads the table
    xxfnd_ddl_pkg.add_column('XXFND_WORKFLOW_PROCESSES', 'PARTICIPANTS_TYPE', q'~varchar2(30) default 'RULE' not null~');
    xxfnd_ddl_pkg.add_constraint('XXFND_WORKFLOW_PROCESSES', 'XXFND_WORKFLOW_PROCESSES_CK3',
        q'~check (participants_type in ('RULE','CHOSEN'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_workflow_processes.participants_type is 'Who acts on the process: RULE = the Approval Setup rules decide; CHOSEN = the user who starts it chooses (e.g. the recipient of a request for information).'~');

end;
/

