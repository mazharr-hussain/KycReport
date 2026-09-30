create or replace editionable trigger xxcus.xxcmp_approval_matrix_who before
    insert or update on xxcus.xxcmp_approval_matrix
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

alter trigger xxcus.xxcmp_approval_matrix_who enable;


-- sqlcl_snapshot {"hash":"f911cd1b9d953d41f5cdf7559dee1e599b2fd678","type":"TRIGGER","name":"XXCMP_APPROVAL_MATRIX_WHO","schemaName":"XXCUS","sxml":""}