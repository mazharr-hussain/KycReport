
create table if not exists xxfnd_feature_pages (
    app_alias              varchar2(255)  not null,
    page_id                number         not null,
    feature_code           varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_feature_pages_pk primary key (app_alias, page_id),
    constraint xxfnd_feature_pages_fk1 foreign key (feature_code) references xxfnd_features (feature_code)
);
comment on table xxfnd_feature_pages is 'Which feature an APEX page belongs to. Page authorization checks the privilege of this feature.';
