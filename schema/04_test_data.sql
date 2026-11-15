-- Очистка данных
create or replace
procedure erase_test_data()
language plpgsql as $$
begin
    truncate
	table review,
	payment,
	order_structure,
	"order",
	product,
	restaurant,
	client_address,
	client,
	courier_pay,
	courier,
	product_category,
	address cascade;
end;

$$;

-- Генерация тестовых данных
create or replace
procedure insert_test_data(value int)
language plpgsql as $$
declare
-- массивы для хранения id
v_clients uuid[] := array[]::uuid[];

v_couriers uuid[] := array[]::uuid[];

v_categories uuid[] := array[]::uuid[];

v_restaurant_addresses uuid[] := array[]::uuid[];

v_client_addresses uuid[] := array[]::uuid[];

v_restaurants uuid[] := array[]::uuid[];

v_orders uuid[] := array[]::uuid[];

v_order_restaurants uuid[] := array[]::uuid[];

v_order_clients uuid[] := array[]::uuid[];

v_order_totals numeric[] := array[]::numeric[];
-- рабочие переменные
v_id uuid;

v_idx int;

v_rand_int int;

v_price numeric;

v_now timestamp := localtimestamp;
-- сборка заказа
v_selected_products uuid[];

v_selected_quantities numeric[];

v_selected_prices numeric[];

v_product_count int;

v_order_amount numeric;

v_commission numeric;

v_total numeric;

v_factor numeric;
-- метаданные заказа
v_order_ts timestamp;

v_delivery_ts timestamp;

v_order_status order_status;

v_pay_type payment_type;

v_payment_status payment_status;

v_review_type review_entity_type;

v_review_entity uuid;
-- рабочие часы ресторана
v_work_start time;

v_work_end time;
-- курьеры и выплаты
v_month_start date;

v_sum_commission numeric;

v_pay_amount numeric;

v_delivery_count int;

v_new_coefficient numeric;

v_cur_coefficient numeric;
-- платежи
v_success_count int;

v_error_count int;

v_processing_count int;

i int;

j int;

k int;

begin
    if value < 1 then
        raise exception 'insert_test_data: value must be >= 1 (got %)',
value;
end if;
-- ============================================================
-- 1. product_category 
-- ============================================================
    for i in 1.. value loop
        insert
	into
	product_category (product_category_id,
	product_category_name)
values (exts.uuid_generate_v4(),
                'category_' || nextval('ponomarenko_food.test_data_seq'))
        returning product_category_id
into
	v_id;

v_categories := array_append(v_categories, v_id);
end loop;
-- ============================================================
-- 2. courier 
-- ============================================================
    for i in 1.. value loop
        insert
	into
	courier (courier_id,
	last_name,
	first_name,
	middle_name,
	phone_number,
	status,
	hire_date,
	dismissal_date,
	coefficient)
values (exts.uuid_generate_v4(),
                'last_' || nextval('ponomarenko_food.test_data_seq'),
                'first_' || nextval('ponomarenko_food.test_data_seq'),
                'middle_' || nextval('ponomarenko_food.test_data_seq'),
                '+7' || lpad(nextval('ponomarenko_food.test_data_seq')::text, 10, '0'),
                (enum_range(null::courier_status))[1 + floor(random() * (cardinality(enum_range(null::courier_status)) - 1))::int],
                current_date - 180 - floor(random() * 180)::int,
                null,
--round((0.1 + random() * 0.4)::numeric, 1))
				(floor(random() * 5) + 1) * 0.1)
        returning courier_id
into
	v_id;

v_couriers := array_append(v_couriers, v_id);
end loop;
-- ============================================================
-- 3. address 
-- ============================================================
    for i in 1.. value loop
        insert
	into
	address (address_id,
	street,
	house_number,
	apartment_office)
values (exts.uuid_generate_v4(),
                'reststreet_' || nextval('ponomarenko_food.test_data_seq'),
                'house_' || i,
                null)
        returning address_id
into
	v_id;

