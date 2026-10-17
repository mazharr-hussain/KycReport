
-- release 86: COMMON no longer registers any business application here (it used to add the KYC row). Each
-- application is onboarded by IT (Applications, or apex/db/admin/onboard-application.sql: XXFND_APPLICATION_PKG.ONBOARD);
-- a row that exists already is kept as it is.

-- existing roles belong to the application of their code
update xxfnd_roles r
   set r.application_id = (select a.application_id from xxfnd_applications a where a.application_code = r.application_code)
 where r.application_id is null
   and exists (select 1 from xxfnd_applications a where a.application_code = r.application_code);
