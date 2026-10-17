
-- Compound trigger: the cross-row GLOBAL-column check reads XXFND_DF_SEGMENTS,
-- so it runs after the statement to avoid a mutating-table error.
create or replace trigger xxfnd_df_segments_chk
    for insert or update of column_name, value_set_code, context_code on xxfnd_df_segments
    compound trigger

    type t_key is record (dff varchar2(60), ctx varchar2(80), seg varchar2(30),
                          col varchar2(128), vs varchar2(60));
    type t_keys is table of t_key index by pls_integer;
    g_keys t_keys;

    before each row is
    begin
        :new.column_name := upper(:new.column_name);
        :new.segment_code := upper(:new.segment_code);
    end before each row;

    after each row is
        l_key t_key;
    begin
        l_key.dff := :new.descriptive_flexfield_code;
        l_key.ctx := :new.context_code;
        l_key.seg := :new.segment_code;
        l_key.col := :new.column_name;
        l_key.vs  := :new.value_set_code;
        g_keys(g_keys.count + 1) := l_key;
    end after each row;

    after statement is
    begin
        for i in 1 .. g_keys.count loop
            xxfnd_dff_pkg.check_segment(g_keys(i).dff, g_keys(i).ctx, g_keys(i).seg,
                                        g_keys(i).col, g_keys(i).vs);
        end loop;
        g_keys.delete;
    end after statement;
end xxfnd_df_segments_chk;
/
