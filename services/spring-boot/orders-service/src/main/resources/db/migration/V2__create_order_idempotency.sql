create table if not exists order_idempotency (
    id bigserial primary key,
    idempotency_key varchar(255) not null unique,
    request_hash varchar(64) not null,
    order_id bigint not null,
    created_at timestamp with time zone not null
);

create index if not exists idx_order_idempotency_order_id on order_idempotency(order_id);
