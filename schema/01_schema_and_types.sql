create schema if not exists ponomarenko_food;

create schema if not exists exts;

create extension if not exists "uuid-ossp" with schema exts;

set
search_path to ponomarenko_food,
exts;

create sequence if not exists test_data_seq start 1;
-- enum-типы (br-11.5)
create type restaurant_status as enum ('активен',
'неактивен');

create type product_status as enum ('доступно',
'нет_в_наличии',
'архив');

create type courier_status as enum ('свободен',
'занят',
'на_доставке',
'уволен');

create type order_status as enum ('создан',
'готовится',
'в_доставке',
'доставлен',
'отменён');

create type pay_status as enum ('ожидает',
'оплачен',
'ошибка');

create type payment_type as enum ('карта',
'наличные',
'безнал');

create type payment_status as enum ('успех',
'ошибка',
'в_обработке');

create type review_entity_type as enum ('блюдо',
'ресторан',
'заказ');

--12 таблиц
create table client (
    client_id uuid primary key default exts.uuid_generate_v4(),
    login varchar(50) not null unique,
    password varchar(32) not null check (password ~ '^[a-f0-9]{32}$'),
    phone_number varchar(20) not null unique
);

create table address (
    address_id uuid primary key default exts.uuid_generate_v4(),
    street varchar(100) not null,
    house_number varchar(20) not null,
    apartment_office varchar(20) null
);

create table client_address (
    client_id uuid not null references client(client_id) on
delete
	cascade,
	address_id uuid not null references address(address_id) on
	delete
		restrict,
		primary key (client_id,
		address_id)
);

create table restaurant (
    restaurant_id uuid primary key default exts.uuid_generate_v4(),
    restaurant_name varchar(100) not null,
    address_id uuid not null unique references address(address_id) on
delete
	restrict,
	description text not null,
	work_start time not null,
	work_end time not null check (work_end > work_start),
	inn varchar(12) not null,
	ogrn varchar(15) not null,
	settlement_account varchar(20) not null,
	rating numeric(1, 0) null check (rating >= 0
		and rating <= 5),
	status restaurant_status not null
);

create table courier (
    courier_id uuid primary key default exts.uuid_generate_v4(),
    first_name varchar(100) not null,
    last_name varchar(100) not null,
    middle_name varchar(100) null,
    phone_number varchar(20) not null,
    status courier_status not null,
    hire_date date not null,
    dismissal_date date null check (dismissal_date >= hire_date),
    coefficient numeric(2, 1) not null default 0.1 check (coefficient >= 0.1
	and coefficient <= 0.5),
    check (status != 'уволен'
	or dismissal_date is not null)
);

create table courier_pay (
    year int not null check (year >= 2025),
    month int not null check (month between 1 and 12),
    courier_id uuid not null references courier(courier_id) on
delete
	restrict,
	amount numeric(8, 2) not null check (amount >= 0),
	coefficient_used numeric(2, 1) not null check (coefficient_used >= 0.1
		and coefficient_used <= 0.5),
	primary key (year,
	month,
	courier_id)
);

create table product_category (
    product_category_id uuid primary key default exts.uuid_generate_v4(),
    product_category_name varchar(100) not null unique
);

create table product (
    product_id uuid primary key default exts.uuid_generate_v4(),
    product_name varchar(150) not null,
    product_category_id uuid not null references product_category(product_category_id) on
delete
	restrict,
	price numeric(7, 2) not null check (price >= 0),
	restaurant_id uuid not null references restaurant(restaurant_id) on
	delete
		restrict,
		photo_url text null,
		rating numeric(1, 0) null check (rating >= 0
			and rating <= 5),
		status product_status not null,
		description text not null,
		unique (restaurant_id,
		product_id)
		-- для составного fk в order_structure
);

create table "order" (
    order_id uuid primary key default exts.uuid_generate_v4(),
    courier_id uuid not null references courier(courier_id) on
delete
	restrict,
	client_id uuid not null references client(client_id) on
	delete
		restrict,
		address_id uuid not null references address(address_id) on
		delete
			restrict,
			restaurant_id uuid not null references restaurant(restaurant_id) on
			delete
				restrict,
				order_timestamp timestamp not null default localtimestamp,
				delivery_timestamp timestamp null check (delivery_timestamp >= order_timestamp),
				order_amount numeric(8, 2) not null check (order_amount >= 1000),
				commission numeric(8, 2) not null check (commission >= 0),
				total_amount numeric(9, 2) not null check (total_amount >= 1000),
				status order_status not null,
				pay_status pay_status not null,
				description text null,
				check (commission = round(order_amount * 0.1, 2)),
				check (total_amount = order_amount + commission),
				foreign key (client_id,
				address_id) references client_address(client_id, address_id) on
				delete
					restrict,
					unique (order_id,
					restaurant_id),
					unique (order_id,
					client_id)
);

create table payment (
    payment_id uuid primary key default exts.uuid_generate_v4(),
    order_id uuid not null references "order"(order_id) on
delete
	cascade,
	payment_type payment_type not null,
	amount numeric(9, 2) not null check (amount >= 0),
	transaction_id varchar(100) not null unique,
	transaction_timestamp timestamp not null default localtimestamp,
	status payment_status not null
);
-- ровно одна успешная попытка на заказ (br-8.1)
create unique index idx_payment_one_success on
payment(order_id)
where
status = 'успех';

create table order_structure (
    order_id uuid not null references "order"(order_id) on
delete
	cascade,
	product_id uuid not null references product(product_id) on
	delete
		restrict,
		restaurant_id uuid not null,
		quantity numeric(6, 3) not null check (quantity > 0),
		primary key (order_id,
		product_id),
		foreign key (order_id,
		restaurant_id) references "order"(order_id,
		restaurant_id) on
		delete
			cascade,
			foreign key (product_id,
			restaurant_id) references product(product_id, restaurant_id) on
			delete
				restrict
);

create table review (
    review_id uuid primary key default exts.uuid_generate_v4(),
    client_id uuid not null references client(client_id) on
delete
	restrict,
	review_timestamp timestamp not null default localtimestamp,
	entity_id uuid not null,
	entity_type review_entity_type not null,
	order_id uuid not null references "order"(order_id) on
	delete
		cascade,
		description text not null,
		photo_url text null,
		rating numeric(1, 0) not null check (rating >= 1
			and rating <= 5),
		unique (order_id,
		entity_type,
		entity_id),
		foreign key (order_id,
		client_id) references "order"(order_id,
		client_id) on
		delete
			cascade
);
