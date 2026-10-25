
-- RFIs are looked up by recipient (requesters' data security, their document downloads, the home page).
create index if not exists xxcmp_rfis_n2 on xxcmp_rfis (upper(recipient_user_name));
