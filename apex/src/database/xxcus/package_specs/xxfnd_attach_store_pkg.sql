create or replace package xxcus.xxfnd_attach_store_pkg authid definer as
    c_purpose constant varchar2(30) := 'DOCUMENT_STORAGE';
    type t_stored is record (
            external_document_id varchar2(500),
            external_version_id  varchar2(500),
            external_url         varchar2(2000)
    );

    -- Stores a file (new document, or a new version when p_previous_external_id is set).
    function upload (
        p_cfg                  in xxfnd_storage_config%rowtype,
        p_entity               in varchar2,
        p_pk1                  in varchar2,
        p_folder               in varchar2,
        p_file                 in blob,
        p_filename             in varchar2,
        p_mime                 in varchar2,
        p_title                in varchar2,
        p_previous_external_id in varchar2
    ) return t_stored;

    -- Reads a stored file. p_is_current = false fetches that exact older version.
    function fetch_file (
        p_doc        in xxfnd_documents%rowtype,
        p_is_current in boolean,
        p_entity     in varchar2,
        p_pk1        in varchar2
    ) return blob;

end xxfnd_attach_store_pkg;
/


-- sqlcl_snapshot {"hash":"91629ceaac138c85ca0324355b15c57cb16ee5c8","type":"PACKAGE_SPEC","name":"XXFND_ATTACH_STORE_PKG","schemaName":"XXCUS","sxml":""}