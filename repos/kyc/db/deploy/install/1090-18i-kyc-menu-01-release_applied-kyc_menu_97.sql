--------------------------------------------------------------------------------
-- 18i KYC menu in COMMON (release 97). KYC only (XXCUS), after 18h.
--   KYC's navigation menu is kept in COMMON (Application Menu, XXFND_APP_MENU_ENTRIES) and shown through COMMON's
--   navigation list, which KYC subscribes to - in KYC and on COMMON's shared pages used from KYC (My Tasks,
--   Notifications, ...), so the menu does not change. Who sees an entry: the privilege of its page (View), as on the
--   page itself; Administration: an administrator of anything.
--   - The entries are registered through COMMON's routine (REGISTER_MENU_ENTRY adds only missing entries: what an
--     administrator changed on the Application Menu screen is kept).
--   - Once (release KYC_MENU_97): COMMON's default entries that KYC shows elsewhere (Notifications and Feedback in
--     the navigation bar, the shared setup on the Administration page) are hidden through SAVE_MENU_ENTRY; an
--     administrator may show them again.
-- Idempotent.
--------------------------------------------------------------------------------
declare
    c_app constant varchar2(30) := 'KYC';

    procedure entry(p_code in varchar2, p_label in varchar2, p_type in varchar2, p_page in number, p_icon in varchar2,
                    p_seq in number) is
    begin
        xxfnd_application_pkg.register_menu_entry(c_app, p_code, p_label, p_type, p_page, null, p_icon, p_seq);
    end entry;
begin
    entry('HOME',           'Home',                 'APP_PAGE',   1,   'fa-home',         1);
    -- My Tasks (COMMON page 40, order 10) is COMMON's default entry of every application
    entry('KYC_REQUESTS',   'KYC Requests',         'APP_PAGE',   200, 'fa-file-text-o',  25);
    entry('PARTIES',        'Parties',              'APP_PAGE',   20,  'fa-building-o',   30);
    entry('CASES',          'Cases',                'APP_PAGE',   210, 'fa-briefcase',    35);
    entry('MONITORING',     'Monitoring Watchlist', 'APP_PAGE',   220, 'fa-eye',          40);
    entry('DASHBOARD',      'Executive Dashboard',  'APP_PAGE',   230, 'fa-area-chart',   50);
    entry('ADMINISTRATION', 'Administration',       'ADMIN_PAGE', 100, 'fa-gear',         90);

    if not xxfnd_ddl_pkg.release_applied('KYC_MENU_97') then
        for e in (select entry_code from xxfnd_app_menu_entries
                   where application_code = c_app and made_by = 'COMMON' and entry_code <> 'MY_TASKS'
                     and enabled_flag = 'Y') loop
            xxfnd_application_pkg.save_menu_entry(c_app, e.entry_code, null, null, null, 'N');
        end loop;
        xxfnd_ddl_pkg.mark_release('KYC_MENU_97', 'KYC menu in COMMON: COMMON''s default entries shown elsewhere hidden once');
    end if;
    commit;
end;
/
