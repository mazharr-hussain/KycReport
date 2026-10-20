
-- Compound trigger: the cross-row GLOBAL-column check reads XXFND_DF_SEGMENTS,
-- so it runs after the statement to avoid a mutating-table error.
create or replace trigger xxfnd_df_segments_chk
    for insert or update of column_name, value_set_code, context_code, api_name, sequence_number on xxfnd_df_segments
    compound trigger

    type t_key is record (dff varchar2(60), ctx varchar2(80), seg varchar2(30),
                          col varchar2(128), vs varchar2(60));
    type t_keys is table of t_key index by pls_integer;
    g_keys t_keys;
    g_tmp_seq number := 0;   -- release 92: placeholders (negative) for segments saved without a sequence

    before each row is
        l_app xxfnd_df_flexfields.application_code%type;
    begin
        :new.column_name := upper(:new.column_name);
        :new.segment_code := upper(:new.segment_code);
        -- release 92 (UI issue 7): the API name defaults to the segment code; "LOOKUP:<type>" from the segment grid
        -- becomes that lookup type's value set
        :new.api_name := lower(nvl(:new.api_name, :new.segment_code));
        if :new.sequence_number is null then   -- a placeholder; AFTER STATEMENT gives the next of the context, by 10
            g_tmp_seq := g_tmp_seq - 1;
            :new.sequence_number := g_tmp_seq;
        end if;
        if :new.value_set_code like 'LOOKUP:%' then
            select max(application_code) into l_app
              from xxfnd_df_flexfields where descriptive_flexfield_code = :new.descriptive_flexfield_code;
            :new.value_set_code := xxfnd_dff_pkg.lookup_value_set(l_app, substr(:new.value_set_code, 8));
        end if;
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
        if g_tmp_seq < 0 then
            for r in (select rowid rid, descriptive_flexfield_code dff, context_code ctx from xxfnd_df_segments
                       where sequence_number < 0 order by sequence_number desc) loop
                update xxfnd_df_segments
                   set sequence_number = (select nvl(max(sequence_number), 0) + 10 from xxfnd_df_segments
                                           where descriptive_flexfield_code = r.dff and context_code = r.ctx
                                             and sequence_number > 0)
                 where rowid = r.rid;
            end loop;
        end if;
        for i in 1 .. g_keys.count loop
            xxfnd_dff_pkg.check_segment(g_keys(i).dff, g_keys(i).ctx, g_keys(i).seg,
                                        g_keys(i).col, g_keys(i).vs);
        end loop;
        g_keys.delete;
    end after statement;
end xxfnd_df_segments_chk;
/
