alter table xxcus.xxcmp_alerts
    add constraint xxcmp_alerts_fk1
        foreign key ( alert_rule_id )
            references xxcus.xxcmp_alert_rules ( alert_rule_id )
        enable;


-- sqlcl_snapshot {"hash":"29bf621e51638f8ed14e7dc3c342fdc846cc23cc","type":"REF_CONSTRAINT","name":"XXCMP_ALERTS_FK1","schemaName":"XXCUS","sxml":""}