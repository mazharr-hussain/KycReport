
-- release 74: the messages the party, request and case components raise (message catalogue, COMMON 09f); a text
-- Compliance changed is kept
begin
    xxfnd_error_pkg.register_message('KYC_PARTY_CREATE_NOT_ALLOWED', 'You are not allowed to create parties.', -20701);
    xxfnd_error_pkg.register_message('KYC_PARTY_CHANGE_NOT_ALLOWED', 'You are not allowed to change parties.', -20706);
    xxfnd_error_pkg.register_message('KYC_PARTY_DISABLED', 'A disabled or merged party cannot be changed.', -20707);
    xxfnd_error_pkg.register_message('KYC_PARTY_THIS_NOT_ALLOWED', 'You are not allowed to change this party.', -20706);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_NOT_ALLOWED', 'Only Compliance can merge parties.', -20711);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_TARGET', 'Choose another party to merge into.', -20712);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_TYPE', 'An organisation cannot be merged into an individual, or the reverse.', -20713);
    xxfnd_error_pkg.register_message('KYC_PARTY_MERGE_DISABLED', 'Both parties must be enabled.', -20714);
    xxfnd_error_pkg.register_message('KYC_REQUEST_LOCKED', 'Request {1} can no longer be changed.', -20612);
    xxfnd_error_pkg.register_message('KYC_REQUEST_PARTY_FIXED', 'The counterparty of a submitted request cannot be replaced.', -20617);
    xxfnd_error_pkg.register_message('KYC_REQUEST_PARTY_APPROVED', 'The party of this request has been approved: Compliance maintains it.', -20618);
    xxfnd_error_pkg.register_message('KYC_REQUEST_ANSWERS_LOCKED', 'The request has been submitted; its answers can no longer be changed.', -20613);
    xxfnd_error_pkg.register_message('KYC_REQUEST_QUESTION_UNKNOWN', 'Question {1} does not belong to this request.', -20614);
    xxfnd_error_pkg.register_message('KYC_REQUEST_OPTION_UNKNOWN', 'Answer {1} is not an option of question {2}.', -20615);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NUMBER_EXPECTED', 'Enter a number for: {1}', -20616);
    xxfnd_error_pkg.register_message('KYC_REQUEST_INFO_TEXT', 'Enter the information you need from the requester.', -20625);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NOT_IN_APPROVAL', 'Request {1} is not waiting for approval.', -20625);
    xxfnd_error_pkg.register_message('KYC_REQUEST_NOT_APPROVER', 'You are not an approver of request {1}.', -20625);
    -- release 76: requesting departments from data security
    xxfnd_error_pkg.register_message('KYC_REQUEST_NO_DEPARTMENT', 'No requesting department is set up for you. Ask the administrator to give you a Requesting Entity role.', -20626);
    -- release 95 (COMMON 96 security model): the department comes with the requesting entity role (its Data Access Values)
    xxfnd_error_pkg.register_message('KYC_REQUEST_NO_ENTITY', 'You may not raise requests for any department yet. Ask the administrator to give you a requesting entity role (e.g. Requesting Entity1) with your department in its data access values.', -20626);
    xxfnd_error_pkg.register_message('KYC_REQUEST_DEPT_NOT_ALLOWED', 'You cannot raise requests for {1}. Choose one of your departments.', -20626);
    xxfnd_error_pkg.register_message('KYC_CASE_REASSIGN_NOT_ALLOWED', 'Only a case under investigation can be reassigned, by Compliance management or its assignee.', -20611);
    xxfnd_error_pkg.register_message('KYC_CASE_OFFICER_REQUIRED', 'Select the officer.', -20611);
    -- release 75: the officer chosen for a case must be an active Compliance officer, manager or head of Compliance
    xxfnd_error_pkg.register_message('KYC_CASE_OFFICER_INVALID', 'Choose an active Compliance officer, manager or head of Compliance.', -20619);
    xxfnd_error_pkg.register_message('KYC_CASE_WITHDRAW_NOT_ALLOWED', 'Only a case waiting for approval can be withdrawn, by its officer or Compliance management.', -20615);
    xxfnd_error_pkg.register_message('KYC_CASE_WITHDRAW_REASON', 'Enter the reason for withdrawing the case from approval.', -20615);
    xxfnd_error_pkg.register_message('KYC_CASE_NO_MATRIX_ROW', 'The approval matrix has no row for risk tier {1}.', -20612);
    xxfnd_error_pkg.register_message('KYC_CASE_CONTACT_NO_EMAIL', 'The contact person has no e-mail address: add one before sending the request.', -20509);
    xxfnd_error_pkg.register_message('KYC_CASE_FIU_FILING', 'Enter the goAML reference and the date the report was filed.', -20616);
    xxfnd_error_pkg.register_message('KYC_CASE_FUNDS_EVIDENCE', 'Record the evidence seen before marking the source as verified.', -20617);
    commit;
end;
/