v_restaurant_addresses := array_append(v_restaurant_addresses, v_id);
end loop;

for i in 1..(value * 4) loop
        insert
	into
	address (address_id,
	street,
	house_number,
	apartment_office)
values (exts.uuid_generate_v4(),
                'clientstreet_' || nextval('ponomarenko_food.test_data_seq'),
                'house_' || i,
                case
	when random() < 0.5 then null
	else 'apt_' || i
end)
        returning address_id
into
	v_id;

v_client_addresses := array_append(v_client_addresses, v_id);
end loop;
-- ============================================================
-- 4. restaurant 
-- ============================================================
    for i in 1.. value loop
        v_work_start := make_time(8 + floor(random() * 4)::int, 0, 0);

v_work_end := make_time(18 + floor(random() * 5)::int, 0, 0);

insert
	into
	restaurant (
            restaurant_id,
	restaurant_name,
	address_id,
	description,
	work_start,
	work_end,
	inn,
	ogrn,
	settlement_account,
	rating,
	status)
values (exts.uuid_generate_v4(),
                'restaurant_' || nextval('ponomarenko_food.test_data_seq'),
                v_restaurant_addresses[i],
                'description for restaurant ' || i,
                v_work_start,
v_work_end,
                lpad((100000000000 + floor(random() * 900000000000)::bigint)::text, 12, '0'),
                lpad((100000000000000 + floor(random() * 900000000000000)::bigint)::text, 15, '0'),
                lpad((40000000000000000000 + floor(random() * 9000000000000000000)::bigint)::text, 20, '0'),
                null,
-- генерация случайного статуса (активен / неактивен)
                (enum_range(null::restaurant_status))[1 + floor(random() * (cardinality(enum_range(null::restaurant_status)) - 1))::int])
        returning restaurant_id
into
	v_id;

v_restaurants := array_append(v_restaurants, v_id);
end loop;
-- ============================================================
-- 5. client 
-- ============================================================
    for i in 1.. value loop
        insert
	into
	client (client_id,
	login,
	password,
	phone_number)
values (exts.uuid_generate_v4(),
                'client_' || nextval('ponomarenko_food.test_data_seq'),
                md5(random()::text),
                '+7' || lpad(nextval('ponomarenko_food.test_data_seq')::text, 10, '0'))
        returning client_id
into
	v_id;

v_clients := array_append(v_clients, v_id);
end loop;
-- ============================================================
-- 6. client_address
-- ============================================================
    for i in 1.. value loop
        for j in 1..4 loop
            insert
	into
	client_address (client_id,
	address_id)
values (v_clients[i],
v_client_addresses[(i - 1) * 4 + j])
            on
conflict do nothing;
end loop;
end loop;
-- ============================================================
-- 7. product (value*5)
-- ============================================================
    for i in 1..(value * 5) loop
        v_idx := ((i - 1) % value) + 1;

insert
	into
	product (
            product_id,
	product_name,
	product_category_id,
	price,
	restaurant_id,
	photo_url,
	rating,
	status,
	description)
values (exts.uuid_generate_v4(),
                'product_' || nextval('ponomarenko_food.test_data_seq'),
                v_categories[1 + floor(random() * array_length(v_categories, 1))::int],
                round((100 + random() * 1000)::numeric, 2),
                v_restaurants[v_idx],
                case
	when random() < 0.5 then null
	else 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
end,
                null,
                (enum_range(null::product_status))[1 + floor(random() * (cardinality(enum_range(null::product_status)) - 1))::int],
                'description for product ' || i);
end loop;
-- ============================================================
-- 8. order (value*5) + order_structure
-- ============================================================
    for i in 1..(value * 5) loop
        declare
            v_client uuid := v_clients[1 + floor(random() * array_length(v_clients, 1))::int];

v_restaurant uuid := v_restaurants[1 + floor(random() * array_length(v_restaurants, 1))::int];

v_courier uuid := v_couriers[1 + floor(random() * array_length(v_couriers, 1))::int];

v_address uuid;

begin
            select
	address_id
