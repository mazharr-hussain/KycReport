-- R15 upload limits: the category's value wins over the attachment page's, which wins over the application setting.
-- Changes page 21's registration and category OTHER for the test and restores them.
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_page  xxfnd_attachment_functions%rowtype;
    l_cat   xxfnd_document_categories%rowtype;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function size_mb return number is begin return xxfnd_attach_pkg.max_file_size_mb(21, 'OTHER'); end;
    function types return varchar2 is begin return xxfnd_attach_pkg.allowed_file_types(21, 'OTHER'); end;
begin
    select application_id into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'KYC';
    apex_session.create_session(l_app, 1, 'ADMIN');
    select * into l_page from xxfnd_attachment_functions where apex_app_alias = 'KYC' and apex_page_id = 21;
    select * into l_cat from xxfnd_document_categories where category_code = 'OTHER';
    update xxfnd_attachment_functions set max_file_size_mb = null, allowed_file_types = null where function_code = l_page.function_code;
    update xxfnd_document_categories set max_file_size_mb = null, allowed_file_types = null where category_code = 'OTHER';

    ok('application default: ' || size_mb || ' MB, ' || types,
       size_mb = 10 and types = 'pdf,jpg,jpeg,png,tif,tiff,doc,docx,xls,xlsx,msg,eml');
    ok('rules text: ' || xxfnd_attach_pkg.upload_rules_text(21, 'OTHER'),
       xxfnd_attach_pkg.upload_rules_text(21, 'OTHER') like 'PDF, JPG, %up to 10 MB');

    update xxfnd_attachment_functions set max_file_size_mb = 5, allowed_file_types = ' .PDF, Jpg '
     where function_code = l_page.function_code;
    ok('the page overrides the application: ' || size_mb || ' MB, ' || types, size_mb = 5 and types = 'pdf,jpg');
    ok('another page keeps the application default: ' || xxfnd_attach_pkg.max_file_size_mb(31, 'OTHER') || ' MB',
       xxfnd_attach_pkg.max_file_size_mb(31, 'OTHER') = 10);

    update xxfnd_document_categories set max_file_size_mb = 2 where category_code = 'OTHER';
    ok('the category size overrides the page: ' || size_mb || ' MB (types still from the page: ' || types || ')',
       size_mb = 2 and types = 'pdf,jpg');
    update xxfnd_document_categories set allowed_file_types = '*' where category_code = 'OTHER';
    ok('the category can allow any type: ' || xxfnd_attach_pkg.upload_rules_text(21, 'OTHER'),
       types = '*' and xxfnd_attach_pkg.upload_rules_text(21, 'OTHER') = 'Any file type up to 2 MB');

    rollback;
    apex_session.delete_session;
end;
/
exit
