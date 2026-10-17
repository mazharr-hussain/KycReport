-- Release 81 checks (run as XXFUSION): C4 Documents and Records - the store transport merged into XXFND_ATTACH_PKG
-- (XXFND_ATTACH_STORE_PKG dropped), page 131 saves through the package, XXFND_RETENTION_PKG is a placeholder that
-- changes nothing. Changes are rolled back.
set serveroutput on feedback off
declare
    l_n     number;
    l_n2    number;
    l_id    number;
    l_v     varchar2(4000);
    l_ent   varchar2(100);
    l_cat   varchar2(100);
    l_cfg   xxfnd_storage_config%rowtype;
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    -- the store package is gone, its code is private in XXFND_ATTACH_PKG; nothing invalid
    select count(*) into l_n from user_objects where object_name = 'XXFND_ATTACH_STORE_PKG';
    check_(l_n = 0, 'XXFND_ATTACH_STORE_PKG dropped');
    select count(*) into l_n from xxfnd_dropped_objects where object_name = 'XXFND_ATTACH_STORE_PKG';
    -- an upgraded database (it also dropped the release 79/80 packages) records it; a fresh install never had it
    select count(*) into l_n2 from xxfnd_dropped_objects where object_name in ('XXFND_SECURITY_PKG', 'XXFND_SETUP_TYPE_PKG');
    check_((l_n2 > 0 and l_n >= 1) or (l_n2 = 0 and l_n = 0), 'its DDL is recorded in XXFND_DROPPED_OBJECTS when it existed (' || l_n || ')');
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from user_procedures
     where object_name = 'XXFND_ATTACH_PKG' and procedure_name in ('UPLOAD', 'FETCH_FILE', 'DATABASE_CONFIG');
    check_(l_n = 0, 'store transport is private (not in the XXFND_ATTACH_PKG spec)');

    -- the attachment package works after the merge
    l_cfg := xxfnd_attach_pkg.resolve_storage('XXFND_R81_NO_ENTITY', null);
    check_(l_cfg.storage_type = 'DATABASE', 'no storage row: files are kept in the database');
    select min(entity_name) into l_ent from xxfnd_document_entities;
    -- a category that needs no issue or expiry date (a text attachment has no dates)
    select min(category_code) into l_cat from xxfnd_document_categories
     where max_age_days is null and nvl(has_expiry_flag, 'N') = 'N';
    if l_ent is not null and l_cat is not null then
        l_id := xxfnd_attach_pkg.add_text(l_ent, 'R81-TEST', l_cat, 'SHORT_TEXT', 'R81 note', 'release 81 test');
        select count(*) into l_n from xxfnd_attached_documents where attached_document_id = l_id;
        check_(l_n = 1, 'a text attachment is added');
        xxfnd_attach_pkg.copy_attachments(l_ent, 'R81-TEST', l_ent, 'R81-COPY');
        select count(*) into l_n from xxfnd_attached_documents where entity_name = l_ent and pk1_value = 'R81-COPY';
        check_(l_n = 1, 'attachments are copied to another record');
        xxfnd_attach_pkg.remove(l_id);
        select count(*) into l_n from xxfnd_attached_documents where attached_document_id = l_id;
        check_(l_n = 1, 'remove is a soft delete: the row stays');

        -- page 131: the display name saved by the package
        xxfnd_attach_pkg.save_entity_display_name(l_ent, 'R81 display name');
        select max(user_entity_name) into l_v from xxfnd_document_entities_tl
         where entity_name = l_ent and language_code = 'en';
        check_(l_v = 'R81 display name', 'entity display name saved by XXFND_ATTACH_PKG');
    else
        check_(false, 'a document entity and category exist for the attachment checks');
    end if;

    -- retention: a placeholder that flags, archives and deletes nothing
    check_(xxfnd_retention_pkg.is_active = 'N', 'retention is not active');
    check_(xxfnd_retention_pkg.policy_for('XXFND_ATTACHED_DOCUMENTS') is null, 'no retention policy applies');
    select count(*) into l_n from xxfnd_attached_documents;
    xxfnd_retention_pkg.run;
    select count(*) into l_n2 from xxfnd_attached_documents;
    check_(l_n = l_n2, 'the retention run changes nothing');
    rollback;
end;
/
