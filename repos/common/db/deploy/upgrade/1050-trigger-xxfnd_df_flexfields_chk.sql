--------------------------------------------------------------------------------
-- 06a_xxfnd_dff_pkg.sql
-- Descriptive flexfield setup (0.5): the integrity triggers on flexfield and segment definitions.
-- Release 80: the checks and the <TABLE>_DFV reporting views are in XXFND_DFF_PKG (10/11).
--------------------------------------------------------------------------------

-- release 80: the setup checks and the DFV views are in XXFND_DFF_PKG (10/11); XXFND_DFF_SETUP_PKG is dropped below

--------------------------------------------------------------------------------
-- Setup-integrity triggers
--------------------------------------------------------------------------------
create or replace trigger xxfnd_df_flexfields_chk
    before insert or update of table_name, pk_column_name, context_column_name, context_reference_column,
                               context_rule_type, context_rule_function, context_user_selectable_flag
    on xxfnd_df_flexfields
    for each row
begin
    -- release 92 (UI issue 6): the context rule decides; the reference column only for ATTRIBUTE, the user list only
    -- for USER, a function name only for FUNCTION
    :new.context_rule_type := upper(nvl(:new.context_rule_type, 'GLOBAL'));
    if :new.context_rule_type <> 'ATTRIBUTE' then
        :new.context_reference_column := null;
    elsif :new.context_reference_column is null then
        raise_application_error(-20215, 'Choose the attribute the context follows (context rule "By attribute").');
    end if;
    if :new.context_rule_type <> 'FUNCTION' then
        :new.context_rule_function := null;
    elsif :new.context_rule_function is null then
        raise_application_error(-20215, 'Enter the function that returns the context (context rule "By function").');
    end if;
    :new.context_user_selectable_flag := case when :new.context_rule_type = 'USER' then 'Y' else 'N' end;
    :new.table_name               := upper(:new.table_name);
    :new.pk_column_name           := upper(:new.pk_column_name);
    :new.context_column_name      := upper(:new.context_column_name);
    :new.context_reference_column := upper(:new.context_reference_column);
    xxfnd_dff_pkg.check_flexfield(:new.table_name, :new.pk_column_name,
                                  :new.context_column_name, :new.context_reference_column);
end;
/
