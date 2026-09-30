create or replace package xxcus.xxfnd_dff_setup_pkg authid definer as

    -- Setup checks, called from the XXFND_DF_SEGMENTS trigger.
    procedure check_segment (
        p_dff_code     in varchar2,
        p_context_code in varchar2,
        p_segment_code in varchar2,
        p_column_name  in varchar2,
        p_value_set    in varchar2
    );

    procedure check_flexfield (
        p_table_name       in varchar2,
        p_pk_column        in varchar2,
        p_context_column   in varchar2,
        p_reference_column in varchar2
    );

    -- Creates or replaces <TABLE>_DFV: one readable column per segment,
    -- for reports and integrations (EBS "DFV" views).
    procedure generate_dfv_view (
        p_dff_code in varchar2
    );

    procedure generate_all_dfv_views;

end xxfnd_dff_setup_pkg;
/


-- sqlcl_snapshot {"hash":"fc9d2d46cb0b54ccb434736fa80a4c2860a7db4c","type":"PACKAGE_SPEC","name":"XXFND_DFF_SETUP_PKG","schemaName":"XXCUS","sxml":""}