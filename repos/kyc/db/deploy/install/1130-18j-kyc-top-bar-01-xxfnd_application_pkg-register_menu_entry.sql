--------------------------------------------------------------------------------
-- 18j KYC navigation bar in COMMON (release 98). KYC only (XXCUS), after 18i.
--   KYC's navigation bar (top bar) is kept in COMMON's menu registry like its side menu (menu TOP_BAR, COMMON 105) and
--   shown through COMMON's Navigation Bar list, which KYC subscribes to: Feedback (COMMON page 173 on the current
--   page), the user menu with About, a separator and Sign Out. Registered through COMMON's routine (only missing
--   entries: what an administrator changed on the Application Menu screen is kept).
-- Idempotent.
--------------------------------------------------------------------------------
declare
    c_app constant varchar2(30) := 'KYC';

    procedure entry(p_code in varchar2, p_label in varchar2, p_type in varchar2, p_page in number, p_icon in varchar2,
                    p_seq in number, p_parent in varchar2 default null) is
    begin
        xxfnd_application_pkg.register_menu_entry(c_app, p_code, p_label, p_type, p_page, null, p_icon, p_seq,
                                                  p_parent, 'TOP_BAR');
    end entry;
begin
    entry('TB_FEEDBACK', 'Feedback',  'COMMON_PAGE', 173,   'fa-comment-o', 5);
    entry('TB_USER',     'User',      'USER_MENU',   null,  'fa-user',      10);
    entry('TB_ABOUT',    'About',     'APP_PAGE',    10010, null,           18, 'TB_USER');
    entry('TB_USER_SEP', '---',       'SEPARATOR',   null,  null,           20, 'TB_USER');
    entry('TB_SIGN_OUT', 'Sign Out',  'SIGN_OUT',    null,  'fa-sign-out',  30, 'TB_USER');
    commit;
end;
/
