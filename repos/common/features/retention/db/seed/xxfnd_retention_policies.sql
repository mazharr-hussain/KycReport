-- release 77: no retention policy is seeded (the business keeps every record); the release 76 seed is taken back
-- when nobody changed it since
delete from xxfnd_retention_policies
 where table_name = 'XXFND_ERROR_LOG' and jurisdiction is null and retention_years = 1
   and action_at_expiry = 'FLAG_FOR_REVIEW' and object_version_number = 1;
commit;
