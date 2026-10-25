
-- release 73: the beneficial owner is marked on the owner / officer relationship (Owners and Officers), with its basis
begin
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_RELATIONSHIPS', 'BENEFICIAL_OWNER_FLAG', q'~varchar2(1) default 'N' not null~');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_RELATIONSHIPS', 'UBO_BASIS', 'varchar2(30)');
    xxfnd_ddl_pkg.add_column('XXCMP_PARTY_RELATIONSHIPS', 'UBO_NOTES', 'varchar2(4000)');
    xxfnd_ddl_pkg.add_constraint('XXCMP_PARTY_RELATIONSHIPS', 'XXCMP_PARTY_REL_CK6',
        q'~check (beneficial_owner_flag in ('Y','N'))~');
    -- a beneficial owner needs its basis (CK7 let an empty basis through: NULL passes a check, replaced by CK8)
    xxfnd_ddl_pkg.drop_constraint('XXCMP_PARTY_RELATIONSHIPS', 'XXCMP_PARTY_REL_CK7');
    xxfnd_ddl_pkg.add_constraint('XXCMP_PARTY_RELATIONSHIPS', 'XXCMP_PARTY_REL_CK8',
        q'~check (beneficial_owner_flag = 'N' or (ubo_basis is not null and ubo_basis in ('OWNERSHIP','CONTROL','FALLBACK')))~');
    -- release 92: the one-time copy of the beneficial owners from XXCMP_UBO_DETERMINATIONS (release 73) is gone: every
    -- supported database (release 74 or later) has it, and the table is retired
end;
/
comment on column xxcmp_party_relationships.beneficial_owner_flag is 'Y = the related (subject) party is a beneficial owner of the object party (release 73).';
comment on column xxcmp_party_relationships.ubo_basis is 'Why the subject party is a beneficial owner (lookup UBO_BASIS); required when BENEFICIAL_OWNER_FLAG = Y.';
