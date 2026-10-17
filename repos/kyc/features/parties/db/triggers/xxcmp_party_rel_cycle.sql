
--==============================================================================
-- Ownership cycles (A owns B owns C owns A) are rejected. Checked after the
-- statement because the check reads the table being changed.
--==============================================================================
create or replace trigger xxcmp_party_rel_cycle
    for insert or update of subject_party_id, object_party_id, end_date on xxcmp_party_relationships
    compound trigger

    type t_pair is record (subject_id number, object_id number);
    type t_pairs is table of t_pair index by pls_integer;
    g_pairs t_pairs;

    after each row is
        l_pair t_pair;
    begin
        l_pair.subject_id := :new.subject_party_id;
        l_pair.object_id  := :new.object_party_id;
        g_pairs(g_pairs.count + 1) := l_pair;
    end after each row;

    after statement is
        l_count pls_integer;
    begin
        for i in 1 .. g_pairs.count loop
            select count(*) into l_count
              from (select r.object_party_id
                      from xxcmp_party_relationships r
                     where r.end_date is null or r.end_date >= trunc(sysdate)
                     start with r.subject_party_id = g_pairs(i).object_id
                   connect by nocycle prior r.object_party_id = r.subject_party_id
                          and (r.end_date is null or r.end_date >= trunc(sysdate)))
             where object_party_id = g_pairs(i).subject_id;
            if l_count > 0 then
                g_pairs.delete;
                raise_application_error(-20500, 'This relationship would create an ownership loop.');
            end if;
        end loop;
        g_pairs.delete;
    end after statement;
end xxcmp_party_rel_cycle;
/
