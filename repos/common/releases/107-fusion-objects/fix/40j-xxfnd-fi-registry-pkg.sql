--------------------------------------------------------------------------------
-- XXFND_FI_REGISTRY_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The registry of onboarded Fusion objects and the onboarding steps of the Onboard Object screen (191):
--   an object is created as DRAFT from a catalog row with its live attributes (primary keys and the last-update date
--   pre-selected) and, for a REST resource, its children; the administrator selects attributes and children, the mode
--   and schedule, then ACTIVATE generates what the mode needs (XXFND_FI_GEN_PKG) and the object runs on schedule.
--   Changes need FUSION_OBJECTS - Manage (ORA-20366) unless an install or trusted COMMON code calls.
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_registry_pkg authid definer as
    -- A DRAFT object from a catalog row (P_OBJECT_CODE: the short code of its generated objects, made from the name
    -- when empty). Returns its ID; an object of that source already onboarded is returned as it is.
    function create_object(p_catalog_id       in number,
                           p_object_code      in varchar2 default null,
                           p_parent_object_id in number   default null) return number;
    -- A child resource of a REST object selected (Y) or not (N).
    procedure select_child(p_object_id in number, p_child_name in varchar2, p_selected_flag in varchar2);
    -- Mode (REPLICA, REALTIME, PUSH), schedule (minutes between replica runs) and, for BICC, where its extract lands
    -- (an OBJECT_STORAGE server of the Servers screen, bucket, prefix).
    procedure set_mode(p_object_id           in number,
                       p_mode_code           in varchar2,
                       p_schedule_minutes    in number   default null,
                       p_business_name       in varchar2 default null,
                       p_storage_server_code in varchar2 default null,
                       p_storage_bucket      in varchar2 default null,
                       p_storage_prefix      in varchar2 default null);
    -- Generates what the object needs and makes it ACTIVE (next run now): replica - tables and business view; BICC -
    -- the datastore configuration and its job; each selected REST child becomes a DRAFT object of its own.
    procedure activate(p_object_id in number);
    procedure pause(p_object_id in number);
    procedure resume(p_object_id in number);
    -- RETIRED: no more runs; the generated tables and views are kept (the applications may still read the last data).
    procedure retire(p_object_id in number);
    -- Raises ORA-20366 when the caller may not change the registry (FUSION_OBJECTS - Manage).
    procedure check_manage;
end xxfnd_fi_registry_pkg;
/

