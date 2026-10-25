
begin
    if xxfnd_ddl_pkg.create_table('XXFND_ATTACHMENT_BLOCKS', q'~create table xxfnd_attachment_blocks (
    function_code          varchar2(60)   not null,
    block_code             varchar2(60)   not null,
    region_static_id       varchar2(255)  not null,
    block_name             varchar2(240),
    display_sequence       number,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_att_blocks_pk primary key (function_code, block_code),
    constraint xxfnd_att_blocks_fk1 foreign key (function_code)
        references xxfnd_attachment_functions (function_code) on delete cascade,
    constraint xxfnd_att_blocks_uk1 unique (function_code, region_static_id)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_attachment_blocks is 'A region on the page (FND_ATTACHMENT_BLOCKS), identified by its static ID.'~');
    end if;
end;
/