into
	v_address
from
	client_address
where
	client_id = v_client
order by
	random()
limit 1;

v_selected_products := array[]::uuid[];

v_selected_quantities := array[]::numeric[];

v_selected_prices := array[]::numeric[];

v_product_count := 1 + floor(random() * 5)::int;

for j in 1.. v_product_count loop
                select
	p.product_id,
	p.price
into
	v_id,
	v_price
from
	product p
where
	p.restaurant_id = v_restaurant
	and p.product_id <> all (v_selected_products)
order by
	random()
limit 1;

exit
when v_id is null;

v_selected_products := array_append(v_selected_products, v_id);

v_selected_prices := array_append(v_selected_prices, v_price);

v_selected_quantities := array_append(v_selected_quantities, round((1 + random() * 2)::numeric, 2));
end loop;

if coalesce(array_length(v_selected_products, 1), 0) = 0 then
                raise exception 'no products for restaurant % — невозможно создать заказ',
v_restaurant;
end if;

v_order_amount := 0;

for j in 1.. array_length(v_selected_products, 1) loop
                v_order_amount := v_order_amount + v_selected_quantities[j] * v_selected_prices[j];
end loop;

v_order_amount := round(v_order_amount, 2);

if v_order_amount < 1000 then
                v_factor := ceil(1000 / v_order_amount) + 1;

for j in 1.. array_length(v_selected_quantities, 1) loop
                    v_selected_quantities[j] := v_selected_quantities[j] * v_factor;
end loop;

v_order_amount := 0;

for j in 1.. array_length(v_selected_products, 1) loop
                    v_order_amount := v_order_amount + v_selected_quantities[j] * v_selected_prices[j];
end loop;

v_order_amount := round(v_order_amount, 2);
end if;

v_commission := round(v_order_amount * 0.10, 2);

v_total := v_order_amount + v_commission;
-- дата заказа: последние 180 дней
v_order_ts := v_now - make_interval(days => floor(random() * 180)::int)
                                - make_interval(secs => floor(random() * 86400)::int);
-- случайный статус заказа         
v_order_status := (enum_range(null::order_status))[
                1 + floor(random() * (cardinality(enum_range(null::order_status)) - 1))::int
            ];
-- если доставлен — ставим время окончания доставки
            if v_order_status = 'доставлен'::order_status then
                v_delivery_ts := v_order_ts + make_interval(hours => (1 + floor(random() * 5)::int));
else
                v_delivery_ts := null;
end if;

v_id := exts.uuid_generate_v4();
-- по умолчанию статус ожидает, обновим его после генерации платежей
            insert
	into
	"order" (
                order_id,
	courier_id,
	client_id,
	address_id,
	restaurant_id,
	order_timestamp,
	delivery_timestamp,
	order_amount,
	commission,
	total_amount,
	status,
	pay_status,
	description)
values (
                v_id,
v_courier,
v_client,
v_address,
v_restaurant,
                v_order_ts,
v_delivery_ts,
                v_order_amount,
v_commission,
v_total,
                v_order_status,
'ожидает'::pay_status,
                'order ' || i);

for j in 1.. array_length(v_selected_products, 1) loop
                insert
	into
	order_structure (order_id,
	product_id,
	restaurant_id,
	quantity)
values (v_id,
v_selected_products[j],
v_restaurant,
v_selected_quantities[j]);
end loop;

v_orders := array_append(v_orders, v_id);

v_order_restaurants := array_append(v_order_restaurants, v_restaurant);

v_order_clients := array_append(v_order_clients, v_client);

v_order_totals := array_append(v_order_totals, v_total);
end;
end loop;
-- ============================================================
-- 9. payment 
-- ============================================================
      for i in 1..(value * 5) loop
-- 1. получаем случайный статус из enum_range (строго по тз)
v_payment_status := (enum_range(null::payment_status))[
            1 + floor(random() * (cardinality(enum_range(null::payment_status)) - 1))::int
        ];
