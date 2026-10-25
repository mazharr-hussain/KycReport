-- Upgrade fix: partial unique indexes were created as (column, ..., CASE ... END), which also
-- restricted rows outside the condition (ORA-00001 in the seed data). Recreate any index that
-- still has a plain column with every key column inside the CASE. Existing data always fits.
declare
    procedure fix(p_index in varchar2, p_definition in varchar2) is
        l_old pls_integer;
    begin
        select count(*) into l_old from user_ind_columns
         where index_name = p_index and column_name not like 'SYS\_NC%' escape '\';
        if l_old > 0 then
            execute immediate 'drop index ' || p_index;
            execute immediate 'create unique index ' || p_index || ' on ' || p_definition;
        end if;
    end fix;
begin
    fix('XXFND_USER_ROLES_U1', 'xxfnd_user_roles (case when end_date_active is null then employee_id end, case when end_date_active is null then role_code end)');
    fix('XXFND_DF_CONTEXTS_U1', 'xxfnd_df_contexts (case when global_flag = ''Y'' then descriptive_flexfield_code end)');
    -- (XXCMP_PARTY_CONTACTS_U1 became one primary contact person per party in release 23: 16f)
end;
/
