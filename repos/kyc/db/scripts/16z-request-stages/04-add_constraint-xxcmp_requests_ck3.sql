--------------------------------------------------------------------------------
-- 16z step 4 (release 105): the request status check with the stages - Draft, Submitted, Under Review, In
-- Approval, Approved; Information Needed, KYC Not Required, Rejected, Cancelled.
-- Idempotent: added only when missing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_constraint('XXCMP_REQUESTS', 'XXCMP_REQUESTS_CK3',
        q'~check (request_status in ('DRAFT','SUBMITTED','UNDER_REVIEW','IN_APPROVAL','INFO_NEEDED','APPROVED','NOT_REQUIRED','REJECTED','CANCELLED'))~');
end;
/
