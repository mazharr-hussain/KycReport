
create or replace package body xxfnd_retention_pkg as

    function is_active return varchar2 is
    begin
        return 'N';
    end is_active;

    function policy_for(p_table_name in varchar2, p_jurisdiction in varchar2 default null) return number is
    begin
        return null;   -- placeholder: no policy applies
    end policy_for;

    procedure run is
    begin
        null;          -- placeholder: nothing is flagged, archived or deleted
    end run;

end xxfnd_retention_pkg;
/
