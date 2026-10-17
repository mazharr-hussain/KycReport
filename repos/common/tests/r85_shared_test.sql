-- Release 85 checks (run as XXFUSION): the shared screens of COMMON - Documents (47 Attachments, 48 Document) for
-- any application's record, Platform Activity (170) and Feedback (171-173) for every application.
-- Its rows stay (a communication "R85 document test" with a text document; a feedback and its follow-up).
set serveroutput on feedback off
declare
    l_n     number;
    l_n2    number;
    l_app   number;
    l_comm  number;
    l_doc   number;
    l_att   number;
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
    procedure expect_error(p_code in number, p_text in varchar2, p_block in varchar2) is
    begin
        execute immediate p_block;
        check_(false, p_text || ' (no error)');
    exception
        when others then
            check_(sqlcode = p_code, p_text || ' (' || sqlcode || ')');
    end expect_error;
    procedure session_as(p_user in varchar2) is
    begin
        apex_session.create_session(p_app_id => l_app, p_page_id => 1, p_username => p_user);
    end session_as;
begin
    apex_util.set_workspace('XXCUS');
    select max(apex_application_id) into l_app from xxfnd_applications where application_code = 'COMMON';

    ---------------------------------------------------------------- screens, features and privileges
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from apex_application_pages where application_id = l_app and page_id in (47, 48, 170, 171, 172, 173);
    check_(l_n = 6, 'the six shared screens are in COMMON (' || l_n || ')');
    select count(*) into l_n from xxfnd_feature_pages
     where app_alias = 'COMMON' and (feature_code, page_id) in
           (('DOCUMENTS', 47), ('DOCUMENTS', 48), ('PLATFORM_ACTIVITY', 170), ('USAGE_FEEDBACK', 171),
            ('USAGE_FEEDBACK', 172), ('GIVE_FEEDBACK', 173));
    check_(l_n = 6, 'each screen belongs to its feature (' || l_n || ')');
    select count(*) into l_n from xxfnd_features f
     where f.feature_code in ('DOCUMENTS', 'PLATFORM_ACTIVITY', 'USAGE_FEEDBACK', 'GIVE_FEEDBACK')
       and (select count(*) from xxfnd_privileges p where p.feature_code = f.feature_code) >= 2;
    check_(l_n = 4, 'every screen has at least two privileges');
    select count(*) into l_n from apex_application_pages
     where application_id = l_app and page_id in (47, 173) and page_access_protection like 'Unrestricted%';
    check_(l_n = 2, 'Attachments and Give Feedback can be opened by any application (unrestricted arguments)');

    ---------------------------------------------------------------- documents of any record: who may see, who may change
    session_as('ADMIN');
    l_comm := xxfnd_notify_pkg.record_received(p_application_code => 'COMMON', p_entity_name => 'R85_TEST',
                                               p_pk1_value => to_char(sysdate, 'YYYYMMDDHH24MISS'),
                                               p_from => 'someone.r85@example.com', p_subject => 'R85 document test',
                                               p_body => 'A communication that keeps a document (release 85 test).');
    l_att := xxfnd_attach_pkg.add_text(p_entity_name => 'XXFND_COMMUNICATIONS', p_pk1_value => to_char(l_comm),
                                       p_category_code => 'OTHER', p_datatype_code => 'SHORT_TEXT',
                                       p_title => 'R85 note', p_text => 'A short text document.');
    select document_id into l_doc from xxfnd_attached_documents where attached_document_id = l_att;
    commit;
    check_(xxfnd_attach_pkg.record_visible('XXFND_COMMUNICATIONS', to_char(l_comm)) = 'Y',
           'a record the user may see is available (data security of its table)');
    check_(xxfnd_attach_pkg.record_visible('NO_SUCH_ENTITY', '1') = 'N', 'an unregistered entity is not');
    check_(xxfnd_attach_pkg.record_visible('XXFND_COMMUNICATIONS', '-1') = 'N', 'a record that does not exist is not');
    expect_error(-20317, 'a visible record''s document passes the check (a text is not a file)',
                 'begin xxfnd_attach_pkg.download_checked(' || l_doc || '); end;');
    expect_error(-20332, 'a page without an attachment registration may not add documents',
                 q'~begin xxfnd_attach_pkg.assert_change('COMMON', 47, 'documents', 'XXFND_COMMUNICATIONS', '~'
                 || l_comm || q'~', 'INSERT'); end;~');
    expect_error(-20332, 'a document of another record may not be changed through this record',
                 q'~begin xxfnd_attach_pkg.assert_change('COMMON', 47, 'documents', 'XXFND_COMMUNICATIONS', '-1', 'UPDATE', ~'
                 || l_att || q'~); end;~');
    session_as('R85_NOBODY');
    check_(xxfnd_attach_pkg.record_visible('XXFND_COMMUNICATIONS', to_char(l_comm)) = 'N',
           'someone without access to the record does not see it');
    expect_error(-20331, 'nor open its document', 'begin xxfnd_attach_pkg.download_checked(' || l_doc || '); end;');

    ---------------------------------------------------------------- feedback of every application
    session_as('ADMIN');
    select count(*) into l_n from apex_team_feedback where application_id = l_app;
    expect_error(-20171, 'feedback is taken for the registered applications only',
                 q'~begin xxfnd_application_pkg.submit_feedback(4000, 1, 1, 'no'); end;~');
    expect_error(-20173, 'an empty feedback is refused',
                 'begin xxfnd_application_pkg.submit_feedback(' || l_app || ', 1, 1, null); end;');
    xxfnd_application_pkg.submit_feedback(l_app, 1, 2, 'R85 feedback: a test idea for an improvement.');
    commit;
    select count(*) into l_n2 from apex_team_feedback where application_id = l_app;
    check_(l_n2 = l_n + 1, 'feedback is given on a page of an application and kept by APEX');
    select max(feedback_id) into l_n from apex_team_feedback where application_id = l_app and feedback like 'R85 feedback%';
    session_as('R85_NOBODY');
    expect_error(-20172, 'a follow-up needs Usage and Feedback - Manage',
                 'begin xxfnd_application_pkg.feedback_follow_up(' || l_n || ', ''no''); end;');
    session_as('ADMIN');
    xxfnd_application_pkg.feedback_follow_up(l_n, 'R85 follow-up: thank you, noted.');
    commit;
    select count(*) into l_n2 from apex_team_feedback_followup where feedback_id = l_n;
    check_(l_n2 >= 1, 'the follow-up is kept with the feedback');

    ---------------------------------------------------------------- platform activity (APEX activity log)
    select count(*) into l_n from apex_workspace_activity_log l
      join xxfnd_applications a on a.apex_application_id = l.application_id
     where l.view_date > sysdate - 30;
    check_(l_n >= 0, 'the activity of the registered applications is read from the APEX activity log (' || l_n || ' views)');
end;
/
