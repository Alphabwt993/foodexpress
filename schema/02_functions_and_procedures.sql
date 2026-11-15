create or replace
procedure add_product(
    p_restaurant_id uuid,
    p_product_category_id uuid,
    p_name varchar,
    p_price numeric,
    p_rating numeric,
    p_status product_status,
    p_description text,
    p_photo_url text default null
)
language plpgsql as $$
begin
    if not exists (
select
	1
from
	restaurant
where
	restaurant_id = p_restaurant_id) then
        raise exception 'ресторан с id % не существует',
p_restaurant_id;
end if;

if not exists (
select
	1
from
	product_category
where
	product_category_id = p_product_category_id) then
        raise exception 'категория с id % не существует',
p_product_category_id;
end if;

insert
	into
	product (product_id,
	product_name,
	product_category_id,
	price,
	restaurant_id,
	photo_url,
	rating,
	status,
	description)
values (exts.uuid_generate_v4(),
p_name,
p_product_category_id,
p_price,
p_restaurant_id,
p_photo_url,
p_rating,
p_status,
p_description);
end;

$$;

create or replace
function get_statistic()
returns table (
    restaurant_name varchar,
    best_product_name varchar,
    total_amount numeric,
    avg_amount numeric,
    best_user varchar
)
language plpgsql as $$
begin
    return query
    with order_stats as (
select
	o.restaurant_id,
	sum(o.total_amount) as total_amount,
	avg(o.total_amount) as avg_amount
from
	"order" o
where
	o.status = 'доставлен'
group by
	o.restaurant_id
    ),
    product_sales as (
select
	o.restaurant_id,
	p.product_name,
	sum(os.quantity) as total_quantity
from
	"order" o
join order_structure os on
	o.order_id = os.order_id
join product p on
	os.product_id = p.product_id
where
	o.status = 'доставлен'
group by
	o.restaurant_id,
	p.product_id,
	p.product_name
    ),
    best_product as (
select
	distinct on
	(restaurant_id) restaurant_id,
	product_name
from
	product_sales
order by
	restaurant_id,
	total_quantity desc
    ),
    client_orders as (
select
	o.restaurant_id,
	c.login,
	count(*) as order_count
from
	"order" o
join client c on
	o.client_id = c.client_id
where
	o.status = 'доставлен'
group by
	o.restaurant_id,
	c.client_id,
	c.login
    ),
    best_client as (
select
	distinct on
	(restaurant_id) restaurant_id,
	login
from
	client_orders
order by
	restaurant_id,
	order_count desc
    )
    select
	r.restaurant_name,
	bp.product_name,
	os.total_amount,
	os.avg_amount,
	bc.login
from
	restaurant r
left join order_stats os on
	r.restaurant_id = os.restaurant_id
left join best_product bp on
	r.restaurant_id = bp.restaurant_id
left join best_client bc on
	r.restaurant_id = bc.restaurant_id;
end;

$$;

create or replace
procedure courier_salary()
language plpgsql as $$
declare
    v_year int := extract(year from current_date);

v_month int := extract(month from current_date);

r record;

v_delivery_count int;

v_commission_sum numeric;

v_amount numeric;

v_new_coefficient numeric(2, 1);

begin
    for r in
select
	courier_id,
	coefficient,
	status
from
	courier loop
        select
	count(*),
	coalesce(sum(commission), 0)
        into
	v_delivery_count,
	v_commission_sum
from
	"order"
where
	courier_id = r.courier_id
	and status = 'доставлен'
	and extract(year from order_timestamp) = v_year
	and extract(month from order_timestamp) = v_month;

v_amount := r.coefficient * v_commission_sum;

insert
	into
	courier_pay (year,
	month,
	courier_id,
	amount,
	coefficient_used)
values (v_year,
v_month,
r.courier_id,
v_amount,
r.coefficient)
        on
conflict (year,
month,
courier_id)
        do
update
set
	amount = excluded.amount,
	coefficient_used = excluded.coefficient_used;

if v_delivery_count <= 150 then v_new_coefficient := 0.1;

elsif v_delivery_count <= 250 then v_new_coefficient := 0.2;

elsif v_delivery_count <= 500 then v_new_coefficient := 0.3;
else v_new_coefficient := 0.5;
end if;

if r.status != 'уволен' then
            update
	courier
set
	coefficient = v_new_coefficient
where
	courier_id = r.courier_id;
end if;
end loop;
end;

$$;

