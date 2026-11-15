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
   📄 foodexpress_ponomarenko.backup    # Бинарный бэкап базы данных (pg_dump -Fc)
📄 README.md                           # Этот файл
