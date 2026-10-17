--------------------------------------------------------------------------------
-- 18d Workflow platform - seed (release R12)
--   Release 87: the pages of the workflow screens and the task deadlines are registered in COMMON by 18h; this
--   script only records the release.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.mark_release('R12', 'Release 12: native APEX workflow platform (tasks, My Tasks, monitor, setup)');
    commit;
end;
/
