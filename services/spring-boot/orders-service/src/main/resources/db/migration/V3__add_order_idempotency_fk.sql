do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'fk_order_idempotency_order'
    ) then
        alter table order_idempotency
            add constraint fk_order_idempotency_order
            foreign key (order_id) references orders(id);
    end if;
end $$;
