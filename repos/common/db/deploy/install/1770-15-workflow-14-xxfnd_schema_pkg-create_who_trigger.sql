begin
    for t in (select column_value table_name
                from table(apex_t_varchar2('XXFND_NOTIFY_CHANNELS', 'XXFND_NOTIFY_EVENTS', 'XXFND_NOTIFY_RECIPIENT_TYPES',
                                           'XXFND_NOTIFY_RULES', 'XXFND_NOTIFICATIONS'))) loop
        xxfnd_schema_pkg.create_who_trigger(t.table_name);
    end loop;

end;
/
