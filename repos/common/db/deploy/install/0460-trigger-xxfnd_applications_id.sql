
create or replace trigger xxfnd_applications_id
before update of application_id on xxfnd_applications
for each row
when (new.application_id <> old.application_id)
begin
    raise_application_error(-20051, 'The application ID ' || :old.application_id || ' cannot be changed.');
end;
/
