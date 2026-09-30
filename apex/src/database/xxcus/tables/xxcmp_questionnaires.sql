create table xxcus.xxcmp_questionnaires (
    questionnaire_code     varchar2(30 byte) not null enable,
    questionnaire_name     varchar2(240 byte) not null enable,
    audience               varchar2(20 byte) not null enable,
    low_risk_max_score     number,
    medium_risk_max_score  number,
    current_version_number number default 1 not null enable,
    enabled_flag           varchar2(1 byte) default 'Y' not null enable,
    created_by             varchar2(255 byte) not null enable,
    creation_date          timestamp(6) not null enable,
    last_updated_by        varchar2(255 byte) not null enable,
    last_update_date       timestamp(6) not null enable,
    last_update_login      varchar2(255 byte),
    object_version_number  number default 1 not null enable
);

alter table xxcus.xxcmp_questionnaires
    add constraint xxcmp_questionnaires_ck1
        check ( audience in ( 'REQUESTER', 'OFFICER' ) ) enable;

alter table xxcus.xxcmp_questionnaires
    add constraint xxcmp_questionnaires_ck2
        check ( enabled_flag in ( 'Y', 'N' ) ) enable;

alter table xxcus.xxcmp_questionnaires
    add constraint xxcmp_questionnaires_ck3
        check ( low_risk_max_score is null
                or medium_risk_max_score is null
                or medium_risk_max_score >= low_risk_max_score ) enable;

alter table xxcus.xxcmp_questionnaires
    add constraint xxcmp_questionnaires_ck4
        check ( audience = 'REQUESTER'
                or ( low_risk_max_score is null
                     and medium_risk_max_score is null ) ) enable;

alter table xxcus.xxcmp_questionnaires
    add constraint xxcmp_questionnaires_pk primary key ( questionnaire_code )
        using index enable;


-- sqlcl_snapshot {"hash":"7bd1499eb8e8af5d61dd5eb9f2f6a1b90635db76","type":"TABLE","name":"XXCMP_QUESTIONNAIRES","schemaName":"XXCUS","sxml":"\n  <TABLE xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_QUESTIONNAIRES</NAME>\n   <RELATIONAL_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>QUESTIONNAIRE_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>30</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>QUESTIONNAIRE_NAME</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>240</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>AUDIENCE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>20</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LOW_RISK_MAX_SCORE</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>MEDIUM_RISK_MAX_SCORE</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CURRENT_VERSION_NUMBER</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            <DEFAULT>1</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>ENABLED_FLAG</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'Y'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CREATED_BY</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CREATION_DATE</NAME>\n            <DATATYPE>TIMESTAMP</DATATYPE>\n            <SCALE>6</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATED_BY</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATE_DATE</NAME>\n            <DATATYPE>TIMESTAMP</DATATYPE>\n            <SCALE>6</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATE_LOGIN</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>OBJECT_VERSION_NUMBER</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            <DEFAULT>1</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n      </COL_LIST>\n      <CHECK_CONSTRAINT_LIST>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_QUESTIONNAIRES_CK1</NAME>\n            <CONDITION>audience in ('REQUESTER','OFFICER')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_QUESTIONNAIRES_CK2</NAME>\n            <CONDITION>enabled_flag in ('Y','N')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_QUESTIONNAIRES_CK3</NAME>\n            <CONDITION>\n        low_risk_max_score is null or medium_risk_max_score is null or medium_risk_max_score >= low_risk_max_score</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_QUESTIONNAIRES_CK4</NAME>\n            <CONDITION>\n        audience = 'REQUESTER' or (low_risk_max_score is null and medium_risk_max_score is null)</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n      </CHECK_CONSTRAINT_LIST>\n      <PRIMARY_KEY_CONSTRAINT_LIST>\n         <PRIMARY_KEY_CONSTRAINT_LIST_ITEM>\n            <NAME>XXCMP_QUESTIONNAIRES_PK</NAME>\n            <COL_LIST>\n               <COL_LIST_ITEM>\n                  <NAME>QUESTIONNAIRE_CODE</NAME>\n               </COL_LIST_ITEM>\n            </COL_LIST>\n            <USING_INDEX></USING_INDEX>\n         </PRIMARY_KEY_CONSTRAINT_LIST_ITEM>\n      </PRIMARY_KEY_CONSTRAINT_LIST>\n      <DEFAULT_COLLATION>USING_NLS_COMP</DEFAULT_COLLATION>\n      <PHYSICAL_PROPERTIES>\n         <HEAP_TABLE></HEAP_TABLE>\n      </PHYSICAL_PROPERTIES>\n      \n   </RELATIONAL_TABLE>\n</TABLE>"}