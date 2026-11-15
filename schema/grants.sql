do $$
begin
    if not exists (
select
from
	pg_catalog.pg_roles
where
	rolname = 'inspector') then
        create role inspector with LOGIN password 'NetoSQL2025';
else
--eсли роль уже есть, на всякий случай обновляем пароль и даем право входа
        alter role inspector with LOGIN password 'NetoSQL2025';
end if;
end
$$;
--права на схему
grant usage,
create on
schema ponomarenko_food to inspector;
--права на схему exts (для uuid_generate_v4) 
grant usage on
schema exts to inspector;

grant execute on
all functions in schema exts to inspector;
--проверяем information_schema и pg_catalog 
grant usage on
schema information_schema to inspector;

grant usage on
schema pg_catalog to inspector;
--права на существующие 
grant all privileges on
all tables in schema ponomarenko_food to inspector;

grant all privileges on
all sequences in schema ponomarenko_food to inspector;

grant all privileges on
all functions in schema ponomarenko_food to inspector;

grant all privileges on
all procedures in schema ponomarenko_food to inspector;
--права на будущие объекты
alter default privileges in schema ponomarenko_food
    grant all on
tables to inspector;

alter default privileges in schema ponomarenko_food
    grant all on
sequences to inspector;

alter default privileges in schema ponomarenko_food
    grant all on
functions to inspector;
