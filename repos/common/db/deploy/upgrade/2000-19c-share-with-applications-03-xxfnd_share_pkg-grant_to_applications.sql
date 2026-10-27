
-- every application schema can reach the shared objects (new objects of this release too)
begin
    xxfnd_share_pkg.grant_to_applications;
end;
/
