--------------------------------------------------------------------------------
-- 05c step 01 (release 123, I-010): the colour (tone) of a lookup value shown as a status badge - set by the
-- application that registers the value, read by XXFND_LOOKUP_PKG.LOOKUP_TONE (no status codes held in COMMON).
-- Before the package: its routines read the column. Idempotent: the column and its check are added only when missing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_LOOKUP_VALUES', 'TONE', 'varchar2(10)');
    xxfnd_ddl_pkg.add_constraint('XXFND_LOOKUP_VALUES', 'XXFND_LOOKUP_VALUES_CK3',
        q'~check (tone in ('success','warning','danger','info','neutral'))~');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_lookup_values.tone is 'Release 123: the badge colour of the value as a status - success, warning, danger, info or neutral (null = neutral).'~');
end;
/
