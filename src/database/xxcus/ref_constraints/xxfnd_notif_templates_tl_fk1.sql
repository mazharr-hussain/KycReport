alter table xxcus.xxfnd_notification_templates_tl
    add constraint xxfnd_notif_templates_tl_fk1
        foreign key ( template_code )
            references xxcus.xxfnd_notification_templates ( template_code )
                on delete cascade
        enable;


-- sqlcl_snapshot {"hash":"c920a47a52157d0ad1b6ca33f8ecbcf8967cdee5","type":"REF_CONSTRAINT","name":"XXFND_NOTIF_TEMPLATES_TL_FK1","schemaName":"XXCUS","sxml":""}