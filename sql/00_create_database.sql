-- Лабораторная работа №1, вариант 4.
-- Шаг 1. Выполните этот файл отдельно в PostgreSQL,
-- подключившись к служебной базе postgres (не в блоке транзакции).
-- Если база city_sports_db уже существует, пропустите команду.
CREATE DATABASE city_sports_db
    WITH ENCODING = 'UTF8'
         TEMPLATE = template0;

-- Шаг 2. Подключитесь к созданной базе city_sports_db.
-- Шаг 3. Выполните 01_schema_variant4.sql.
-- Шаг 4 (необязательно). Выполните 02_demo_variant4.sql.