-- One-time DBA step (run as ADMIN on ATP / SYS locally) before importing the COMMON app.
-- Creates the XXFUS schema (Fusion web-service data and every shared object) and adds it
-- to the APEX workspace so the COMMON app can parse as XXFUS. Safe to re-run.
-- Prompts for: xxfus_password, tablespace (DATA on ATP), workspace (the APEX workspace of the apps).
declare
    procedure run(p varchar2) is begin execute immediate p; exception when others then
        if sqlcode not in (-1920, -1031) then raise; end if; end;
begin
    run(q'[create user xxfus identified by "&xxfus_password" default tablespace &tablespace quota unlimited on &tablespace]');
end;
/
grant create session, create table, create view, create sequence, create procedure,
      create trigger, create type, create synonym, create job, create materialized view to xxfus;
begin
    apex_instance_admin.add_schema(p_workspace => '&workspace', p_schema => 'XXFUS');
    commit;
exception when others then
    if sqlerrm not like '%already%' then raise; end if;
end;
/
-- data security (VPD policies) and document hashing
grant execute on sys.dbms_rls to xxfus;
grant execute on sys.dbms_crypto to xxfus;
