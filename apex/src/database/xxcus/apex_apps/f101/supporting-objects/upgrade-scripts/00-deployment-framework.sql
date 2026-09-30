--------------------------------------------------------------------------------
-- 00_deployment_framework.sql
-- Release tracking for chunk deployments. Every chunk ships one idempotent
-- upgrade script that (1) checks XXFND_DDL_PKG.RELEASE_APPLIED, (2) applies its
-- DDL with IF [NOT] EXISTS / ADD_COLUMN, and (3) records itself with MARK_RELEASE.
-- Re-importing the same release therefore changes nothing.
--------------------------------------------------------------------------------
create table if not exists xxfnd_schema_releases (
    release_code           varchar2(30)   not null,
    description            varchar2(400)  not null,
    applied_date           timestamp      default systimestamp not null,
    applied_by             varchar2(255)  not null,
    constraint xxfnd_schema_releases_pk primary key (release_code)
);

create or replace package xxfnd_ddl_pkg authid current_user as
    -- True once MARK_RELEASE has recorded this release in this schema.
    function release_applied(p_release_code in varchar2) return boolean;
    procedure mark_release(p_release_code in varchar2, p_description in varchar2);
    -- ALTER TABLE ... ADD (<column> <definition>) only when the column is missing.
    procedure add_column(p_table_name in varchar2, p_column_name in varchar2, p_definition in varchar2);
end xxfnd_ddl_pkg;
/

create or replace package body xxfnd_ddl_pkg as

    function release_applied(p_release_code in varchar2) return boolean is
        l_count pls_integer;
    begin
        select count(*) into l_count from xxfnd_schema_releases where release_code = upper(p_release_code);
        return l_count > 0;
    end release_applied;

    procedure mark_release(p_release_code in varchar2, p_description in varchar2) is
    begin
        merge into xxfnd_schema_releases t
        using (select upper(p_release_code) release_code from dual) s
           on (t.release_code = s.release_code)
         when not matched then
            insert (release_code, description, applied_by)
            values (s.release_code, p_description,
                    coalesce(sys_context('APEX$SESSION', 'APP_USER'), sys_context('USERENV', 'SESSION_USER')));
    end mark_release;

    procedure add_column(p_table_name in varchar2, p_column_name in varchar2, p_definition in varchar2) is
        l_table  varchar2(128) := upper(dbms_assert.simple_sql_name(p_table_name));
        l_column varchar2(128) := upper(dbms_assert.simple_sql_name(p_column_name));
        l_count  pls_integer;
    begin
        select count(*) into l_count from user_tab_columns where table_name = l_table and column_name = l_column;
        if l_count = 0 then
            execute immediate 'alter table ' || l_table || ' add (' || l_column || ' ' || p_definition || ')';
        end if;
    end add_column;

end xxfnd_ddl_pkg;
/

begin
    xxfnd_ddl_pkg.mark_release('R09', 'Release 9: deployment framework (baseline incl. install fixes and Chunk 0)');
    commit;
end;
/
