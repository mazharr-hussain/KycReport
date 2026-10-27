
create or replace package xxfnd_data_model_pkg authid definer as
    -- Y when the signed-in user may see the application's objects: IT (Common Administrator) every application (or
    -- the one chosen in COMMON's application selector), a delegated administrator only the application that opened
    -- COMMON; outside an APEX session (install, tests) every application.
    function app_visible(p_application_code in varchar2) return varchar2;
    -- Y when the views read the DBA_ dictionary (every schema), N when they read the ALL_ views (COMMON's own
    -- objects and what COMMON may see of other schemas).
    function full_dictionary return varchar2;
    -- The columns of an index: P_DISPLAY Y = as written (function-based columns as their expression), N = the real
    -- columns the index reads (comma separated).
    function index_columns(p_owner in varchar2, p_index_name in varchar2, p_display in varchar2 default 'Y') return varchar2;
    -- The application's object prefix (null = every object of its schema; release 102: several, comma separated, e.g.
    -- XXFND_,XXHR_). In an APEX session: Data Model - Manage.
    procedure set_object_prefix(p_application_code in varchar2, p_object_prefix in varchar2);
    -- The group of one of the application's tables in the diagram; added when missing, an administrator's change is kept.
    procedure register_table_group(p_application_code in varchar2, p_table_name in varchar2, p_group_name in varchar2);
    procedure unregister_table_group(p_application_code in varchar2, p_table_name in varchar2);
    -- The prefix and the groups of the application (XXFND_APPLICATION_PKG.DELETE_APPLICATION).
    procedure unregister_application(p_application_code in varchar2);
    -- The diagram of the application as Mermaid text (an erDiagram): P_TABLE given = that table with the tables it
    -- refers to and the tables that refer to it; else P_GROUP given = the tables of the group (tables of other groups
    -- they refer to with their primary key only); else every table and foreign key of the application. Only key
    -- columns (primary, foreign, unique, indexed) are shown.
    function erd_source(p_application_code in varchar2,
                        p_group            in varchar2 default null,
                        p_table            in varchar2 default null) return clob;
end xxfnd_data_model_pkg;
/
