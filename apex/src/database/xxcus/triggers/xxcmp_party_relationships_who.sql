create or replace editionable trigger xxcus.xxcmp_party_relationships_who before
    insert or update on xxcus.xxcmp_party_relationships
    for each row
begin
    if inserting then
        :new.created_by := nvl(:new.created_by,
                               xxfnd_util_pkg.current_user);
        :new.creation_date := nvl(:new.creation_date,
                                  systimestamp);
        :new.object_version_number := 1;
    else
        :new.created_by := :old.created_by;
        :new.creation_date := :old.creation_date;
        :new.object_version_number := nvl(:old.object_version_number,
                                          0) + 1;
    end if;

    :new.last_updated_by := xxfnd_util_pkg.current_user;
    :new.last_update_date := systimestamp;
    :new.last_update_login := sys_context('APEX$SESSION', 'APP_SESSION');
end;
/

alter trigger xxcus.xxcmp_party_relationships_who enable;


-- sqlcl_snapshot {"hash":"11453efcea7aedd14a3beee2f9acc5f3106bbd11","type":"TRIGGER","name":"XXCMP_PARTY_RELATIONSHIPS_WHO","schemaName":"XXCUS","sxml":""}