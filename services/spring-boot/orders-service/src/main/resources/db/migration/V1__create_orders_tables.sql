create table if not exists orders (
    id bigserial primary key,
    order_number varchar(255) not null,
    customer_email varchar(255) not null,
    status varchar(32) not null,
    total_amount numeric(15, 2) not null,
    currency varchar(5) not null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null
);

create unique index if not exists uk_orders_order_number on orders(order_number);

create table if not exists order_items (
    id bigserial primary key,
    order_id bigint not null references orders(id),
    product_id varchar(255) not null,
    product_name varchar(255) not null,
    unit_price numeric(15, 2) not null,
    quantity integer not null,
    line_total numeric(15, 2) not null
);

create index if not exists idx_order_items_order_id on order_items(order_id);

create table if not exists order_status_history (
    id bigserial primary key,
    order_id bigint not null references orders(id),
    old_status varchar(32),
    new_status varchar(32) not null,
    reason varchar(255),
    changed_at timestamp with time zone not null
);

create index if not exists idx_order_status_history_order_id on order_status_history(order_id);
create index if not exists idx_order_status_history_changed_at on order_status_history(changed_at);
