create or replace editionable trigger xxcus.xxcmp_rfis_who before
    insert or update on xxcus.xxcmp_rfis
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

alter trigger xxcus.xxcmp_rfis_who enable;


-- sqlcl_snapshot {"hash":"a80de7a24b9e99b9ddc2658db9d696d7750f87b2","type":"TRIGGER","name":"XXCMP_RFIS_WHO","schemaName":"XXCUS","sxml":""}