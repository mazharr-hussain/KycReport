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

create or replace package body xxfnd_fi_meta_pkg as

    -- the first of the keys (comma-separated) the object has, as text
    function str(p_obj in json_object_t, p_keys in varchar2) return varchar2 is
    begin
        for k in (select column_value key from table(apex_string.split(p_keys, ','))) loop
            if p_obj.has(k.key) and not p_obj.get(k.key).is_null then
                return case when p_obj.get(k.key).is_string then p_obj.get_string(k.key)
                            else p_obj.get(k.key).to_string end;
            end if;
        end loop;
        return null;
    end str;

    function yn(p_obj in json_object_t, p_keys in varchar2) return varchar2 is
        l_v varchar2(100) := lower(str(p_obj, p_keys));
    begin
        return case when l_v in ('true', 'y', 'yes', '1') then 'Y' else 'N' end;
    end yn;

    -- the array of a response: the response itself, or its items / list member
    function items(p_json in clob, p_keys in varchar2 default 'items,dataStores,offerings,columns,datastoreColumns') return json_array_t is
        l_el  json_element_t := json_element_t.parse(p_json);
        l_obj json_object_t;
    begin
        if l_el.is_array then
            return treat(l_el as json_array_t);
        end if;
        l_obj := treat(l_el as json_object_t);
        for k in (select column_value key from table(apex_string.split(p_keys, ','))) loop
            if l_obj.has(k.key) and l_obj.get(k.key).is_array then
                return l_obj.get_array(k.key);
            end if;
        end loop;
        return json_array_t();
    end items;

    function fusion_get(p_path in varchar2, p_query in varchar2 default null) return clob is
    begin
        apex_web_service.clear_request_headers;
        return xxfnd_integration_pkg.call(c_purpose, 'GET', p_path, p_query);
    exception
        when others then
            if sqlcode = -20311 and ltrim(p_path, '/') like c_bicc_root || '%'
               and apex_web_service.g_status_code in (401, 403) then
                xxfnd_error_pkg.raise_error('XXFND_FI_NO_BICC', apex_t_varchar2(apex_web_service.g_status_code));
            end if;
            raise;
    end fusion_get;

    function fusion_send(p_method in varchar2, p_path in varchar2, p_body in clob) return clob is
        l_resp clob;
    begin
        apex_web_service.clear_request_headers;
        apex_web_service.set_request_headers('Content-Type', 'application/json');
        l_resp := xxfnd_integration_pkg.call(c_purpose, upper(p_method), p_path, null, p_body);
        apex_web_service.clear_request_headers;
        return l_resp;
    exception
        when others then
            apex_web_service.clear_request_headers;
            raise;
    end fusion_send;

    procedure upsert_catalog(p_type in varchar2, p_name in varchar2, p_offering in varchar2, p_offering_name in varchar2,
                             p_business_name in varchar2, p_description in varchar2) is
    begin
        merge into xxfnd_fi_catalog t
        using (select p_type source_type, p_name source_name from dual) s
           on (t.source_type = s.source_type and t.source_name = s.source_name)
         when matched then update set t.offering_code = p_offering, t.offering_name = p_offering_name,
                                      t.business_name = nvl(p_business_name, t.business_name),
                                      t.description = substr(p_description, 1, 4000), t.harvested_date = systimestamp
         when not matched then insert (source_type, source_name, offering_code, offering_name, business_name, description)
                               values (s.source_type, s.source_name, p_offering, p_offering_name,
                                       nvl(p_business_name, p_name), substr(p_description, 1, 4000));
    end upsert_catalog;

    function harvest_bicc(p_offering in varchar2 default null) return number is
        l_offerings json_array_t;
        l_stores    json_array_t;
        l_off       json_object_t;
        l_ds        json_object_t;
        l_code      varchar2(200);
        l_name      varchar2(400);
        l_n         pls_integer := 0;
    begin
        l_offerings := items(fusion_get(c_bicc_root || '/offerings'));
        for i in 0 .. l_offerings.get_size - 1 loop
            l_off  := treat(l_offerings.get(i) as json_object_t);
            l_code := str(l_off, 'id,offeringId,offeringCode,code');
            l_name := str(l_off, 'name,offeringName,displayName');
            if l_code is not null and (p_offering is null or upper(l_code) = upper(p_offering)) then
                l_stores := items(fusion_get(c_bicc_root || '/offerings/' || utl_url.escape(l_code, true) || '/dataStores'));
                for j in 0 .. l_stores.get_size - 1 loop
                    l_ds := treat(l_stores.get(j) as json_object_t);
                    if str(l_ds, 'dataStoreId,id,dataStoreName,name') is not null then
                        upsert_catalog('BICC', str(l_ds, 'dataStoreId,id,dataStoreName,name'), l_code, l_name,
                                       str(l_ds, 'displayName,dataStoreDisplayName,name,dataStoreId'),
                                       str(l_ds, 'description,dataStoreDescription'));
                        l_n := l_n + 1;
                    end if;
                end loop;
            end if;
        end loop;
        commit;
        return l_n;
    end harvest_bicc;

    function harvest_rest(p_api_root in varchar2 default c_rest_root) return number is
        l_root json_object_t;
        l_res  json_object_t;
        l_one  json_object_t;
        l_keys json_key_list;
        l_n    pls_integer := 0;
    begin
        -- describe of the API root: {"Resources": {"<name>": {"titles": {...}, ...}, ...}}
        l_root := json_object_t.parse(fusion_get(rtrim(p_api_root, '/') || '/describe'));
        if not l_root.has('Resources') then
            return 0;
        end if;
        l_res  := l_root.get_object('Resources');
        l_keys := l_res.get_keys;
        for i in 1 .. l_keys.count loop
            l_one := l_res.get_object(l_keys(i));
            upsert_catalog('REST', rtrim(p_api_root, '/') || '/' || l_keys(i), p_api_root, p_api_root,
                           case when l_one.has('titles') then str(l_one.get_object('titles'), 'plural,singular') end,
                           case when l_one.has('titles') then str(l_one.get_object('titles'), 'singular') end);
            l_n := l_n + 1;
        end loop;
        commit;
        return l_n;
    end harvest_rest;

    -- the describe of one resource: {"Resources": {"<name>": {"attributes": [...], "children": {...}}}}
    function describe_one(p_path in varchar2) return json_object_t is
        l_root json_object_t := json_object_t.parse(fusion_get(rtrim(p_path, '/') || '/describe'));
        l_res  json_object_t;
        l_keys json_key_list;
    begin
        if not l_root.has('Resources') then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_METADATA', apex_t_varchar2(p_path));
        end if;
        l_res  := l_root.get_object('Resources');
        l_keys := l_res.get_keys;
        if l_keys.count = 0 then
            xxfnd_error_pkg.raise_error('XXFND_FI_NO_METADATA', apex_t_varchar2(p_path));
        end if;
        return l_res.get_object(l_keys(1));
    end describe_one;

    function add_rest_resource(p_path in varchar2) return number is
        l_path varchar2(1000) := trim(both '/' from p_path);
        l_one  json_object_t  := describe_one(l_path);
        l_id   number;
    begin
        upsert_catalog('REST', l_path, regexp_substr(l_path, '^(.*)/[^/]+$', 1, 1, null, 1),
                       regexp_substr(l_path, '^(.*)/[^/]+$', 1, 1, null, 1),
                       case when l_one.has('titles') then str(l_one.get_object('titles'), 'plural,singular') end,
                       case when l_one.has('titles') then str(l_one.get_object('titles'), 'singular') end);
        select catalog_id into l_id from xxfnd_fi_catalog where source_type = 'REST' and source_name = l_path;
        commit;
        return l_id;
    end add_rest_resource;

    function live_attributes(p_source_type in varchar2, p_source_name in varchar2) return t_attrs is
        l_out  t_attrs;
        l_arr  json_array_t;
        l_one  json_object_t;
        l_col  json_object_t;
        l_type varchar2(60);
    begin
        if upper(p_source_type) = 'BICC' then
            l_arr := items(fusion_get(c_bicc_root || '/datastores/' || utl_url.escape(p_source_name, true),
                                      'includeCustomization=true'));
        else
            l_one := describe_one(p_source_name);
            l_arr := case when l_one.has('attributes') then l_one.get_array('attributes') else json_array_t() end;
        end if;
        for i in 0 .. l_arr.get_size - 1 loop
            l_col  := treat(l_arr.get(i) as json_object_t);
            l_type := upper(str(l_col, 'dataType,type,columnType'));
            l_out(i + 1).attribute_name   := str(l_col, 'name,columnName,attributeName');
            l_out(i + 1).data_type        := nvl(l_type, 'VARCHAR');
            l_out(i + 1).data_length      := to_number(str(l_col, 'size,length,maxLength,precision,columnLength')
                                                       default null on conversion error);
            l_out(i + 1).data_scale       := to_number(str(l_col, 'scale,columnScale') default null on conversion error);
            l_out(i + 1).pk_flag          := yn(l_col, 'isPrimaryKey,primaryKey,isKey');
            l_out(i + 1).custom_flag      := yn(l_col, 'isCustomization,isCustom,customization');
            l_out(i + 1).last_update_flag := yn(l_col, 'isLastUpdateDate,lastUpdateDate');
            l_out(i + 1).display_sequence := i + 1;
        end loop;
        return l_out;
    end live_attributes;

    function live_children(p_source_name in varchar2) return t_children is
        l_out  t_children;
        l_one  json_object_t := describe_one(p_source_name);
        l_ch   json_object_t;
        l_keys json_key_list;
    begin
        if not l_one.has('children') then
            return l_out;
        end if;
        l_ch   := l_one.get_object('children');
        l_keys := l_ch.get_keys;
        for i in 1 .. l_keys.count loop
            l_out(i).child_name := l_keys(i);
            -- a child is reached under a parent row: <resource>/{id}/child/<name>
            l_out(i).child_path := rtrim(p_source_name, '/') || '/{id}/child/' || l_keys(i);
        end loop;
        return l_out;
    end live_children;

end xxfnd_fi_meta_pkg;
/
