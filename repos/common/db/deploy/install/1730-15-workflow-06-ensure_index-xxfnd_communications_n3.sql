begin
    -- R23: the reply link (foreign key) is indexed
    xxfnd_ddl_pkg.ensure_index('XXFND_COMMUNICATIONS_N3',
        'create index xxfnd_communications_n3 on xxfnd_communications (in_reply_to_id)');
    xxfnd_schema_pkg.create_who_trigger('XXFND_COMMUNICATIONS');

end;
/
