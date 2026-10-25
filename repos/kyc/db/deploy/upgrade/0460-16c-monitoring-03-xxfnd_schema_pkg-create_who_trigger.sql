
begin
    for t in (select column_value table_name from table(apex_t_varchar2('XXCMP_ALERT_RULES','XXCMP_ALERTS'))) loop
        xxfnd_schema_pkg.create_who_trigger(t.table_name);
    end loop;
end;
/
