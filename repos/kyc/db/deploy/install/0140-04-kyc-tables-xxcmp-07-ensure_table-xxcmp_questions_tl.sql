
begin
    xxfnd_ddl_pkg.ensure_table('XXCMP_QUESTIONS_TL', q'~create table xxcmp_questions_tl (
    question_id            number         not null,
    language_code          varchar2(10)   not null,
    question_text          varchar2(2000) not null,
    section_name           varchar2(240),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxcmp_questions_tl_pk primary key (question_id, language_code),
    constraint xxcmp_questions_tl_fk1 foreign key (question_id) references xxcmp_questions (question_id) on delete cascade
)~');
end;
/
