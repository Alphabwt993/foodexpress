create or replace
function rating_change() returns trigger as $$
begin
    if tg_op = 'delete' then
        if old.entity_type = 'блюдо' then
            update
	product
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'блюдо'
		and entity_id = old.entity_id)
where
	product_id = old.entity_id;

elsif old.entity_type = 'ресторан' then
            update
	restaurant
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'ресторан'
		and entity_id = old.entity_id)
where
	restaurant_id = old.entity_id;
end if;

return old;

elsif tg_op = 'insert' then
        if new.entity_type = 'блюдо' then
            update
	product
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'блюдо'
		and entity_id = new.entity_id)
where
	product_id = new.entity_id;

elsif new.entity_type = 'ресторан' then
            update
	restaurant
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'ресторан'
		and entity_id = new.entity_id)
where
	restaurant_id = new.entity_id;
end if;

return new;

elsif tg_op = 'update' then
        if old.entity_type = 'блюдо' then
            update
	product
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'блюдо'
		and entity_id = old.entity_id)
where
	product_id = old.entity_id;

elsif old.entity_type = 'ресторан' then
            update
	restaurant
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'ресторан'
		and entity_id = old.entity_id)
where
	restaurant_id = old.entity_id;
end if;

if new.entity_type = 'блюдо' then
            update
	product
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'блюдо'
		and entity_id = new.entity_id)
where
	product_id = new.entity_id;

elsif new.entity_type = 'ресторан' then
            update
	restaurant
set
	rating = (
	select
		round(avg(rating), 2)
	from
		review
	where
		entity_type = 'ресторан'
		and entity_id = new.entity_id)
where
	restaurant_id = new.entity_id;
end if;

return new;
end if;

return null;
end;

$$ language plpgsql;

create or replace
function validate_review() returns trigger as $$
declare
    v_order_restaurant_id uuid;

v_client_id uuid;

begin
    select
	restaurant_id,
	client_id
into
	v_order_restaurant_id,
	v_client_id
from
	"order"
where
	order_id = new.order_id;

if new.client_id != v_client_id then
        raise exception 'клиент % не соответствует заказу % (клиент заказа: %)',
new.client_id,
new.order_id,
v_client_id;
end if;

if new.entity_type = 'блюдо' then
        if not exists (
select
	1
from
	order_structure os
where
	os.order_id = new.order_id
	and os.product_id = new.entity_id) then
            raise exception 'блюдо % отсутствует в заказе %',
new.entity_id,
new.order_id;
end if;

elsif new.entity_type = 'ресторан' then
        if new.entity_id != v_order_restaurant_id then
            raise exception 'ресторан % не соответствует ресторану заказа %',
new.entity_id,
v_order_restaurant_id;
end if;

elsif new.entity_type = 'заказ' then
        if new.entity_id != new.order_id then
            raise exception 'entity_id % должен совпадать с order_id %',
new.entity_id,
new.order_id;
end if;
end if;

return new;
end;

$$ language plpgsql;

create trigger trg_validate_review
before
insert
	or
update
	on
	review
for each row execute function validate_review();

create or replace
function check_payment_amount() returns trigger as $$
declare
    v_total_amount numeric(9, 2);

begin
    select
	total_amount
into
	v_total_amount
from
	"order"
where
	order_id = new.order_id;

if new.amount != v_total_amount then
        raise exception 'сумма платежа % не равна total_amount заказа %',
new.amount,
v_total_amount;
end if;

return new;
end;

$$ language plpgsql;

create trigger trg_check_payment_amount
before
insert
	or
update
	on
	payment
for each row execute function check_payment_amount();

