alter table order_idempotency
    add constraint fk_order_idempotency_order
    foreign key (order_id) references orders(id);
