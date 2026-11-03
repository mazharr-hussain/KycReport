-- Release 89 test setup (pipeline 8.2 runs it first, as XXCUS; kept): two small tables of the test application R86TEST (schema XXCUS)
-- Schema: XXCUS
-- for the Data Model test (r89_data_model_test.sql): R89_PARENT and R89_CHILD with a foreign key and an index.
set serveroutput on feedback off
declare
    procedure ddl(p_name in varchar2, p_sql in varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from user_objects where object_name = p_name;
        if l_n = 0 then
            execute immediate p_sql;
        end if;
    end ddl;
begin
    ddl('R89_PARENT', 'create table r89_parent (parent_id number primary key, parent_code varchar2(30) not null unique)');
    ddl('R89_CHILD', 'create table r89_child (child_id number primary key, parent_id number not null references r89_parent, note varchar2(100))');
    ddl('R89_CHILD_N1', 'create index r89_child_n1 on r89_child (parent_id)');
    dbms_output.put_line('R89 test tables ready');
end;
/
