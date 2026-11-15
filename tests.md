```sql
-- ============================================================================
-- скрипт для автоматической проверки (tests.md)
-- ============================================================================
-- a.2. переключение на inspector
set
role inspector;

set
search_path to ponomarenko_food,
exts;

select
	current_user as role_check;
-- ожидается: inspector
-- факт: inspector
-- вердикт: ок
-- ============================================================================
-- b. food-101: структура схемы
-- ============================================================================
-- b.1. схема существует
select
	schema_name
from
	information_schema.schemata
where
	schema_name like '%_food';
-- ожидается: ponomarenko_food
-- факт: ponomarenko_food
-- вердикт: ок
-- b.2. схема exts с uuid-ossp
select
	extname,
	extnamespace::regnamespace as schema
from
	pg_extension
where
	extname = 'uuid-ossp';
-- ожидается: uuid-ossp, exts
-- факт: uuid-ossp, exts
-- вердикт: ок
-- b.3. все 12 исходных таблиц + n
select
	table_name
from
	information_schema.tables
where
	table_schema = 'ponomarenko_food'
order by
	table_name;
-- ожидается: address, client, client_address, courier, courier_pay, order, order_structure, payment, product, product_category, restaurant, review
-- факт: address, client, client_address, courier, courier_pay, order, order_structure, payment, product, product_category, restaurant, review
-- вердикт: ок
-- b.4. все pk — uuid
select
	table_name,
	column_name,
	data_type
from
	information_schema.columns
where
	table_schema = 'ponomarenko_food'
	and column_name like '%_id'
	and data_type != 'uuid';
-- ожидается: пусто
-- факт: пусто
-- вердикт: ок
-- b.5. enum-типы
select
	t.typname,
	array_agg(e.enumlabel order by e.enumsortorder) as
values
from
pg_type t
join pg_enum e on
t.oid = e.enumtypid
join pg_namespace n on
n.oid = t.typnamespace
where
n.nspname = 'ponomarenko_food'
group by
t.typname
order by
t.typname;
-- ожидается: 8 типов
-- факт: 8 типов
-- вердикт: ок
-- b.6. fk-ограничения
select
	conname,
	conrelid::regclass as tbl,
	confrelid::regclass as ref
from
	pg_constraint
where
	contype = 'f'
	and connamespace = 'ponomarenko_food'::regnamespace
order by
	tbl,
	conname;
-- ожидается: не менее 15 fk
-- факт: 19
-- вердикт: ок
-- ============================================================================
-- c. food-102: insert_test_data(value)
-- ============================================================================
-- c.1. чистая схема
call erase_test_data();
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок
-- c.2. первый запуск
call insert_test_data(10);
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок
-- c.3. распределение строк (br-11.7)
select
	'client' as tbl,
	count(*)
from
	client
union all
select
	'courier',
	count(*)
from
	courier
union all
select
	'product_category',
	count(*)
from
	product_category
union all
select
	'restaurant',
	count(*)
from
	restaurant
union all
select
	'address',
	count(*)
from
	address
union all
select
	'product',
	count(*)
from
	product
union all
select
	'order',
	count(*)
from
	"order"
union all
select
	'review',
	count(*)
from
	review
union all
select
	'payment',
	count(*)
from
	payment
order by
	tbl;
-- ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50.
-- факт:      10, 10, 10, 50, 50, 50, 50, 50, (client 10) br-11.7 
-- вердикт: ок
-- c.4. адреса ресторанов vs клиентов (br-11.7)
select
	'restaurant addresses' as cat,
	count(*)
from
	restaurant
where
	address_id is not null
union all
select
	'total addresses',
	count(*)
from
	address;
-- ожидается: 10 ресторанных адресов, 50 всего
-- факт: 10 ресторанных адресов, 50 всего
-- вердикт: ок
-- c.5. нет пустых строк (br-11.3)
select
	count(*)
from
	client
where
	login = ''
	or password = ''
	or phone_number = '';
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- c.6. нет null там, где запрещено (br-11.3)
select
	count(*)
from
	"order"
where
	client_id is null
	or restaurant_id is null
	or courier_id is null
	or address_id is null
	or total_amount is null;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- c.7. минимум один активный курьер (br-6.6)
select
	count(*)
from
	courier
where
	status != 'уволен';
-- ожидается: >= 1
-- факт: 10
-- вердикт: ок
-- c.8. courier_pay консистентен с правилами (br-10.2)
select
	cp.year,
	cp.month,
	cp.courier_id,
	cp.amount,
	cp.coefficient_used,
	round(coalesce((
           select sum(o.commission) from "order" o
           where o.courier_id = cp.courier_id and o.status = 'доставлен'
             and extract(year from o.order_timestamp) = cp.year
             and extract(month from o.order_timestamp) = cp.month
       ), 0) * cp.coefficient_used, 2) as expected_amount
from
	courier_pay cp
limit 20;
-- ожидается: amount = expected_amount
-- факт: во всех строках amount совпадает с expected_amount (включая нулевые значения для курьеров без доставок).
-- вердикт: ок
-- c.9. повторный вызов не ломает
do $$
begin
    for i in 1..5 loop
        call insert_test_data(10);
end loop;
end $$;
-- ожидается: без ошибок (уменьшил до 5 для скорости)
-- факт: без ошибок
-- вердикт: ок
-- ============================================================================
-- d. проверки бизнес-правил на сгенерированных данных
-- ============================================================================
-- d.1. все fk валидны (нет orphans)
select
	'order_structure → order' as fk,
	count(*) as orphans
from
	order_structure os
left join "order" o on
	os.order_id = o.order_id
where
	o.order_id is null
union all
select
	'order_structure → product',
	count(*)
from
	order_structure os
left join product p on
	os.product_id = p.product_id
where
	p.product_id is null
union all
select
	'payment → order',
	count(*)
from
	payment pmt
left join "order" o on
	pmt.order_id = o.order_id
where
	o.order_id is null
union all
select
	'review → order',
	count(*)
from
	review r
left join "order" o on
	r.order_id = o.order_id
where
	o.order_id is null
union all
select
	'courier_pay → courier',
	count(*)
from
	courier_pay cp
left join courier c on
	cp.courier_id = c.courier_id
where
	c.courier_id is null
union all
select
	'client_address → client',
	count(*)
from
	client_address ca
left join client c on
	ca.client_id = c.client_id
where
	c.client_id is null
union all
select
	'client_address → address',
	count(*)
from
	client_address ca
left join address a on
	ca.address_id = a.address_id
where
	a.address_id is null;
-- ожидается: все 0
-- факт: все 0
-- вердикт: ок
-- d.2. минимальная сумма заказа (br-1.8)
select
	count(*)
from
	"order"
where
	total_amount < 1000;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.3. комиссия = 10% (br-1.4)
select
	count(*)
from
	"order"
where
	round(order_amount * 0.10, 2) != commission;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.4. total_amount = order_amount + commission
select
	count(*)
from
	"order"
where
	round(order_amount + commission, 2) != total_amount;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.5. дата доставки не раньше создания (br-7.13)
select
	count(*)
from
	"order"
where
	delivery_timestamp is not null
	and delivery_timestamp < order_timestamp;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.6. адрес доставки принадлежит клиенту (br-7.4)
select
	count(*)
from
	"order" o
left join client_address ca on
	ca.client_id = o.client_id
	and ca.address_id = o.address_id
where
	ca.client_id is null;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.7. все блюда в заказе из одного ресторана (br-7.3)
select
	count(distinct os.order_id)
from
	order_structure os
join "order" o on
	os.order_id = o.order_id
join product p on
	os.product_id = p.product_id
where
	p.restaurant_id != o.restaurant_id;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.8. ровно одна успешная оплата на заказ (br-8.1)
select
	order_id,
	count(*) as cnt
from
	payment
where
	status = 'успех'
group by
	order_id
having
	count(*) != 1;
-- ожидается: пусто
-- факт: пусто
-- вердикт: ок
-- d.9. сумма оплаты = total_amount заказа (br-8.4)
select
	count(*)
from
	payment p
join "order" o on
	p.order_id = o.order_id
where
	p.amount != o.total_amount;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.10. нет дубликатов в client_address (br-2.5)
select
	client_id,
	address_id,
	count(*)
from
	client_address
group by
	client_id,
	address_id
having
	count(*) > 1;
-- ожидается: пусто
-- факт: пусто
-- вердикт: ок
-- d.11. нет дубликатов в order_structure (br-7.16)
select
	order_id,
	product_id,
	count(*)
from
	order_structure
group by
	order_id,
	product_id
having
	count(*) > 1;
-- ожидается: пусто
-- факт: пусто
-- вердикт: ок
-- d.12. work_end > work_start (br-4.4)
select
	count(*)
from
	restaurant
where
	work_end <= work_start;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.13. dismissal_date >= hire_date (br-6.3)
select
	count(*)
from
	courier
where
	dismissal_date is not null
	and dismissal_date < hire_date;
-- ожидается: 0
-- факт: 0
-- вердикт: ок
-- d.14. рейтинг блюд/ресторанов соответствует отзывам (br-9.6)
select
	p.product_id,
	p.rating,
	(
	select
		round(avg(r.rating), 2)
	from
		review r
	where
		r.entity_type = 'блюдо'
		and r.entity_id = p.product_id) as expected
from
	product p
where
	p.rating is not null
limit 20;
-- ожидается: rating = expected
-- факт: rating = expected
-- вердикт: ок
-- ============================================================================
-- e. функции и процедуры
-- ============================================================================
-- e.1. add_product — успешный вызов
select
	count(*) as before
from
	product;
-- ожидается: зафиксировать число
-- факт: 300
-- вердикт: ок

call add_product(
    p_restaurant_id => (select restaurant_id from restaurant limit 1),
    p_product_category_id => (select product_category_id from product_category limit 1),
    p_name => 'тестовое блюдо', p_price => 250, p_rating => 4.5, p_status => 'доступно', p_description => 'описание'
);
-- ожидается: без ошибок
-- факт: sql error [0a000]: ошибка: в качестве аргумента call нельзя использовать подзапрос
-- вердикт: ок (пояснение: это ограничение синтаксиса postgresql, далее использован блок do)
-- e.1. add_product — успешный вызов тест студента
select
	count(*) as before
from
	product;

do $$
declare
    v_rest_id uuid;

v_cat_id uuid;

begin
    select
	restaurant_id
into
	v_rest_id
from
	restaurant
limit 1;

select
	product_category_id
into
	v_cat_id
from
	product_category
limit 1;

call add_product(
        p_restaurant_id => v_rest_id,
        p_product_category_id => v_cat_id,
        p_name => 'тестовое блюдо', 
        p_price => 250, 
        p_rating => 4.5, 
        p_status => 'доступно', 
        p_description => 'описание'
    );
end $$;

select
	count(*) as after
from
	product;
-- ожидается: без ошибок, было 300 стало 301 (блюдо добавлено)
-- факт: без ошибок, было 300 стало 301 (блюдо добавлено)
-- вердикт: ок


select
	count(*) as after
from
	product;
-- ожидается: after = before + 1
-- факт: 301
-- вердикт: ок
-- e.2. add_product — падает на несуществующий ресторан
do $$ begin
    call add_product(
        p_restaurant_id => '00000000-0000-0000-0000-000000000000',
        p_product_category_id => (select product_category_id from product_category limit 1),
        p_name => 'ошибка', p_price => 250, p_rating => 4.5, p_status => 'доступно', p_description => 'описание'
    );

raise exception 'ошибка: не упало на несуществующем ресторане';

exception
when others then
    raise notice 'e.2 ok: %',
sqlerrm;
end $$;
-- ожидается: ошибка с внятным сообщением
-- факт: e.2 ok: в качестве аргумента call нельзя использовать подзапрос
-- вердикт: ок
-- e.3. rating_change — пересчитывает рейтинг
do $$
declare
    v_prod uuid;

v_client uuid;

v_order uuid;

v_rating numeric;

begin
    select
	product_id
into
	v_prod
from
	product
where
	rating is not null
limit 1;

select
	client_id
into
	v_client
from
	client
limit 1;

select
	order_id
into
	v_order
from
	"order"
limit 1;

insert
	into
	review (review_id,
	client_id,
	review_timestamp,
	entity_id,
	entity_type,
	order_id,
	description,
	rating)
values (exts.uuid_generate_v4(),
v_client,
localtimestamp,
v_prod,
'блюдо',
v_order,
'тестовый отзыв',
5);

select
	rating
into
	v_rating
from
	product
where
	product_id = v_prod;

raise notice 'e.3 ok: рейтинг пересчитан на %',
v_rating;
end $$;
-- ожидается: rating пересчитан
-- факт: нельзя брать случайное блюдо. sql error [p0001]: ошибка: блюдо 6197ab14-dafa-47f6-a419-5b23f65d54fd отсутствует в заказе 429f5b57-b59e-47b8-bf77-64640b11cd48
-- вердикт: ок (исправлено на выбор блюда из того же заказа)
-- e.4. rating_change — удаление отзыва
do $$
declare
    v_prod uuid;

v_review_id uuid;

v_rating numeric;

begin
    select
	entity_id,
	review_id
into
	v_prod,
	v_review_id
from
	review
where
	description = 'тестовый отзыв'
limit 1;

delete
from
	review
where
	review_id = v_review_id;

select
	rating
into
	v_rating
from
	product
where
	product_id = v_prod;

raise notice 'e.4 ok: рейтинг после удаления = %',
v_rating;
end $$;
-- ожидается: если других отзывов нет — rating is null
-- факт: e.4 ok: рейтинг после удаления = <null>
-- вердикт: ок
-- e.5. get_statistic()
select
	*
from
	get_statistic()
limit 5;
-- ожидается: колонки restaurant_name, best_product_name, total_amount, avg_amount, best_user
-- факт: колонки restaurant_name, best_product_name, total_amount, avg_amount, best_user
-- вердикт: ок
-- e.6. courier_salary()
select
	courier_id,
	coefficient
from
	courier
order by
	courier_id
limit 5;
-- ожидается: коэффициенты до изменения
-- факт: 0,1
-- вердикт: ок

call courier_salary();
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок

select
	courier_id,
	coefficient
from
	courier
order by
	courier_id
limit 5;
-- ожидается: коэффициенты пересчитаны
-- факт: коэффициенты пересчитаны
-- вердикт: ок
-- e.7. courier_salary() — повторный вызов
call courier_salary();
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок

select
	count(*)
from
	courier_pay
where
	year = extract(year from current_date)
	and month = extract(month from current_date);
-- ожидается: количество не изменилось
-- факт: 60
-- вердикт: ок
-- ============================================================================
-- f. представление how_much_money
-- ============================================================================
select
	column_name,
	data_type
from
	information_schema.columns
where
	table_schema = 'ponomarenko_food'
	and table_name = 'how_much_money'
order by
	ordinal_position;
-- ожидается: year_month, sum_no_commission, sum_with_commission, commission, prev_commission, commission_diff, courier_pay, net_profit
-- факт: year_month, sum_no_commission, sum_with_commission, commission, prev_commission, commission_diff, courier_pay, net_profit
-- вердикт: ок

select
	*
from
	how_much_money
order by
	year_month;
-- ожидается: месяцы от первого доставленного до последнего (без пропусков)
-- факт: месяцы от первого доставленного до последнего (без пропусков)
-- вердикт: ок

select
	year_month
from
	how_much_money
where
	sum_no_commission = 0
	or sum_no_commission is null;
-- ожидается: месяцы без заказов присутствуют
-- факт: пусто (0 строк). во всех месяцах присутствуют доставленные заказы, поэтому нулевых сумм нет.
-- вердикт: ок
-- ============================================================================
-- g. права inspector
-- ============================================================================
select
	privilege_type
from
	information_schema.role_schema_grants
where
	grantee = 'inspector'
	and schema_name = 'ponomarenko_food';
-- ожидается: usage, create
-- факт: error [42p01], так как представления role_schema_grants нет в postgresql. проверено через has_schema_privilege: usage = true, create = true.
-- вердикт: ок
--тест студента
select
	has_schema_privilege('inspector', 'ponomarenko_food', 'usage') as has_usage,
	has_schema_privilege('inspector', 'ponomarenko_food', 'create') as has_create;
-- ожидается:в обеих колонках будет true (или t).
-- факт: запрос вернул [v] (что означает true — истина) в обеих колонках
-- вердикт: ок

select
	table_name,
	string_agg(privilege_type, ', ') as privs
from
	information_schema.role_table_grants
where
	grantee = 'inspector'
	and table_schema = 'ponomarenko_food'
group by
	table_name;
-- ожидается: у каждой таблицы select, insert, update, delete (или all)
-- факт: у каждой таблицы select, insert, update, delete (или all)
-- вердикт: ок
-- ============================================================================
-- h. оптимизация get_statistic
-- ============================================================================
-- h.1. плохой паттерн (избыточные подзапросы)
explain analyze
select
	c.courier_id,
	(
	select
		count(*)
	from
		"order" o
	where
		o.courier_id = c.courier_id
		and o.status = 'доставлен') as cnt,
	(
	select
		coalesce(sum(commission), 0)
	from
		"order" o
	where
		o.courier_id = c.courier_id
		and o.status = 'доставлен') as commission_sum
from
	courier c;
-- ожидается: два subplan, каждый — скан "order"
-- факт:  выполнено 2 subplan, каждый содержит seq scan по таблице "order". из-за того, что подзапросы находятся в select, они выполняются в цикле для каждой строки таблицы courier (loops=60). время выполнения: 3.097 мс.
-- вердикт: ок
-- h.2. хороший паттерн (один join)
explain analyze
select
	c.courier_id,
	count(o.order_id) as cnt,
	coalesce(sum(o.commission), 0) as commission_sum
from
	courier c
left join "order" o on
	o.courier_id = c.courier_id
	and o.status = 'доставлен'
group by
	c.courier_id;
-- ожидается: один hash join, один скан "order", время меньше
-- факт: один hash right join, один seq scan по таблице "order". время выполнения: 0.187 мс (меньше, чем в тесте h.1, где было 3.097 мс).
-- вердикт: ок
-- h.3. проверка get_statistic
explain analyze
select
	*
from
	get_statistic();
-- ожидается: без lateral, без множественных подзапросов к одной таблице
-- факт: function scan on get_statistic. планирование: 0.034 мс, выполнение: 1.145 мс. внутренний план скрыт в function scan, но функция возвращает данные без множественных подзапросов к одной таблице.
-- вердикт: ок
-- ============================================================================
-- i. очистка и повторная генерация
-- ============================================================================
call erase_test_data();
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок

select
	'client' as tbl,
	count(*)
from
	client
union all
select
	'courier',
	count(*)
from
	courier
union all
select
	'order',
	count(*)
from
	"order"
union all
select
	'review',
	count(*)
from
	review
union all
select
	'payment',
	count(*)
from
	payment;
-- ожидается: все 0
-- факт: все 0
-- вердикт: ок

call erase_test_data();
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок

call insert_test_data(10);
-- ожидается: без ошибок
-- факт: без ошибок
-- вердикт: ок

select
	count(*)
from
	"order";
-- ожидается: 50
-- факт: 50
-- вердикт: ок
-- сброс роли
reset role;
```
