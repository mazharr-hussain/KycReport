create unique index xxcus.xxcmp_party_contacts_u1 on
    xxcus.xxcmp_party_contacts (
        case
            primary_flag
            when 'Y' then
                    party_id
        end,
        case
            primary_flag
            when 'Y' then
                    contact_type
        end
    );


-- sqlcl_snapshot {"hash":"4cf6f390ae9a58ba78118488cdae8bd3b47a7e42","type":"INDEX","name":"XXCMP_PARTY_CONTACTS_U1","schemaName":"XXCUS","sxml":"\n  <INDEX xmlns=\"http://xmlns.oracle.com/ku\" version=\"1.0\">\n   <UNIQUE></UNIQUE>\n   <SCHEMA>XXCUS</SCHEMA>\n   <NAME>XXCMP_PARTY_CONTACTS_U1</NAME>\n   <TABLE_INDEX>\n      <ON_TABLE>\n         <SCHEMA>XXCUS</SCHEMA>\n         <NAME>XXCMP_PARTY_CONTACTS</NAME>\n      </ON_TABLE>\n      <COL_LIST>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>CASE \"PRIMARY_FLAG\" WHEN 'Y' THEN \"PARTY_ID\" END </DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n         <COL_LIST_ITEM>\n            <DEFAULT_EXPRESSION>CASE \"PRIMARY_FLAG\" WHEN 'Y' THEN \"CONTACT_TYPE\" END </DEFAULT_EXPRESSION>\n         </COL_LIST_ITEM>\n      </COL_LIST>\n      \n   </TABLE_INDEX>\n</INDEX>"}