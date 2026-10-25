begin
    if xxfnd_ddl_pkg.create_table('XXFND_SERVER_TESTS', q'~create table xxfnd_server_tests (
    server_static_id       varchar2(255)  not null,
    tested_date            timestamp      not null,
    tested_by              varchar2(255)  not null,
    http_status            number(3),
    result_code            varchar2(20)   not null,
    result_message         varchar2(4000),
    constraint xxfnd_server_tests_pk primary key (server_static_id),
    constraint xxfnd_server_tests_ck1 check (result_code in ('REACHABLE','FAILED'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_server_tests is 'Release 83: the last Test Connection of each APEX Remote Server (Servers screen health).'~');
    end if;
end;
/
