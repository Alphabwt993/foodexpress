# FoodExpress Database Project

Репозиторий содержит реализацию базы данных для сервиса доставки еды **FoodExpress** (PostgreSQL 15+). 


## 📂 Структура репозитория

```text
📁 db/
   📁 schema/
      📄 01_schema_and_types.sql       # Создание схемы, ENUM-типов и таблиц с PK/FK/CHECK
      📄 02_functions_and_procedures.sql # Бизнес-логика: add_product, get_statistic, courier_salary
      📄 03_triggers.sql               # Триггеры: rating_change, validate_review, check_payment_amount
      📄 04_test_data.sql              # Процедуры очистки (erase_test_data) и генерации (insert_test_data)
      📄 05_how_much_money.sql         # Представление (View) для финансового отчета
      📄 grants.sql                    # Создание роли inspector и выдача прав доступа
   📄 constraints.md                   # Обоснование всех ограничений (CHECK, UNIQUE, FK, NOT NULL)
   📄 tests.md                         # Протокол самопроверки (заполненный)
   📄 ponomarenko_food.backup    # Бинарный бэкап базы данных (pg_dump -Fc)
📄 README.md                           # Этот файл

```
## 🚀 Порядок развертывания (с нуля)

```
Если вы разворачиваете базу данных не из бэкапа, а с помощью SQL-скриптов, выполняйте их строго в следующем порядке (от имени суперпользователя postgres):

01_schema_and_types.sql — создает схему ponomarenko_food, типы и таблицы.

02_functions_and_procedures.sql — создает функции и процедуры.

03_triggers.sql — навешивает триггеры на таблицы.

04_test_data.sql — создает процедуры для очистки и заполнения тестовыми данными.

05_how_much_money.sql — создает представление для отчета.

grants.sql — создает роль inspector, выдает ей права и настраивает ALTER DEFAULT PRIVILEGES.
```
## 💾 Восстановление из бэкапа
```
Если вы хотите развернуть базу из бинарного архива (файл .backup):

1. Создайте пустую базу данных (например, food_db):
bash
createdb -U postgres food_db

2. Восстановите из архива:
bash
pg_restore -U postgres -d food_db -c db/ponomarenko_food.backup

3. Примените скрипт с правами (обязательно, так как роли не всегда попадают в бэкап):
bash
psql -U postgres -d food_db -f db/schema/grants.sql
```
## 🧪 Запуск тестов
```
Для проверки работоспособности базы под ролью inspector:

Подключитесь к базе под ролью inspector (пароль: NetoSQL2025).

Выполните скрипт tests.md (или SQL-версию из него):
SET ROLE inspector;
SET search_path TO ponomarenko_food, exts;

CALL erase_test_data();
CALL insert_test_data(N);

Далее выполняются проверки из протокола tests.md
```
## 📝 Ключевые решения и архитектура
```
Генерация ID: Все первичные ключи генерируются через exts.uuid_generate_v4() (BR-11.1). Расширение установлено в схему exts.

Enum-типы: Все статусы реализованы через CREATE TYPE ... AS ENUM (BR-11.5) для предотвращения опечаток.

Связь заказа и адреса: Реализована через составной внешний ключ (client_id, address_id) на таблицу client_address, что гарантирует доставку только по адресам самого клиента (BR-7.4).

Целостность заказа: Составные ключи (order_id, restaurant_id) и (product_id, restaurant_id) в order_structure гарантируют, что все блюда в заказе принадлежат одному ресторану (BR-7.3).

Полиморфизм отзывов: Реализован через entity_type + entity_id, валидность проверяется триггером validate_review (BR-9.1, BR-9.2).

Денормализация рейтингов: Поля product.rating и restaurant.rating обновляются автоматически через триггер rating_change при любом изменении отзывов (BR-9.6, BR-9.7).

Оплата: Агрегированный статус order.pay_status вычисляется на основе попыток оплаты. Частичный уникальный индекс WHERE status = 'успех' гарантирует ровно одну успешную попытку на заказ (BR-8.1).
```
