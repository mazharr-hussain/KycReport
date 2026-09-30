create or replace package body xxcus.xxfnd_dff_pkg as

    c_num_nls constant varchar2(40) := 'NLS_NUMERIC_CHARACTERS=''.,''';
    type t_segment is record (
            context_code    xxfnd_df_segments.context_code%type,
            global_flag     varchar2(1),
            segment_code    xxfnd_df_segments.segment_code%type,
            column_name     xxfnd_df_segments.column_name%type,
            prompt          varchar2(240),
            help_text       varchar2(1000),
            value_set_code  xxfnd_df_segments.value_set_code%type,
            validation_type xxfnd_value_sets.validation_type%type,
            format_type     xxfnd_value_sets.format_type%type,
            maximum_size    xxfnd_value_sets.maximum_size%type,
            minimum_value   xxfnd_value_sets.minimum_value%type,
            maximum_value   xxfnd_value_sets.maximum_value%type,
            uppercase_only  xxfnd_value_sets.uppercase_only_flag%type,
            lookup_type     xxfnd_value_sets.lookup_type%type,
            parent_vs       xxfnd_value_sets.parent_value_set_code%type,
            required_flag   varchar2(1),
            default_type    xxfnd_df_segments.default_type%type,
            default_value   xxfnd_df_segments.default_value%type,
            read_only_flag  varchar2(1),
            display_flag    varchar2(1)
    );
    type t_segments is
        table of t_segment index by pls_integer;

    ----------------------------------------------------------------------------
    -- helpers
    ----------------------------------------------------------------------------
    function get_ff (
        p_table_name in varchar2
    ) return xxfnd_df_flexfields%rowtype is
        l_ff xxfnd_df_flexfields%rowtype;
    begin
        select
            *
        into l_ff
        from
            xxfnd_df_flexfields
        where
                table_name = upper(p_table_name)
            and enabled_flag = 'Y';

        return l_ff;
    exception
        when no_data_found then
            return l_ff;   -- all fields null: table has no enabled DFF
    end get_ff;

    function flexfield_for_table (
        p_table_name in varchar2
    ) return varchar2 is
    begin
        return get_ff(p_table_name).descriptive_flexfield_code;
    end flexfield_for_table;

    function column_family (
        p_column_name in varchar2
    ) return varchar2 is
    begin
        return
            case
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE_NUMBER' ) then
                    'NUMBER'
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE_DATE' ) then
                    'DATE'
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE_TIMESTAMP' ) then
                    'TIMESTAMP'
                when regexp_like ( p_column_name,
                                   '^ATTRIBUTE[0-9]' ) then
                    'CHAR'
            end;
    end column_family;

    -- Segments shown for a context: GLOBAL first, then the context's own.
    function load_segments (
        p_dff_code     in varchar2,
        p_context_code in varchar2
    ) return t_segments is
        l_segs t_segments;
    begin
        select
            s.context_code,
            c.global_flag,
            s.segment_code,
            s.column_name,
            nvl(t.prompt, s.prompt),
            nvl(t.help_text, s.help_text),
            s.value_set_code,
            vs.validation_type,
            vs.format_type,
            vs.maximum_size,
            vs.minimum_value,
            vs.maximum_value,
            vs.uppercase_only_flag,
            vs.lookup_type,
            vs.parent_value_set_code,
            s.required_flag,
            s.default_type,
            s.default_value,
            s.read_only_flag,
            s.display_flag
        bulk collect
        into l_segs
        from
                 xxfnd_df_segments s
            join xxfnd_df_contexts    c on c.descriptive_flexfield_code = s.descriptive_flexfield_code
                                        and c.context_code = s.context_code
            join xxfnd_value_sets     vs on vs.value_set_code = s.value_set_code
            left join xxfnd_df_segments_tl t on t.descriptive_flexfield_code = s.descriptive_flexfield_code
                                                and t.context_code = s.context_code
                                                and t.segment_code = s.segment_code
                                                and t.language_code = xxfnd_util_pkg.current_lang
        where
                s.descriptive_flexfield_code = p_dff_code
            and s.enabled_flag = 'Y'
            and c.enabled_flag = 'Y'
            and ( c.global_flag = 'Y'
                  or s.context_code = p_context_code )
        order by
            case c.global_flag
                when 'Y' then
                    0
                else
                    1
            end,
            s.sequence_number;

        return l_segs;
    end load_segments;

    -- Every column any segment of the DFF uses (all contexts).
    function configured_columns (
        p_dff_code in varchar2
    ) return apex_t_varchar2 is
        l_cols apex_t_varchar2;
    begin
        select distinct
            column_name
        bulk collect
        into l_cols
        from
            xxfnd_df_segments
        where
            descriptive_flexfield_code = p_dff_code;

        return l_cols;
    end configured_columns;

    -- Canonical text of a column, used in dynamic SQL select lists.
    function canonical_expr (
        p_column_name in varchar2
    ) return varchar2 is
        l_col varchar2(128) := dbms_assert.simple_sql_name(p_column_name);
    begin
        return
            case column_family(p_column_name)
                when 'NUMBER'    then
                    'to_char('
                    || l_col
                    || ', ''TM9'', '''
                    || replace(c_num_nls, '''', '''''')
                    || ''')'
                when 'DATE'      then
                    'to_char('
                    || l_col
                    || ', ''YYYY-MM-DD'')'
                when 'TIMESTAMP' then
                    'to_char('
                    || l_col
                    || ', ''YYYY-MM-DD"T"HH24:MI:SS'')'
                else
                    l_col
            end;
    end canonical_expr;

    -- Current stored values of one row as JSON {COLUMN: canonical text}.
    function row_values (
        p_ff       in xxfnd_df_flexfields%rowtype,
        p_pk_value in varchar2
    ) return json_object_t is
        l_cols apex_t_varchar2 := configured_columns(p_ff.descriptive_flexfield_code);
        l_sql  varchar2(32767);
        l_json clob;
    begin
        if p_pk_value is null then
            return json_object_t();
        end if;
        l_sql := '''ATTRIBUTE_CATEGORY'' value '
                 || dbms_assert.simple_sql_name(p_ff.context_column_name);
        if p_ff.context_reference_column is not null then
            l_sql := l_sql
                     || ', ''#REFERENCE#'' value to_char('
                     || dbms_assert.simple_sql_name(p_ff.context_reference_column)
                     || ')';
        end if;

        for i in 1..l_cols.count loop
            l_sql := l_sql
                     || ', '''
                     || l_cols(i)
                     || ''' value '
                     || canonical_expr(l_cols(i));
        end loop;

        l_sql := 'select json_object('
                 || l_sql
                 || ' returning clob) from '
                 || dbms_assert.simple_sql_name(p_ff.table_name)
                 || ' where '
                 || dbms_assert.simple_sql_name(p_ff.pk_column_name)
                 || ' = :pk';

        begin
            execute immediate l_sql
            into l_json
                using p_pk_value;
        exception
            when no_data_found then
                return json_object_t();
        end;

        return json_object_t.parse(l_json);
    end row_values;

    function context_is_valid (
        p_dff_code     in varchar2,
        p_context_code in varchar2
    ) return boolean is
        l_count pls_integer;
    begin
        if p_context_code is null then
            return false;
        end if;
        select
            count(*)
        into l_count
        from
            xxfnd_df_contexts
        where
                descriptive_flexfield_code = p_dff_code
            and context_code = p_context_code
            and global_flag = 'N'
            and enabled_flag = 'Y';

        return l_count > 0;
    end context_is_valid;

    function resolve_context (
        p_ff              in xxfnd_df_flexfields%rowtype,
        p_stored          in json_object_t,
        p_context_code    in varchar2,
        p_reference_value in varchar2
    ) return varchar2 is
        l_candidate varchar2(150);
    begin
        if p_ff.context_reference_column is not null then
            -- EBS reference field: the context always follows the column.
            l_candidate := coalesce(p_reference_value,
                                    p_stored.get_string('#REFERENCE#'));
        else
            l_candidate := coalesce(p_context_code,
                                    p_stored.get_string('ATTRIBUTE_CATEGORY'),
                                    p_ff.default_context_code);
        end if;

        if context_is_valid(p_ff.descriptive_flexfield_code, l_candidate) then
            return l_candidate;
        end if;
        return
            case
                when context_is_valid(p_ff.descriptive_flexfield_code, p_ff.default_context_code) then
                    p_ff.default_context_code
            end;

    end resolve_context;

    function derive_context (
        p_table_name      in varchar2,
        p_pk_value        in varchar2,
        p_context_code    in varchar2 default null,
        p_reference_value in varchar2 default null
    ) return varchar2 is
        l_ff xxfnd_df_flexfields%rowtype := get_ff(p_table_name);
    begin
        if l_ff.descriptive_flexfield_code is null then
            return null;
        end if;
        return resolve_context(l_ff,
                               row_values(l_ff, p_pk_value),
                               p_context_code,
                               p_reference_value);
    end derive_context;

    function admin_sql_error (
        p_sql   in clob,
        p_kind  in varchar2,
        p_parse in varchar2 default 'Y'
    ) return varchar2 is

        l_sql    varchar2(32767);
        l_plain  varchar2(32767);
        l_cursor integer;
        l_cols   dbms_sql.desc_tab2;
        l_count  integer;
    begin
        if p_sql is null then
            return null;
        end if;
        if dbms_lob.getlength(p_sql) > 32000 then
            return 'The query is too long.';
        end if;
        l_sql := trim(dbms_lob.substr(p_sql, 32000, 1));
        -- look at the statement's shape without its comments and quoted text
        l_plain := regexp_replace(l_sql, '/\*.*?\*/', ' ', 1, 0,
                                  'n');
        l_plain := regexp_replace(l_plain,
                                  '--[^'
                                  || chr(10)
                                  || ']*',
                                  ' ');

        l_plain := regexp_replace(l_plain, q'['[^']*']', q'['']');
        if not regexp_like(l_plain, '^\s*(select|with)\s', 'i') then
            return 'The SQL must be a query starting with SELECT or WITH.';
        end if;
        if instr(l_plain, ';') > 0 then
            return 'Enter one query without a semicolon.';
        end if;
        if regexp_like(l_plain, '@[a-z]', 'i') then
            return 'Database links are not allowed.';
        end if;
        if regexp_like(
            regexp_replace(l_plain, ':context_code([^a-z0-9_$#]|$)', ' \1', 1, 0,
                           'i'),
            ':[a-z_]',
            'i'
        ) then
            return 'The only bind variable allowed is :CONTEXT_CODE.';
        end if;

        if nvl(p_parse, 'Y') = 'Y' then
            l_cursor := dbms_sql.open_cursor;
            begin
                if upper(p_kind) = 'VALUE_SET' then
                    -- also proves the RETURN_VALUE and DISPLAY_VALUE columns exist
                    dbms_sql.parse(l_cursor, 'select to_char(return_value), to_char(display_value) from ('
                                             || l_sql
                                             || ')', dbms_sql.native);
                else
                    dbms_sql.parse(l_cursor, l_sql, dbms_sql.native);
                    dbms_sql.describe_columns2(l_cursor, l_count, l_cols);
                    if l_count <> 1 then
                        dbms_sql.close_cursor(l_cursor);
                        return 'The default query must return exactly one column.';
                    end if;

                end if;

                dbms_sql.close_cursor(l_cursor);
            exception
                when others then
                    if dbms_sql.is_open(l_cursor) then
                        dbms_sql.close_cursor(l_cursor);
                    end if;
                    return 'The query does not run: '
                           || regexp_replace(sqlerrm, '^ORA-[0-9]+: ', '')
                           ||
                        case
                            when upper(p_kind) = 'VALUE_SET' then
                                ' (it must return columns RETURN_VALUE and DISPLAY_VALUE)'
                        end;

            end;

        end if;

        return null;
    end admin_sql_error;

    function run_single_value (
        p_sql          in varchar2,
        p_context_code in varchar2
    ) return varchar2 is
        l_value varchar2(4000);
    begin
        if admin_sql_error(p_sql, 'DEFAULT', 'N') is not null then
            return null;   -- not an acceptable query: no default
        end if;

        if instr(
            upper(p_sql),
            ':CONTEXT_CODE'
        ) > 0 then
            execute immediate p_sql
            into l_value
                using p_context_code;
        else
            execute immediate p_sql
            into l_value;
        end if;

        return l_value;
    exception
        when others then
            return null;   -- a broken default must not stop the page from opening
    end run_single_value;

    function value_list (
        p_value_set_code in varchar2,
        p_context_code   in varchar2 default null
    ) return sys_refcursor is
        l_vs  xxfnd_value_sets%rowtype;
        l_cur sys_refcursor;
        l_sql varchar2(32767);
    begin
        select
            *
        into l_vs
        from
            xxfnd_value_sets
        where
            value_set_code = p_value_set_code;

        if l_vs.validation_type in ( 'INDEPENDENT', 'DEPENDENT' ) then
            open l_cur for select
                                              lookup_code        return_value,
                                              meaning            display_value,
                                              parent_lookup_code parent_value
                                          from
                                              xxfnd_lookup_values_vl
                           where
                                   lookup_type = l_vs.lookup_type
                               and active_flag = 'Y'
                           order by
                               display_sequence,
                               meaning;

        elsif
            l_vs.validation_type = 'TABLE'
            and admin_sql_error(l_vs.table_query, 'VALUE_SET', 'N') is null
        then
            l_sql := 'select to_char(return_value) return_value, to_char(display_value) display_value,'
                     || ' cast(null as varchar2(150)) parent_value from ('
                     || l_vs.table_query
                     || ')';
            if instr(
                upper(l_vs.table_query),
                ':CONTEXT_CODE'
            ) > 0 then
                open l_cur for l_sql
                    using p_context_code;

            else
                open l_cur for l_sql;

            end if;

        else
            open l_cur for select
                                              cast(null as varchar2(150)) return_value,
                                              cast(null as varchar2(240)) display_value,
                                              cast(null as varchar2(150)) parent_value
                                          from
                                              dual
                           where
                               1 = 0;

        end if;

        return l_cur;
    end value_list;

    -- Column name of the segment in this context that holds the parent value.
    function parent_column (
        p_segs      in t_segments,
        p_parent_vs in varchar2
    ) return varchar2 is
    begin
        for i in 1..p_segs.count loop
            if p_segs(i).value_set_code = p_parent_vs then
                return p_segs(i).column_name;
            end if;
        end loop;

        return null;
    end parent_column;

    ----------------------------------------------------------------------------
    -- render
    ----------------------------------------------------------------------------
    function field_html (
        p_seg        in t_segment,
        p_value      in varchar2,
        p_field_id   in varchar2,
        p_parent_col in varchar2,
        p_context    in varchar2,
        p_read_only  in boolean
    ) return clob is

        l_html  clob;
        l_attrs varchar2(4000);
        l_cur   sys_refcursor;
        l_ret   varchar2(4000);
        l_disp  varchar2(4000);
        l_par   varchar2(4000);
        l_type  varchar2(20);
    begin
        l_attrs := ' id="'
                   || p_field_id
                   || '" name="'
                   || p_field_id
                   || '"'
                   || ' data-dff-col="'
                   || p_seg.column_name
                   || '"'
                   || ' data-dff-format="'
                   || p_seg.format_type
                   || '"'
                   ||
            case
                when p_seg.required_flag = 'Y' then
                    ' required aria-required="true"'
            end
                   ||
            case
                when p_read_only
                     or p_seg.read_only_flag = 'Y' then
                    ' disabled'
            end;

        l_html := '<div class="t-Form-fieldContainer t-Form-fieldContainer--floatingLabel xxfnd-dff-field'
                  ||
            case
                when p_seg.required_flag = 'Y' then
                    ' is-required'
            end
                  ||
            case
                when p_seg.display_flag = 'N' then
                    ' u-hidden'
            end
                  || '">'
                  || '<div class="t-Form-labelContainer"><label for="'
                  || p_field_id
                  || '" class="t-Form-label">'
                  || apex_escape.html(p_seg.prompt)
                  || '</label></div>'
                  || '<div class="t-Form-inputContainer"><div class="t-Form-itemWrapper">';

        if p_seg.validation_type in ( 'INDEPENDENT', 'DEPENDENT', 'TABLE' ) then
            l_html := l_html
                      || '<select class="selectlist apex-item-select"'
                      || l_attrs
                      ||
                case
                    when p_parent_col is not null then
                        ' data-dff-parent="'
                        || p_parent_col
                        || '"'
                end
                      || '><option value=""></option>';

            l_cur := value_list(p_seg.value_set_code, p_context);
            loop
                fetch l_cur into
                    l_ret,
                    l_disp,
                    l_par;
                exit when l_cur%notfound;
                l_html := l_html
                          || '<option value="'
                          || apex_escape.html_attribute(l_ret)
                          || '"'
                          ||
                    case
                        when p_parent_col is not null then
                            ' data-parent-value="'
                            || apex_escape.html_attribute(l_par)
                            || '"'
                    end
                          ||
                    case
                        when l_ret = p_value then
                            ' selected'
                    end
                          || '>'
                          || apex_escape.html(l_disp)
                          || '</option>';

            end loop;

            close l_cur;
            l_html := l_html || '</select>';
        else
            l_type :=
                case p_seg.format_type
                    when 'NUMBER'    then
                        'number" step="any'
                    when 'DATE'      then
                        'date'
                    when 'TIMESTAMP' then
                        'datetime-local" step="1'
                    else
                        'text'
                end;

            l_html := l_html
                      || '<input type="'
                      || l_type
                      || '" class="text_field apex-item-text"'
                      || l_attrs
                      ||
                case
                    when p_seg.format_type = 'CHAR' then
                        ' maxlength="'
                        || least(
                            nvl(p_seg.maximum_size, 150),
                            150
                        )
                        || '"'
                        ||
                        case
                            when p_seg.uppercase_only = 'Y' then
                                    ' style="text-transform:uppercase"'
                        end
                end
                      ||
                case
                    when p_seg.format_type = 'NUMBER'
                         and p_seg.minimum_value is not null then
                        ' min="'
                        || apex_escape.html_attribute(p_seg.minimum_value)
                        || '"'
                end
                      ||
                case
                    when p_seg.format_type = 'NUMBER'
                         and p_seg.maximum_value is not null then
                        ' max="'
                        || apex_escape.html_attribute(p_seg.maximum_value)
                        || '"'
                end
                      || ' value="'
                      || apex_escape.html_attribute(p_value)
                      || '">';

        end if;

        l_html := l_html
                  || '</div>'
                  ||
            case
                when p_seg.help_text is not null then
                    '<span class="t-Form-inlineHelp">'
                    || apex_escape.html(p_seg.help_text)
                    || '</span>'
            end
                  || '<span id="'
                  || p_field_id
                  || '_error_placeholder" class="a-Form-error"></span>'
                  || '</div></div>';

        return l_html;
    end field_html;

    function render (
        p_table_name      in varchar2,
        p_pk_value        in varchar2,
        p_context_code    in varchar2 default null,
        p_reference_value in varchar2 default null,
        p_read_only       in varchar2 default 'N'
    ) return clob is

        l_ff      xxfnd_df_flexfields%rowtype := get_ff(p_table_name);
        l_stored  json_object_t;
        l_context varchar2(150);
        l_segs    t_segments;
        l_html    clob;
        l_value   varchar2(4000);
        l_prefix  varchar2(200);
        l_ro      boolean := p_read_only = 'Y';
        l_shown   pls_integer := 0;
    begin
        if l_ff.descriptive_flexfield_code is null then
            return '';
        end if;
        l_stored := row_values(l_ff, p_pk_value);
        l_context := resolve_context(l_ff, l_stored, p_context_code, p_reference_value);
        l_segs := load_segments(l_ff.descriptive_flexfield_code, l_context);
        l_prefix := 'dff_'
                    || lower(l_ff.descriptive_flexfield_code)
                    || '_';
        l_html := '<div class="xxfnd-dff" data-dff-code="'
                  || apex_escape.html_attribute(l_ff.descriptive_flexfield_code)
                  || '" data-dff-context="'
                  || apex_escape.html_attribute(l_context)
                  || '">';

        -- Context chooser (EBS "Context Value" field) when the user picks it.
        if
            l_ff.context_reference_column is null
            and l_ff.context_user_selectable_flag = 'Y'
        then
            l_html := l_html
                      || '<div class="t-Form-fieldContainer t-Form-fieldContainer--floatingLabel">'
                      || '<div class="t-Form-labelContainer"><label class="t-Form-label" for="'
                      || l_prefix
                      || 'context">'
                      || apex_escape.html(apex_lang.message('XXFND_DFF_CONTEXT_LABEL'))
                      || '</label></div>'
                      || '<div class="t-Form-inputContainer"><div class="t-Form-itemWrapper">'
                      || '<select class="selectlist apex-item-select" data-dff-context-select id="'
                      || l_prefix
                      || 'context"'
                      ||
                case
                    when l_ro then
                        ' disabled'
                end
                      || '><option value=""></option>';

            for c in (
                select
                    context_code,
                    context_name
                from
                    xxfnd_df_contexts_vl
                where
                        descriptive_flexfield_code = l_ff.descriptive_flexfield_code
                    and global_flag = 'N'
                    and enabled_flag = 'Y'
                order by
                    context_name
            ) loop
                l_html := l_html
                          || '<option value="'
                          || apex_escape.html_attribute(c.context_code)
                          || '"'
                          ||
                    case
                        when c.context_code = l_context then
                            ' selected'
                    end
                          || '>'
                          || apex_escape.html(c.context_name)
                          || '</option>';
            end loop;

            l_html := l_html || '</select></div></div></div>';
        end if;

        for i in 1..l_segs.count loop
            -- Stored value only if the row is on the same context (or the segment is GLOBAL).
            if l_segs(i).global_flag = 'Y'
            or nvl(
                l_stored.get_string('ATTRIBUTE_CATEGORY'),
                '#'
            ) = nvl(l_context, '#') then
                l_value := l_stored.get_string(l_segs(i).column_name);
            else
                l_value := null;
            end if;

            if
                l_value is null
                and p_pk_value is null
            then
                l_value :=
                    case l_segs(i).default_type
                        when 'CONSTANT' then
                            l_segs(i).default_value
                        when 'SQL'      then
                            run_single_value(l_segs(i).default_value,
                                             l_context)
                    end;

            end if;

            l_html := l_html
                      || field_html(
                p_seg        => l_segs(i),
                p_value      => l_value,
                p_field_id   => l_prefix
                              || lower(l_segs(i).column_name),
                p_parent_col =>
                              case
                                  when l_segs(i).validation_type = 'DEPENDENT' then
                                      parent_column(l_segs,
                                                    l_segs(i).parent_vs)
                              end,
                p_context    => l_context,
                p_read_only  => l_ro
            );

            if l_segs(i).display_flag = 'Y' then
                l_shown := l_shown + 1;
            end if;

        end loop;

        l_html := l_html || '</div>';
        if
            l_shown = 0
            and not (
                l_ff.context_reference_column is null
                and l_ff.context_user_selectable_flag = 'Y'
            )
        then
            return '';
        end if;

        return l_html;
    end render;

    ----------------------------------------------------------------------------
    -- validate / save
    ----------------------------------------------------------------------------
    function to_num (
        p_value in varchar2
    ) return number is
    begin
        return to_number ( p_value,
        '9999999999999999999999999999D9999999999',
        c_num_nls );
    exception
        when value_error or invalid_number then
            return null;
    end to_num;

    function to_dt (
        p_value in varchar2
    ) return date is
    begin
        if not regexp_like(p_value, '^\d{4}-\d{2}-\d{2}$') then
            return null;
        end if;
        return to_date ( p_value,
        'YYYY-MM-DD' );
    exception
        when others then
            return null;   -- ORA-018xx: not a valid date
    end to_dt;

    function to_ts (
        p_value in varchar2
    ) return timestamp is
    begin
        if not regexp_like(p_value, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$') then
            return null;
        end if;
        return to_timestamp ( rpad(p_value, 19, ':00'),
        'YYYY-MM-DD"T"HH24:MI:SS' );
    exception
        when others then
            return null;
    end to_ts;

    function in_value_list (
        p_seg          in t_segment,
        p_value        in varchar2,
        p_parent_value in varchar2,
        p_context      in varchar2
    ) return boolean is
        l_count pls_integer;
        l_sql   varchar2(32767);
        l_query clob;
    begin
        if p_seg.validation_type = 'INDEPENDENT' then
            select
                count(*)
            into l_count
            from
                xxfnd_lookup_values_vl
            where
                    lookup_type = p_seg.lookup_type
                and lookup_code = p_value
                and active_flag = 'Y';

        elsif p_seg.validation_type = 'DEPENDENT' then
            select
                count(*)
            into l_count
            from
                xxfnd_lookup_values_vl
            where
                    lookup_type = p_seg.lookup_type
                and lookup_code = p_value
                and active_flag = 'Y'
                and ( p_parent_value is null
                      or parent_lookup_code = p_parent_value );

        elsif p_seg.validation_type = 'TABLE' then
            select
                table_query
            into l_query
            from
                xxfnd_value_sets
            where
                value_set_code = p_seg.value_set_code;

            if admin_sql_error(l_query, 'VALUE_SET', 'N') is not null then
                raise_application_error(-20411, 'Value set '
                                                || p_seg.value_set_code
                                                || ' has a query that is not allowed.');
            end if;

            l_sql := 'select count(*) from ('
                     || l_query
                     || ') where to_char(return_value) = :v';
            if instr(
                upper(l_query),
                ':CONTEXT_CODE'
            ) > 0 then
                execute immediate l_sql
                into l_count
                    using p_context, p_value;
            else
                execute immediate l_sql
                into l_count
                    using p_value;
            end if;

        else
            return true;
        end if;

        return l_count > 0;
    end in_value_list;

    function check_value (
        p_seg     in t_segment,
        p_value   in varchar2,
        p_values  in json_object_t,
        p_segs    in t_segments,
        p_context in varchar2
    ) return varchar2 is
        l_num    number;
        l_parent varchar2(128);
    begin
        if p_value is null then
            return
                case
                    when p_seg.required_flag = 'Y' then
                        apex_lang.message('XXFND_DFF_REQUIRED', p_seg.prompt)
                end;
        end if;

        case p_seg.format_type
            when 'CHAR' then
                if length(p_value) > least(
                    nvl(p_seg.maximum_size, 150),
                    150
                ) then
                    return apex_lang.message('XXFND_DFF_TOO_LONG',
                                             p_seg.prompt,
                                             least(
                                                           nvl(p_seg.maximum_size, 150),
                                                           150
                                                       ));
                end if;

                if
                    p_seg.uppercase_only = 'Y'
                    and p_value <> upper(p_value)
                then
                    return apex_lang.message('XXFND_DFF_UPPERCASE', p_seg.prompt);
                end if;

            when 'NUMBER' then
                l_num := to_num(p_value);
                if l_num is null then
                    return apex_lang.message('XXFND_DFF_NOT_NUMBER', p_seg.prompt);
                end if;

                if (
                    p_seg.minimum_value is not null
                    and l_num < to_num(p_seg.minimum_value)
                )
                or (
                    p_seg.maximum_value is not null
                    and l_num > to_num(p_seg.maximum_value)
                ) then
                    return apex_lang.message('XXFND_DFF_OUT_OF_RANGE', p_seg.prompt, p_seg.minimum_value, p_seg.maximum_value);
                end if;

            when 'DATE' then
                if to_dt(p_value) is null then
                    return apex_lang.message('XXFND_DFF_NOT_DATE', p_seg.prompt);
                end if;
            when 'TIMESTAMP' then
                if to_ts(p_value) is null then
                    return apex_lang.message('XXFND_DFF_NOT_DATE', p_seg.prompt);
                end if;
        end case;

        if p_seg.validation_type <> 'NONE' then
            l_parent :=
                case
                    when p_seg.validation_type = 'DEPENDENT' then
                        parent_column(p_segs, p_seg.parent_vs)
                end;

            if not in_value_list(p_seg,
                                 p_value,
                                 case
                                     when l_parent is not null then
                                           p_values.get_string(l_parent)
                                 end,
                                 p_context) then
                return apex_lang.message('XXFND_DFF_NOT_IN_LIST', p_seg.prompt);
            end if;

        end if;

        return null;
    end check_value;

    function validate (
        p_table_name      in varchar2,
        p_values_json     in clob,
        p_context_code    in varchar2 default null,
        p_pk_value        in varchar2 default null,
        p_reference_value in varchar2 default null
    ) return varchar2 is

        l_ff      xxfnd_df_flexfields%rowtype := get_ff(p_table_name);
        l_values  json_object_t;
        l_context varchar2(150);
        l_segs    t_segments;
        l_error   varchar2(4000);
    begin
        if l_ff.descriptive_flexfield_code is null then
            return null;
        end if;
        l_values :=
            case
                when p_values_json is null then
                    json_object_t()
                else
                    json_object_t.parse(p_values_json)
            end;

        l_context := resolve_context(l_ff,
                                     row_values(l_ff, p_pk_value),
                                     p_context_code,
                                     p_reference_value);

        if
            l_context is null
            and l_ff.context_required_flag = 'Y'
        then
            return apex_lang.message('XXFND_DFF_CONTEXT_REQUIRED');
        end if;

        l_segs := load_segments(l_ff.descriptive_flexfield_code, l_context);
        for i in 1..l_segs.count loop
            -- Read-only segments are not submitted by the page; skip their required check.
            if l_segs(i).read_only_flag = 'N' then
                l_error := check_value(
                    l_segs(i),
                    l_values.get_string(l_segs(i).column_name),
                    l_values,
                    l_segs,
                    l_context
                );

                if l_error is not null then
                    return l_error;
                end if;
            end if;
        end loop;

        return null;
    exception
        when others then
            if sqlcode between - 40999 and - 40400 then   -- JSON parse errors
                return apex_lang.message('XXFND_DFF_BAD_PAYLOAD');
            end if;

            raise;
    end validate;

    procedure save (
        p_table_name      in varchar2,
        p_pk_value        in varchar2,
        p_values_json     in clob,
        p_context_code    in varchar2 default null,
        p_reference_value in varchar2 default null
    ) is

        l_ff      xxfnd_df_flexfields%rowtype := get_ff(p_table_name);
        l_values  json_object_t;
        l_stored  json_object_t;
        l_clean   json_object_t := json_object_t();
        l_context varchar2(150);
        l_segs    t_segments;
        l_cols    apex_t_varchar2;
        l_error   varchar2(4000);
        l_sql     varchar2(32767);
        l_value   varchar2(4000);
    begin
        if l_ff.descriptive_flexfield_code is null
           or p_pk_value is null then
            return;
        end if;
        l_error := validate(p_table_name, p_values_json, p_context_code, p_pk_value, p_reference_value);
        if l_error is not null then
            raise_application_error(-20200, l_error);
        end if;
        l_values :=
            case
                when p_values_json is null then
                    json_object_t()
                else
                    json_object_t.parse(p_values_json)
            end;

        l_stored := row_values(l_ff, p_pk_value);
        l_context := resolve_context(l_ff, l_stored, p_context_code, p_reference_value);
        l_segs := load_segments(l_ff.descriptive_flexfield_code, l_context);

        -- Keep only this context's (and GLOBAL) columns, in canonical form.
        -- Read-only segments keep their stored value.
        for i in 1..l_segs.count loop
            l_value :=
                case
                    when l_segs(i).read_only_flag = 'Y' then
                        l_stored.get_string(l_segs(i).column_name)
                    else
                        l_values.get_string(l_segs(i).column_name)
                end;

            if l_segs(i).uppercase_only = 'Y' then
                l_value := upper(l_value);
            end if;

            if l_value is not null then
                l_clean.put(l_segs(i).column_name,
                            l_value);
            end if;

        end loop;

        -- One UPDATE, one bind: every configured column reads its value from the
        -- JSON; columns of other contexts get null.
        l_cols := configured_columns(l_ff.descriptive_flexfield_code);
        l_sql := dbms_assert.simple_sql_name(l_ff.context_column_name)
                 || ' = :ctx';
        for i in 1..l_cols.count loop
            l_sql := l_sql
                     || ', '
                     || dbms_assert.simple_sql_name(l_cols(i))
                     || ' = '
                     ||
                case column_family(l_cols(i))
                    when 'NUMBER'    then
                        'to_number(json_value(:j, ''$.'
                        || l_cols(i)
                        || '''), ''9999999999999999999999999999D9999999999'', '''
                        || replace(c_num_nls, '''', '''''')
                        || ''')'
                    when 'DATE'      then
                        'to_date(json_value(:j, ''$.'
                        || l_cols(i)
                        || '''), ''YYYY-MM-DD'')'
                    when 'TIMESTAMP' then
                        'to_timestamp(rpad(json_value(:j, ''$.'
                        || l_cols(i)
                        || '''), 19, '':00''), ''YYYY-MM-DD"T"HH24:MI:SS'')'
                    else
                        'json_value(:j, ''$.'
                        || l_cols(i)
                        || ''' returning varchar2(150))'
                end;
        end loop;

        l_sql := 'update '
                 || dbms_assert.simple_sql_name(l_ff.table_name)
                 || ' set '
                 || l_sql
                 || ' where '
                 || dbms_assert.simple_sql_name(l_ff.pk_column_name)
                 || ' = :pk';

        -- Named binds repeat; dynamic SQL binds by position, so use DBMS_SQL.
        declare
            l_cursor integer := dbms_sql.open_cursor;
            l_rows   integer;
        begin
            dbms_sql.parse(l_cursor, l_sql, dbms_sql.native);
            dbms_sql.bind_variable(l_cursor, ':ctx', l_context);
            if l_cols.count > 0 then
                dbms_sql.bind_variable(l_cursor, ':j', l_clean.to_clob);
            end if;

            dbms_sql.bind_variable(l_cursor, ':pk', p_pk_value);
            l_rows := dbms_sql.execute(l_cursor);
            dbms_sql.close_cursor(l_cursor);
        exception
            when others then
                if dbms_sql.is_open(l_cursor) then
                    dbms_sql.close_cursor(l_cursor);
                end if;
                raise;
        end;

    end save;

end xxfnd_dff_pkg;
/


-- sqlcl_snapshot {"hash":"24f3597a493c28a64e94ad158c720f77f853c2f0","type":"PACKAGE_BODY","name":"XXFND_DFF_PKG","schemaName":"XXCUS","sxml":""}