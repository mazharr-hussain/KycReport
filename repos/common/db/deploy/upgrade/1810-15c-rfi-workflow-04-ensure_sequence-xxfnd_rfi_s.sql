declare
    l_n pls_integer;
begin

    xxfnd_ddl_pkg.ensure_sequence('XXFND_RFI_S', 'create sequence xxfnd_rfi_s');
    xxfnd_ddl_pkg.ensure_sequence('XXFND_RFI_NUMBER_S', 'create sequence xxfnd_rfi_number_s');


    -- data security: the Common administrators' rule is seeded by XXFND_SHARE_PKG.SEED_COMMON (19c, run by 20, after the role); applications add theirs (KYC: 18e)
end;
/
