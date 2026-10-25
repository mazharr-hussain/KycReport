
-- release 74: the former XXCMP_KYC_PKG (document rules now XXCMP_DOC_RULE_PKG; party matching in XXCMP_PARTY_PKG;
-- RFIs in COMMON) is dropped when it is still there
begin
    for o in (select object_name from user_objects where object_name = 'XXCMP_KYC_PKG' and object_type = 'PACKAGE') loop
        execute immediate 'drop package xxcmp_kyc_pkg';
    end loop;
end;
/
