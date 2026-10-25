--------------------------------------------------------------------------------
-- XXFND_FI_META_PKG (release 107, Fusion Objects). COMMON only (XXFUSION).
--   The metadata harvester: reads Fusion metadata live from the pod through the one Fusion server and credential
--   (integration purpose FUSION_OBJECTS -> REST Data Source FUSION_ROOT, XXFND_INTEGRATION_PKG.CALL):
--   - BICC Meta Data REST API (/biacm/rest/meta): offerings, their datastores (VOs), the columns of a datastore with
--     the customizations (includeCustomization=true);
--   - Fusion REST: describe of a resource (attributes, children); the resources of an API root (its describe).
--   The BICC paths are the constants below (one place to adjust to the pod's BICC version); the JSON is read by the
--   keys BICC and Fusion REST use, with the alternative spellings of older versions.
--------------------------------------------------------------------------------
create or replace package xxfnd_fi_meta_pkg authid definer as
    c_purpose     constant varchar2(30)  := 'FUSION_OBJECTS';
    c_bicc_root   constant varchar2(100) := 'biacm/rest/meta';
    c_rest_root   constant varchar2(100) := 'hcmRestApi/resources/11.13.18.05';

    -- One attribute of the live metadata of an object.
    type t_attr is record (
        attribute_name   varchar2(400),
        data_type        varchar2(60),
        data_length      number,
        data_scale       number,
        pk_flag          varchar2(1),
        custom_flag      varchar2(1),
        last_update_flag varchar2(1),
        display_sequence number);
    type t_attrs is table of t_attr index by pls_integer;
    -- One child resource of a REST object.
    type t_child is record (child_name varchar2(400), child_path varchar2(1000));
    type t_children is table of t_child index by pls_integer;

    -- GET / send through the Fusion server (purpose FUSION_OBJECTS); JSON body with Content-Type application/json.
    function fusion_get(p_path in varchar2, p_query in varchar2 default null) return clob;
    function fusion_send(p_method in varchar2, p_path in varchar2, p_body in clob) return clob;

    -- Harvests every BICC offering and its datastores into XXFND_FI_CATALOG (P_OFFERING: one offering only).
    -- Returns the number of datastores read. ORA-20361 when the credential has no BICC access.
    function harvest_bicc(p_offering in varchar2 default null) return number;
    -- Harvests the resources of a Fusion REST API root (its describe) into XXFND_FI_CATALOG; returns their number.
    function harvest_rest(p_api_root in varchar2 default c_rest_root) return number;
    -- Adds one REST resource by its path under the Fusion server (e.g. hcmRestApi/resources/11.13.18.05/workers)
    -- after reading its describe; returns its catalog ID.
    function add_rest_resource(p_path in varchar2) return number;

    -- The live attributes of a catalog source (BICC datastore columns with customizations, or REST describe).
    function live_attributes(p_source_type in varchar2, p_source_name in varchar2) return t_attrs;
    -- The child resources of a REST resource (describe).
    function live_children(p_source_name in varchar2) return t_children;
end xxfnd_fi_meta_pkg;
/
