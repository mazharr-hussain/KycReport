create table xxcus.xxcmp_approval_matrix (
    risk_tier             varchar2(30 byte) not null enable,
    required_levels       number(1, 0) not null enable,
    level1_role_code      varchar2(30 byte) not null enable,
    level2_role_code      varchar2(30 byte),
    sar_gate_flag         varchar2(1 byte) default 'N' not null enable,
    created_by            varchar2(255 byte) not null enable,
    creation_date         timestamp(6) not null enable,
    last_updated_by       varchar2(255 byte) not null enable,
    last_update_date      timestamp(6) not null enable,
    last_update_login     varchar2(255 byte),
    object_version_number number default 1 not null enable
);

alter table xxcus.xxcmp_approval_matrix
    add constraint xxcmp_approval_matrix_ck1
        check ( required_levels in ( 1, 2 ) ) enable;

alter table xxcus.xxcmp_approval_matrix
    add constraint xxcmp_approval_matrix_ck2
        check ( ( required_levels = 1
                  and level2_role_code is null )
                or ( required_levels = 2
                     and level2_role_code is not null
                     and level2_role_code <> level1_role_code ) ) enable;

alter table xxcus.xxcmp_approval_matrix
    add constraint xxcmp_approval_matrix_ck3
        check ( sar_gate_flag in ( 'Y', 'N' ) ) enable;

alter table xxcus.xxcmp_approval_matrix
    add constraint xxcmp_approval_matrix_pk primary key ( risk_tier )
        using index enable;


-- sqlcl_snapshot {"hash":"bb68ad9f4dd04f3bd4dd77818734e8bac77a0369","type":"TABLE","name":"XXCMP_APPROVAL_MATRIX","schemaName":"XXCUS","sxml":"\n  <TABLE xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_APPROVAL_MATRIX</NAME>\n   <RELATIONAL_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>RISK_TIER</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>30</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>REQUIRED_LEVELS</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            <PRECISION>1</PRECISION>\n            <SCALE>0</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LEVEL1_ROLE_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>30</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LEVEL2_ROLE_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>30</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>SAR_GATE_FLAG</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'N'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CREATED_BY</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CREATION_DATE</NAME>\n            <DATATYPE>TIMESTAMP</DATATYPE>\n            <SCALE>6</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATED_BY</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATE_DATE</NAME>\n            <DATATYPE>TIMESTAMP</DATATYPE>\n            <SCALE>6</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATE_LOGIN</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>OBJECT_VERSION_NUMBER</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            <DEFAULT>1</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n      </COL_LIST>\n      <CHECK_CONSTRAINT_LIST>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_APPROVAL_MATRIX_CK1</NAME>\n            <CONDITION>required_levels in (1,2)</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_APPROVAL_MATRIX_CK2</NAME>\n            <CONDITION>\n        (required_levels = 1 and level2_role_code is null) or\n        (required_levels = 2 and level2_role_code is not null and level2_role_code &#60;> level1_role_code)</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_APPROVAL_MATRIX_CK3</NAME>\n            <CONDITION>sar_gate_flag in ('Y','N')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n      </CHECK_CONSTRAINT_LIST>\n      <PRIMARY_KEY_CONSTRAINT_LIST>\n         <PRIMARY_KEY_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_APPROVAL_MATRIX_PK</NAME>\n            <COL_LIST>\n               <COL_LIST_ITEM>\n                  <NAME>RISK_TIER</NAME>\n               </COL_LIST_ITEM>\n            </COL_LIST>\n            <USING_INDEX></USING_INDEX>\n         </PRIMARY_KEY_CONSTRAINT_LIST_ITEM>\n      </PRIMARY_KEY_CONSTRAINT_LIST>\n      <DEFAULT_COLLATION>USING_NLS_COMP</DEFAULT_COLLATION>\n      <PHYSICAL_PROPERTIES>\n         <HEAP_TABLE></HEAP_TABLE>\n      </PHYSICAL_PROPERTIES>\n      \n   </RELATIONAL_TABLE>\n</TABLE>"}