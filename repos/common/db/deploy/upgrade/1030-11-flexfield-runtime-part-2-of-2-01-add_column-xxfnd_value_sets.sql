-- Release 86: REGISTER_VALUE_SET reads the value set's application; on older databases 16i adds that column, a fresh
-- install needs it before this body compiles (checked step: nothing when it exists).
begin
    xxfnd_ddl_pkg.add_column('XXFND_VALUE_SETS', 'APPLICATION_CODE', 'varchar2(30)');
end;
/
