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
