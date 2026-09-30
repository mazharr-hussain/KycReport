create table xxcus.xxfnd_df_segments (
    descriptive_flexfield_code varchar2(60 byte) not null enable,
    context_code               varchar2(80 byte) not null enable,
    segment_code               varchar2(30 byte) not null enable,
    column_name                varchar2(128 byte) not null enable,
    sequence_number            number(3, 0) not null enable,
    prompt                     varchar2(240 byte) not null enable,
    help_text                  varchar2(1000 byte),
    value_set_code             varchar2(60 byte) not null enable,
    required_flag              varchar2(1 byte) default 'N' not null enable,
    default_type               varchar2(20 byte) default 'NONE' not null enable,
    default_value              varchar2(4000 byte),
    read_only_flag             varchar2(1 byte) default 'N' not null enable,
    display_flag               varchar2(1 byte) default 'Y' not null enable,
    enabled_flag               varchar2(1 byte) default 'Y' not null enable,
    created_by                 varchar2(255 byte) not null enable,
    creation_date              timestamp(6) not null enable,
    last_updated_by            varchar2(255 byte) not null enable,
    last_update_date           timestamp(6) not null enable,
    last_update_login          varchar2(255 byte),
    object_version_number      number default 1 not null enable
);

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck1
        check ( required_flag in ( 'Y', 'N' ) ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck2
        check ( default_type in ( 'NONE', 'CONSTANT', 'SQL' ) ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck3
        check ( read_only_flag in ( 'Y', 'N' ) ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck4
        check ( display_flag in ( 'Y', 'N' ) ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck5
        check ( enabled_flag in ( 'Y', 'N' ) ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck6
        check ( default_type = 'NONE'
                or default_value is not null ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_ck7 check ( regexp_like ( column_name,
                                                               '^ATTRIBUTE([1-9]|[12][0-9]|30)$|^ATTRIBUTE_NUMBER([1-9]|10)$|^ATTRIBUTE_DATE([1-9]|10)$|^ATTRIBUTE_TIMESTAMP[1-5]$'
                                                               ) ) enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_pk
        primary key ( descriptive_flexfield_code,
                      context_code,
                      segment_code )
            using index enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_uk1
        unique ( descriptive_flexfield_code,
                 context_code,
                 column_name )
            using index enable;

alter table xxcus.xxfnd_df_segments
    add constraint xxfnd_df_segments_uk2
        unique ( descriptive_flexfield_code,
                 context_code,
                 sequence_number )
            using index enable;


-- sqlcl_snapshot {"hash":"1e38c8cbd150b4c961986dd63e4b2422a7e85bdb","type":"TABLE","name":"XXFND_DF_SEGMENTS","schemaName":"XXCUS","sxml":"\n  <TABLE xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXFND_DF_SEGMENTS</NAME>\n   <RELATIONAL_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <NAME>DESCRIPTIVE_FLEXFIELD_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>60</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CONTEXT_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>80</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>SEGMENT_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>30</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>COLUMN_NAME</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>128</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>SEQUENCE_NUMBER</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            <PRECISION>3</PRECISION>\n            <SCALE>0</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>PROMPT</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>240</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>HELP_TEXT</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1000</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>VALUE_SET_CODE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>60</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>REQUIRED_FLAG</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'N'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>DEFAULT_TYPE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>20</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'NONE'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>DEFAULT_VALUE</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>4000</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>READ_ONLY_FLAG</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'N'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>DISPLAY_FLAG</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'Y'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>ENABLED_FLAG</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>1</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <DEFAULT>'Y'</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CREATED_BY</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>CREATION_DATE</NAME>\n            <DATATYPE>TIMESTAMP</DATATYPE>\n            <SCALE>6</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATED_BY</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATE_DATE</NAME>\n            <DATATYPE>TIMESTAMP</DATATYPE>\n            <SCALE>6</SCALE>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>LAST_UPDATE_LOGIN</NAME>\n            <DATATYPE>VARCHAR2</DATATYPE>\n            <LENGTH>255</LENGTH>\n            <COLLATE_NAME>USING_NLS_COMP</COLLATE_NAME>\n            \n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <NAME>OBJECT_VERSION_NUMBER</NAME>\n            <DATATYPE>NUMBER</DATATYPE>\n            <DEFAULT>1</DEFAULT>\n            <NOT_NULL></NOT_NULL>\n            \n         </COL_LIST_ITEM>\n      </COL_LIST>\n      <CHECK_CONSTRAINT_LIST>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK1</NAME>\n            <CONDITION>required_flag in ('Y','N')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK2</NAME>\n            <CONDITION>default_type in ('NONE','CONSTANT','SQL')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK3</NAME>\n            <CONDITION>read_only_flag in ('Y','N')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK4</NAME>\n            <CONDITION>display_flag in ('Y','N')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK5</NAME>\n            <CONDITION>enabled_flag in ('Y','N')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK6</NAME>\n            <CONDITION>default_type = 'NONE' or default_value is not null</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n         <CHECK_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_CK7</NAME>\n            <CONDITION>regexp_like(column_name,\n        '^ATTRIBUTE([1-9]|[12][0-9]|30)$|^ATTRIBUTE_NUMBER([1-9]|10)$|^ATTRIBUTE_DATE([1-9]|10)$|^ATTRIBUTE_TIMESTAMP[1-5]$')</CONDITION>\n         </CHECK_CONSTRAINT_LIST_ITEM>\n      </CHECK_CONSTRAINT_LIST>\n      <PRIMARY_KEY_CONSTRAINT_LIST>\n         <PRIMARY_KEY_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_PK</NAME>\n            <COL_LIST>\n               <COL_LIST_ITEM>\n                  <NAME>DESCRIPTIVE_FLEXFIELD_CODE</NAME>\n               </COL_LIST_ITEM>\n               <COL_LIST_ITEM>\n                  <NAME>CONTEXT_CODE</NAME>\n               </COL_LIST_ITEM>\n               <COL_LIST_ITEM>\n                  <NAME>SEGMENT_CODE</NAME>\n               </COL_LIST_ITEM>\n            </COL_LIST>\n            <USING_INDEX></USING_INDEX>\n         </PRIMARY_KEY_CONSTRAINT_LIST_ITEM>\n      </PRIMARY_KEY_CONSTRAINT_LIST>\n      <UNIQUE_KEY_CONSTRAINT_LIST>\n         <UNIQUE_KEY_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_UK1</NAME>\n            <COL_LIST>\n               <COL_LIST_ITEM>\n                  <NAME>DESCRIPTIVE_FLEXFIELD_CODE</NAME>\n               </COL_LIST_ITEM>\n               <COL_LIST_ITEM>\n                  <NAME>CONTEXT_CODE</NAME>\n               </COL_LIST_ITEM>\n               <COL_LIST_ITEM>\n                  <NAME>COLUMN_NAME</NAME>\n               </COL_LIST_ITEM>\n            </COL_LIST>\n            <USING_INDEX></USING_INDEX>\n         </UNIQUE_KEY_CONSTRAINT_LIST_ITEM>\n         <UNIQUE_KEY_CONSTRAINT_LIST_ITEM>\n            <NAME>XXFND_DF_SEGMENTS_UK2</NAME>\n            <COL_LIST>\n               <COL_LIST_ITEM>\n                  <NAME>DESCRIPTIVE_FLEXFIELD_CODE</NAME>\n               </COL_LIST_ITEM>\n               <COL_LIST_ITEM>\n                  <NAME>CONTEXT_CODE</NAME>\n               </COL_LIST_ITEM>\n               <COL_LIST_ITEM>\n                  <NAME>SEQUENCE_NUMBER</NAME>\n               </COL_LIST_ITEM>\n            </COL_LIST>\n            <USING_INDEX></USING_INDEX>\n         </UNIQUE_KEY_CONSTRAINT_LIST_ITEM>\n      </UNIQUE_KEY_CONSTRAINT_LIST>\n      <DEFAULT_COLLATION>USING_NLS_COMP</DEFAULT_COLLATION>\n      <PHYSICAL_PROPERTIES>\n         <HEAP_TABLE></HEAP_TABLE>\n      </PHYSICAL_PROPERTIES>\n      \n   </RELATIONAL_TABLE>\n</TABLE>"}