--------------------------------------------------------------------------------
-- 30 Application journey (release 86, part C). COMMON only (XXFUSION), after 29.
--   Applications are registered and maintained through one guided journey:
--   - page 165 Application Journey (create = register, edit = any step): Universal Theme wizard, steps Application,
--     Roles, Users, Shared functions, Setup types, Processes, Notifications, Document storage, Integrations, Review;
--   - page 166 Application (review): header card with the actions (Edit, Disable / Enable, Delete) and one section per
--     journey step; the sections are Global Page regions shared by 165 and 166.
--   Both pages belong to the feature APPLICATIONS (View for 166, Create for the journey on create, Manage for the
--   edit, disable and delete). Page 161 (the old Application form) is removed from the application; its
--   XXFND_FEATURE_PAGES row is left as it is (no data is deleted): a feature page that the application does not have
--   is never shown (menus, tabs and module lists join APEX_APPLICATION_PAGES) and grants nothing.
-- Idempotent: rows are added only when missing; a re-run changes nothing.
--------------------------------------------------------------------------------
declare
    procedure page(p_feature in varchar2, p_page in number) is
    begin
        -- the page belongs to the feature (its privileges decide who may open it), added when missing
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p_page page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code) values ('COMMON', p_page, p_feature);
    end page;
begin
    xxfnd_util_pkg.set_install_mode(true);
    page('APPLICATIONS', 165);   -- Application Journey (create and edit)
    page('APPLICATIONS', 166);   -- Application (review)
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
