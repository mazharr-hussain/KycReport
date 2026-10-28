--------------------------------------------------------------------------------
-- 41d COMMON 113: the Process page (154) and the Approval Group dialog (155) are pages of the feature APPROVAL_SETUP
-- (its View / Create / Manage privileges open them). Re-runnable: only what is missing is added.
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'APPROVAL_SETUP', 154);
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'APPROVAL_SETUP', 155);
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
