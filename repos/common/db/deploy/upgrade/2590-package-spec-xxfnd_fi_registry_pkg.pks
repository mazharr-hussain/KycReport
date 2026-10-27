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