create or replace package body xxfnd_fi_registry_pkg as

    procedure check_manage is
    begin
        if not xxfnd_util_pkg.in_apex_session or xxfnd_vpd_pkg.is_trusted then
            return;     -- install, registration and server code
        end if;
        if not xxfnd_privilege_pkg.has_privilege('FUSION_OBJECTS', 'MANAGE') then
            xxfnd_error_pkg.raise_error('XXFND_FI_NOT_ALLOWED', apex_t_varchar2('FUSION_OBJECTS - Manage'));
        end if;
    end check_manage;

    -- a database name from a Fusion name: letters, digits and _, not starting with a digit, at most P_MAX characters,
    -- not an Oracle reserved word
    function db_name(p_name in varchar2, p_max in pls_integer default 30) return varchar2 is
        l_n varchar2(400) := trim(both '_' from upper(regexp_replace(p_name, '[^A-Za-z0-9]+', '_')));
    begin
        if l_n is null or regexp_like(l_n, '^[0-9]') then
            l_n := 'C_' || l_n;
        end if;
        l_n := substr(l_n, 1, p_max);
        if l_n in ('DATE', 'LEVEL', 'NUMBER', 'SIZE', 'COMMENT', 'USER', 'UID', 'ROWID', 'ROWNUM', 'SESSION', 'ACCESS',
                   'FILE', 'MODE', 'OPTION', 'ORDER', 'GROUP', 'TABLE', 'VIEW', 'INDEX', 'START', 'CHECK', 'DEFAULT',
                   'RESOURCE', 'AUDIT', 'LONG', 'RAW', 'CHAR', 'VARCHAR', 'VARCHAR2', 'INTEGER', 'DECIMAL', 'FLOAT',
                   'SELECT', 'FROM', 'WHERE', 'UPDATE', 'DELETE', 'INSERT', 'VALUES', 'SET', 'SHARE', 'LOCK', 'ONLINE') then
            l_n := substr(l_n, 1, p_max - 1) || '_';
        end if;
        return l_n;
    end db_name;

    function unique_code(p_base in varchar2) return varchar2 is
        l_code varchar2(30) := db_name(p_base, 20);
        l_try  varchar2(30) := l_code;
        l_n    pls_integer;
        i      pls_integer := 1;
    begin
        loop
            select count(*) into l_n from xxfnd_fi_objects where object_code = l_try;
            exit when l_n = 0;
            i := i + 1;
            l_try := substr(l_code, 1, 20 - length(to_char(i)) - 1) || '_' || i;
        end loop;
        return l_try;
    end unique_code;

    function create_object(p_catalog_id       in number,
                           p_object_code      in varchar2 default null,
                           p_parent_object_id in number   default null) return number is
        l_cat   xxfnd_fi_catalog%rowtype;
        l_id    number;
        l_attrs xxfnd_fi_meta_pkg.t_attrs;
        l_kids  xxfnd_fi_meta_pkg.t_children;
        l_col   varchar2(128);
        l_try   varchar2(128);
        l_n     pls_integer;
        j       pls_integer;
        l_code  xxfnd_fi_objects.object_code%type;
    begin
        check_manage;
        select * into l_cat from xxfnd_fi_catalog where catalog_id = p_catalog_id;
        select max(object_id) into l_id from xxfnd_fi_objects
         where source_type = l_cat.source_type and source_name = l_cat.source_name
           and decode(parent_object_id, p_parent_object_id, 1, 0) = 1;
        if l_id is not null then
            return l_id;
        end if;
        -- a private function is not called inside SQL (PLS-00231)
        l_code := case when p_object_code is not null then db_name(p_object_code, 20)
                       else unique_code(regexp_substr(l_cat.source_name, '[^/]+$')) end;
        insert into xxfnd_fi_objects (object_code, catalog_id, parent_object_id, source_type, source_name, offering_code,
                                      business_name, mode_code, status_code)
        values (l_code, p_catalog_id, p_parent_object_id, l_cat.source_type, l_cat.source_name, l_cat.offering_code,
                nvl(l_cat.business_name, l_cat.source_name), 'REPLICA', 'DRAFT')
        returning object_id into l_id;
        -- the live attributes; primary keys and the last-update date selected
        l_attrs := xxfnd_fi_meta_pkg.live_attributes(l_cat.source_type, l_cat.source_name);
        for i in 1 .. l_attrs.count loop
            if l_attrs(i).attribute_name is not null then
                l_col := db_name(l_attrs(i).attribute_name);
                l_try := l_col;
                j := 1;
                loop
                    select count(*) into l_n from xxfnd_fi_attributes where object_id = l_id and column_name = l_try;
                    exit when l_n = 0;
                    j := j + 1;
                    l_try := substr(l_col, 1, 30 - length(to_char(j)) - 1) || '_' || j;
                end loop;
                insert into xxfnd_fi_attributes (object_id, attribute_name, column_name, business_name, data_type,
                                                 data_length, data_scale, pk_flag, selected_flag, custom_flag,
                                                 last_update_flag, display_sequence)
                values (l_id, l_attrs(i).attribute_name, l_try,
                        initcap(replace(regexp_replace(l_attrs(i).attribute_name, '([a-z])([A-Z])', '\1 \2'), '_', ' ')),
                        l_attrs(i).data_type, l_attrs(i).data_length, l_attrs(i).data_scale, l_attrs(i).pk_flag,
                        case when l_attrs(i).pk_flag = 'Y' or l_attrs(i).last_update_flag = 'Y' then 'Y' else 'N' end,
                        l_attrs(i).custom_flag, l_attrs(i).last_update_flag, l_attrs(i).display_sequence);
            end if;
        end loop;
        if l_cat.source_type = 'REST' and p_parent_object_id is null then
            l_kids := xxfnd_fi_meta_pkg.live_children(l_cat.source_name);
            for i in 1 .. l_kids.count loop
                insert into xxfnd_fi_children (object_id, child_name, child_path)
                values (l_id, l_kids(i).child_name, l_kids(i).child_path);
            end loop;
        end if;
        return l_id;
    end create_object;

    procedure select_child(p_object_id in number, p_child_name in varchar2, p_selected_flag in varchar2) is
    begin
        check_manage;
        update xxfnd_fi_children
           set selected_flag = case when upper(p_selected_flag) = 'Y' then 'Y' else 'N' end
         where object_id = p_object_id and child_name = p_child_name;
    end select_child;

    procedure set_mode(p_object_id           in number,
                       p_mode_code           in varchar2,
                       p_schedule_minutes    in number   default null,
                       p_business_name       in varchar2 default null,
                       p_storage_server_code in varchar2 default null,
                       p_storage_bucket      in varchar2 default null,
                       p_storage_prefix      in varchar2 default null) is
    begin
        check_manage;
        if upper(p_mode_code) not in ('REPLICA', 'REALTIME', 'PUSH') then
            xxfnd_error_pkg.raise_error('XXFND_FI_MODE', apex_t_varchar2(p_mode_code));
        end if;
        update xxfnd_fi_objects
           set mode_code           = upper(p_mode_code),
               schedule_minutes    = case when upper(p_mode_code) = 'REPLICA' then nvl(p_schedule_minutes, 1440) end,
               business_name       = nvl(p_business_name, business_name),
               storage_server_code = p_storage_server_code,
               storage_bucket      = p_storage_bucket,
               storage_prefix      = p_storage_prefix
         where object_id = p_object_id;
    end set_mode;

    procedure activate(p_object_id in number) is
        l_o   xxfnd_fi_objects%rowtype;
        l_n   pls_integer;
        l_pk  pls_integer;
        l_cat number;
        l_kid number;
    begin
        check_manage;
        select * into l_o from xxfnd_fi_objects where object_id = p_object_id for update;
        if l_o.status_code = 'RETIRED' then
            xxfnd_error_pkg.raise_error('XXFND_FI_RETIRED', apex_t_varchar2(l_o.object_code));
        end if;
        select count(*), count(case when pk_flag = 'Y' then 1 end) into l_n, l_pk
          from xxfnd_fi_attributes where object_id = p_object_id and selected_flag = 'Y' and status_code = 'ACTIVE';
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_ATTRIBUTES', apex_t_varchar2(l_o.object_code));
        elsif l_o.mode_code = 'REPLICA' and l_pk = 0 then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_KEY', apex_t_varchar2(l_o.object_code));
        elsif l_o.source_type = 'BICC' and l_o.mode_code = 'REPLICA'
              and (l_o.storage_server_code is null or l_o.storage_bucket is null) then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_STORAGE', apex_t_varchar2(l_o.object_code));
        end if;
        if l_o.mode_code = 'REPLICA' then
            l_n := xxfnd_fi_gen_pkg.apply_version(p_object_id);
            if l_o.source_type = 'BICC' then
                xxfnd_fi_gen_pkg.bicc_configure(p_object_id);
            end if;
        end if;
        -- each selected REST child: an object of its own (DRAFT, onboarded the same way)
        for c in (select child_name, child_path from xxfnd_fi_children
                   where object_id = p_object_id and selected_flag = 'Y' and child_object_id is null) loop
            merge into xxfnd_fi_catalog t
            using (select 'REST' source_type, c.child_path source_name from dual) s
               on (t.source_type = s.source_type and t.source_name = s.source_name)
             when not matched then insert (source_type, source_name, offering_code, offering_name, business_name)
                                   values ('REST', c.child_path, l_o.source_name, l_o.business_name,
                                           l_o.business_name || ' - ' || c.child_name);
            select catalog_id into l_cat from xxfnd_fi_catalog where source_type = 'REST' and source_name = c.child_path;
            l_kid := create_object(l_cat, null, p_object_id);
            update xxfnd_fi_children set child_object_id = l_kid
             where object_id = p_object_id and child_name = c.child_name;
        end loop;
        update xxfnd_fi_objects
           set status_code = 'ACTIVE',
               next_run_date = case when mode_code = 'REPLICA' then systimestamp end
         where object_id = p_object_id;
    end activate;

    procedure set_status(p_object_id in number, p_from in varchar2, p_to in varchar2) is
    begin
        check_manage;
        update xxfnd_fi_objects
           set status_code = p_to,
               next_run_date = case when p_to = 'ACTIVE' and mode_code = 'REPLICA' then systimestamp end
         where object_id = p_object_id and instr(p_from, status_code) > 0;
        if sql%rowcount = 0 then
            xxfnd_error_pkg.raise_error('XXFND_FI_STATUS', apex_t_varchar2(to_char(p_object_id), p_to));
        end if;
    end set_status;

    procedure pause(p_object_id in number) is
    begin
        set_status(p_object_id, 'ACTIVE', 'PAUSED');
    end pause;

    procedure resume(p_object_id in number) is
    begin
        set_status(p_object_id, 'PAUSED', 'ACTIVE');
    end resume;

    procedure retire(p_object_id in number) is
    begin
        set_status(p_object_id, 'DRAFT,ACTIVE,PAUSED', 'RETIRED');
    end retire;

end xxfnd_fi_registry_pkg;
/
