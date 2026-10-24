--------------------------------------------------------------------------------
-- XXFND_FI_DRIFT_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   Governance of the onboarded objects' metadata: CHECK compares the live metadata with the registry.
--   - Non-breaking, applied at once (AUTO_APPLIED): a new attribute (added unselected, the administrator may select
--     it), a longer length of a selected attribute (column widened, new version of the business view).
--   - Breaking, waiting on the Drift Queue (PENDING): a selected attribute removed, its type changed or shortened.
--     APPROVE applies it (removed: unselected, kept in the replica; type / length: the attribute takes the new value,
--     the tables follow) and makes a new version; REJECT keeps the registry as it is.
--   The holders of FUSION_OBJECTS - Manage are told (notification template XXFND_FI_ALERT).
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_drift_pkg authid definer as
    -- Checks one object; returns the number of changes found (logged as a CHECK run).
    function check_object(p_object_id in number) return number;
    -- Checks every active object not checked in the last P_HOURS hours.
    procedure check_all(p_hours in number default 24);
    procedure approve(p_drift_id in number);
    procedure reject(p_drift_id in number);
    -- Tells the holders of FUSION_OBJECTS - Manage about an object (P_EVENT: what happened).
    procedure alert(p_object_id in number, p_event in varchar2);
end xxfnd_fi_drift_pkg;
/