-- 2. вставляем ровно один платеж
        insert
	into
	payment (payment_id,
	order_id,
	payment_type,
	amount,
	transaction_id,
	transaction_timestamp,
	status)
values (exts.uuid_generate_v4(),
                v_orders[i],
                (enum_range(null::payment_type))[1 + floor(random() * (cardinality(enum_range(null::payment_type)) - 1))::int],
                v_order_totals[i],
                'txn_' || nextval('ponomarenko_food.test_data_seq'),
                v_now,
                v_payment_status);
-- 3. обновляем статус оплаты заказа (br-8.7)
        if v_payment_status = 'успех'::payment_status then
            update
	"order"
set
	pay_status = 'оплачен'
where
	order_id = v_orders[i];

elsif v_payment_status = 'в_обработке'::payment_status then
            update
	"order"
set
	pay_status = 'ожидает'
where
	order_id = v_orders[i];
else
            update
	"order"
set
	pay_status = 'ошибка'
where
	order_id = v_orders[i];
end if;
end loop;
-- ============================================================
-- 10. review
-- ============================================================
    for i in 1..(value * 5) loop
-- 1. выбираем тип сущности через enum_range 
v_review_type := (enum_range(null::review_entity_type))[
            1 + floor(random() * (cardinality(enum_range(null::review_entity_type)) - 1))::int
        ];
-- 2. в зависимости от типа определяем entity_id
        case
	v_review_type
            when 'блюдо'::review_entity_type then
                select
	product_id
into
	v_review_entity
from
	order_structure
where
	order_id = v_orders[i]
order by
	random()
limit 1;
when 'ресторан'::review_entity_type then
                v_review_entity := v_order_restaurants[i];
when 'заказ'::review_entity_type then
                v_review_entity := v_orders[i];
end case;

insert
	into
	review (
            review_id,
	client_id,
	review_timestamp,
	entity_id,
	entity_type,
	order_id,
	description,
	photo_url,
	rating)
values (
            exts.uuid_generate_v4(),
            v_order_clients[i],
            v_now - make_interval(days => floor(random() * 180)::int),
            v_review_entity,
v_review_type,
v_orders[i],
            'review text ' || i,
            case
	when random() < 0.5 then null
	else 'https://cdn.foodexpress.ru/review/' || md5(random()::text) || '.jpg'
end,
            1 + floor(random() * 5)::int);
end loop;
-- ============================================================
-- 11. courier_pay и обновление коэффициентов
-- ============================================================
    for v_month_start in
        select
	generate_series(
            date_trunc('month', current_date - interval '5 months')::date,
            date_trunc('month', current_date)::date,
            interval '1 month'
        )::date
    loop
        for i in 1.. array_length(v_couriers, 1) loop
            select
	count(*),
	coalesce(sum(o.commission), 0)
            into
	v_delivery_count,
	v_sum_commission
from
	"order" o
where
	o.courier_id = v_couriers[i]
	and o.status = 'доставлен'
	and date_trunc('month', o.order_timestamp)::date = v_month_start;

select
	coefficient
into
	v_cur_coefficient
from
	courier
where
	courier_id = v_couriers[i];

v_pay_amount := round(v_cur_coefficient * v_sum_commission, 2);

insert
	into
	courier_pay (year,
	month,
	courier_id,
	amount,
	coefficient_used)
values (
                extract(year from v_month_start)::int,
                extract(month from v_month_start)::int,
                v_couriers[i],
                v_pay_amount,
                v_cur_coefficient)
            on
conflict (year,
month,
courier_id) do
update
set
	amount = excluded.amount,
	coefficient_used = excluded.coefficient_used;

if v_delivery_count <= 150 then v_new_coefficient := 0.1;

elsif v_delivery_count <= 250 then v_new_coefficient := 0.2;

elsif v_delivery_count <= 500 then v_new_coefficient := 0.3;
else v_new_coefficient := 0.5;
end if;

update
	courier
set
	coefficient = v_new_coefficient
where
	courier_id = v_couriers[i];
end loop;
end loop;
end;

$$;
