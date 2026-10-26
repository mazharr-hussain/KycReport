--------------------------------------------------------------------------------
-- 16z step 3 (release 105): the existing requests get their stage. The request is the parent of its case and
-- follows it: Investigation = Under Review, Pending Approval = In Approval, Pending Information = Information
-- Needed, Approved / Rejected / Cancelled the same. A request without a case: In Progress = Submitted; Approved
-- without a case (KYC not required or auto-approved) = KYC Not Required.
-- Idempotent: only In Progress requests and Approved requests whose case is still open or that have no case change.
--------------------------------------------------------------------------------
begin
    update xxcmp_requests r
       set r.request_status = (select case c.case_status when 'INVESTIGATION'       then 'UNDER_REVIEW'
                                                         when 'PENDING_APPROVAL'    then 'IN_APPROVAL'
                                                         when 'PENDING_INFORMATION' then 'INFO_NEEDED'
                                                         else c.case_status end
                                 from xxcmp_cases c
                                where c.case_id = (select max(c2.case_id) from xxcmp_cases c2 where c2.request_id = r.request_id))
     where r.request_status in ('IN_PROGRESS', 'APPROVED')
       and exists (select 1 from xxcmp_cases c where c.request_id = r.request_id
                      and c.case_status in ('INVESTIGATION', 'PENDING_APPROVAL', 'PENDING_INFORMATION', 'APPROVED',
                                            'REJECTED', 'CANCELLED'));
    update xxcmp_requests r set r.request_status = 'SUBMITTED'
     where r.request_status = 'IN_PROGRESS'
       and not exists (select 1 from xxcmp_cases c where c.request_id = r.request_id);
    update xxcmp_requests r set r.request_status = 'NOT_REQUIRED'
     where r.request_status = 'APPROVED'
       and not exists (select 1 from xxcmp_cases c where c.request_id = r.request_id);
    commit;
end;
/