create or replace package body xxfnd_fi_drift_pkg as

    procedure alert(p_object_id in number, p_event in varchar2) is
        l_users varchar2(32767) := xxfnd_workflow_pkg.users_with_privilege('FUSION_OBJECTS', 'MANAGE');
        l_name  xxfnd_fi_objects.business_name%type;
    begin
        if l_users is null then
            return;
        end if;
        select max(business_name) into l_name from xxfnd_fi_objects where object_id = p_object_id;
        xxfnd_notify_pkg.send_to_users('XXFND_FI_ALERT', l_users,
            json_object('OBJECT' value l_name, 'EVENT' value substr(p_event, 1, 2000)));
    exception
        when others then
            null;   -- an alert never stops the run or the check that raised it
    end alert;

    procedure add_drift(p_object_id in number, p_type in varchar2, p_attr in varchar2, p_old in varchar2,
                        p_new in varchar2, p_breaking in varchar2) is
        l_n pls_integer;
    begin
        -- the same open change is recorded once
        select count(*) into l_n from xxfnd_fi_drift
         where object_id = p_object_id and attribute_name = p_attr and change_type = p_type
           and status_code = 'PENDING' and decode(new_value, p_new, 1, 0) = 1;
        if l_n = 0 then
            insert into xxfnd_fi_drift (object_id, change_type, attribute_name, old_value, new_value, breaking_flag,
                                        status_code, decided_by, decided_date)
            values (p_object_id, p_type, p_attr, substr(p_old, 1, 400), substr(p_new, 1, 400), p_breaking,
                    case when p_breaking = 'Y' then 'PENDING' else 'AUTO_APPLIED' end,
                    case when p_breaking = 'N' then 'SYSTEM' end, case when p_breaking = 'N' then systimestamp end);
        end if;
    end add_drift;

    function check_object(p_object_id in number) return number is
        l_o        xxfnd_fi_objects%rowtype;
        l_live     xxfnd_fi_meta_pkg.t_attrs;
        l_found    apex_t_varchar2 := apex_t_varchar2();
        l_changes  pls_integer := 0;
        l_breaking pls_integer := 0;
        l_apply    boolean := false;
        l_run      number;
        l_ver      number;
        l_n        pls_integer;
        l_col      varchar2(128);
    begin
        select * into l_o from xxfnd_fi_objects where object_id = p_object_id;
        insert into xxfnd_fi_runs (object_id, run_type) values (p_object_id, 'CHECK') returning run_id into l_run;
        l_live := xxfnd_fi_meta_pkg.live_attributes(l_o.source_type, l_o.source_name);
        for i in 1 .. l_live.count loop
            l_found.extend;
            l_found(l_found.count) := l_live(i).attribute_name;
            for a in (select * from xxfnd_fi_attributes
                       where object_id = p_object_id and attribute_name = l_live(i).attribute_name) loop
                if a.selected_flag = 'Y' and a.status_code = 'ACTIVE' then
                    if upper(a.data_type) <> upper(l_live(i).data_type) then
                        add_drift(p_object_id, 'TYPE', a.attribute_name, a.data_type, l_live(i).data_type, 'Y');
                        l_breaking := l_breaking + 1;
                    elsif nvl(l_live(i).data_length, 0) > nvl(a.data_length, 0) and a.data_length is not null then
                        add_drift(p_object_id, 'LENGTH', a.attribute_name, a.data_length, l_live(i).data_length, 'N');
                        update xxfnd_fi_attributes set data_length = l_live(i).data_length
                         where object_id = p_object_id and attribute_name = a.attribute_name;
                        l_apply := true;
                        l_changes := l_changes + 1;
                    elsif nvl(l_live(i).data_length, 0) < nvl(a.data_length, 0) and l_live(i).data_length is not null then
                        add_drift(p_object_id, 'LENGTH', a.attribute_name, a.data_length, l_live(i).data_length, 'Y');
                        l_breaking := l_breaking + 1;
                    end if;
                elsif a.status_code = 'REMOVED' then
                    -- back in the metadata: available again (unselected)
                    update xxfnd_fi_attributes set status_code = 'ACTIVE', selected_flag = 'N'
                     where object_id = p_object_id and attribute_name = a.attribute_name;
                end if;
            end loop;
            select count(*) into l_n from xxfnd_fi_attributes
             where object_id = p_object_id and attribute_name = l_live(i).attribute_name;
            if l_n = 0 then
                -- a new attribute: available to select (non-breaking)
                l_col := substr(trim(both '_' from upper(regexp_replace(l_live(i).attribute_name, '[^A-Za-z0-9]+', '_'))), 1, 26);
                if l_col is null or regexp_like(l_col, '^[0-9]') then
                    l_col := 'C_' || substr(l_col, 1, 24);
                end if;
                select count(*) into l_n from xxfnd_fi_attributes where object_id = p_object_id and column_name = l_col;
                if l_n > 0 then
                    l_col := l_col || '_' || (l_n + 1);
                end if;
                insert into xxfnd_fi_attributes (object_id, attribute_name, column_name, business_name, data_type,
                                                 data_length, data_scale, pk_flag, selected_flag, custom_flag,
                                                 last_update_flag, display_sequence)
                values (p_object_id, l_live(i).attribute_name, l_col, l_live(i).attribute_name, l_live(i).data_type,
                        l_live(i).data_length, l_live(i).data_scale, l_live(i).pk_flag, 'N', l_live(i).custom_flag,
                        l_live(i).last_update_flag, 1000 + i);
                add_drift(p_object_id, 'ADDED', l_live(i).attribute_name, null, l_live(i).data_type, 'N');
                l_changes := l_changes + 1;
            end if;
        end loop;
        -- selected attributes no longer in the metadata
        for a in (select attribute_name, selected_flag from xxfnd_fi_attributes
                   where object_id = p_object_id and status_code = 'ACTIVE'
                     and attribute_name not in (select column_value from table(l_found))) loop
            if a.selected_flag = 'Y' then
                add_drift(p_object_id, 'REMOVED', a.attribute_name, a.attribute_name, null, 'Y');
                l_breaking := l_breaking + 1;
            else
                -- not used by the object: no longer offered (non-breaking)
                update xxfnd_fi_attributes set status_code = 'REMOVED'
                 where object_id = p_object_id and attribute_name = a.attribute_name;
            end if;
        end loop;
        if l_apply and l_o.status_code = 'ACTIVE' and l_o.mode_code = 'REPLICA' then
            l_ver := xxfnd_fi_gen_pkg.apply_version(p_object_id);
        end if;
        update xxfnd_fi_runs
           set status_code = 'SUCCESS', ended_date = systimestamp,
               message = l_changes || ' change(s) applied, ' || l_breaking || ' waiting for approval'
         where run_id = l_run;
        commit;
        if l_breaking > 0 then
            alert(p_object_id, l_breaking || ' metadata change(s) wait for approval on the Drift Queue');
        end if;
        return l_changes + l_breaking;
    exception
        when others then
            rollback;
            if l_run is not null then
                update xxfnd_fi_runs set status_code = 'FAILED', ended_date = systimestamp,
                       message = substr(sqlerrm, 1, 4000)
                 where run_id = l_run;
                commit;
            end if;
            raise;
    end check_object;

    procedure check_all(p_hours in number default 24) is
        l_n number;
    begin
        for o in (select o.object_id from xxfnd_fi_objects o
                   where o.status_code = 'ACTIVE'
                     and not exists (select 1 from xxfnd_fi_runs r
                                      where r.object_id = o.object_id and r.run_type = 'CHECK'
                                        and r.started_date > systimestamp - numtodsinterval(p_hours, 'HOUR'))) loop
            begin
                l_n := check_object(o.object_id);
            exception
                when others then
                    alert(o.object_id, 'Metadata check failed: ' || sqlerrm);
            end;
        end loop;
    end check_all;

    procedure decide(p_drift_id in number, p_status in varchar2) is
        l_d   xxfnd_fi_drift%rowtype;
        l_o   xxfnd_fi_objects%rowtype;
        l_ver number;
    begin
        xxfnd_fi_registry_pkg.check_manage;
        select * into l_d from xxfnd_fi_drift where drift_id = p_drift_id for update;
        if l_d.status_code <> 'PENDING' then
            xxfnd_error_pkg.raise_error('XXFND_FI_DRIFT_DONE', apex_t_varchar2(to_char(p_drift_id)));
        end if;
        if p_status = 'APPROVED' then
            if l_d.change_type = 'REMOVED' then
                update xxfnd_fi_attributes set status_code = 'REMOVED', selected_flag = 'N'
                 where object_id = l_d.object_id and attribute_name = l_d.attribute_name;
            elsif l_d.change_type = 'TYPE' then
                update xxfnd_fi_attributes set data_type = l_d.new_value
                 where object_id = l_d.object_id and attribute_name = l_d.attribute_name;
            elsif l_d.change_type = 'LENGTH' then
                update xxfnd_fi_attributes set data_length = to_number(l_d.new_value default null on conversion error)
                 where object_id = l_d.object_id and attribute_name = l_d.attribute_name;
            end if;
            select * into l_o from xxfnd_fi_objects where object_id = l_d.object_id;
            if l_o.status_code = 'ACTIVE' and l_o.mode_code = 'REPLICA' then
                l_ver := xxfnd_fi_gen_pkg.apply_version(l_d.object_id);
            end if;
        end if;
        update xxfnd_fi_drift
           set status_code = p_status, decided_by = xxfnd_util_pkg.current_user, decided_date = systimestamp
         where drift_id = p_drift_id;
    end decide;

    procedure approve(p_drift_id in number) is
    begin
        decide(p_drift_id, 'APPROVED');
    end approve;

    procedure reject(p_drift_id in number) is
    begin
        decide(p_drift_id, 'REJECTED');
    end reject;

end xxfnd_fi_drift_pkg;
/
