--------------------------------------------------------------------------------
-- 15b Common workflow runtime (release 74). COMMON only (XXFUSION); every application uses it.
--   The APEX Workflow engine runs the processes; this package is the one place components start, check and end
--   them (no copies in the component packages). Components keep their own rules: when to start, what to do next.
-- Idempotent.
--------------------------------------------------------------------------------
create or replace package xxfnd_workflow_pkg authid definer as
    -- Starts the APEX workflow p_static_id for the record p_detail_pk; returns the workflow ID.
    function start_process(p_static_id      in varchar2,
                           p_detail_pk      in varchar2,
                           p_initiator      in varchar2 default null,
                           p_application_id in number   default null) return number;
    -- ACTIVE, SUSPENDED, FAULTED, COMPLETED, TERMINATED ... (null when unknown).
    function state(p_workflow_id in number) return varchar2;
    -- Y while the workflow still runs (active, suspended or faulted).
    function is_running(p_workflow_id in number) return varchar2;
    -- Ends a running workflow and its open tasks; nothing when it already ended.
    procedure end_process(p_workflow_id in number);
end xxfnd_workflow_pkg;
/

create or replace package body xxfnd_workflow_pkg as

    function start_process(p_static_id      in varchar2,
                           p_detail_pk      in varchar2,
                           p_initiator      in varchar2 default null,
                           p_application_id in number   default null) return number is
        l_id number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        begin
            l_id := apex_workflow.start_workflow(
                        p_application_id => coalesce(p_application_id, to_number(v('APP_ID'))),
                        p_static_id      => p_static_id,
                        p_initiator      => coalesce(p_initiator, nullif(v('APP_USER'), 'nobody')),
                        p_detail_pk      => p_detail_pk);
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        return l_id;
    end start_process;

    function state(p_workflow_id in number) return varchar2 is
        l_state varchar2(30);
    begin
        if p_workflow_id is null then
            return null;
        end if;
        select max(state_code) into l_state from apex_workflows where workflow_id = p_workflow_id;
        return l_state;
    end state;

    function is_running(p_workflow_id in number) return varchar2 is
    begin
        return case when state(p_workflow_id) in ('ACTIVE', 'SUSPENDED', 'FAULTED') then 'Y' else 'N' end;
    end is_running;

    procedure end_process(p_workflow_id in number) is
    begin
        if is_running(p_workflow_id) = 'N' then
            return;
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            apex_workflow.terminate(p_instance_id => p_workflow_id);
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end end_process;

end xxfnd_workflow_pkg;
/
