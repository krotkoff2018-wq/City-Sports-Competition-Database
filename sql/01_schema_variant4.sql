-- ================================================================
-- ЛАБОРАТОРНАЯ РАБОТА № 1. ВАРИАНТ 4.
-- Информационная система организации городского соревнования
-- Предметный пример: городской легкоатлетический забег.
-- СУБД: PostgreSQL 12+. Модель: третья нормальная форма (3NF).
--
-- Запуск: подключиться к city_sports_db и выполнить весь файл.
-- Создание самой БД вынесено в 00_create_database.sql, так как
-- CREATE DATABASE нельзя выполнять внутри блока транзакции.
-- Время в TIMESTAMP указано по местному времени города.
-- ================================================================
BEGIN;
CREATE SCHEMA IF NOT EXISTS city_sport;
SET search_path TO city_sport, public;

-- 1. Организации, отвечающие за проведение соревнований.
CREATE TABLE organizations (
    organization_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_name VARCHAR(200) NOT NULL UNIQUE,
    contact_email VARCHAR(254),
    contact_phone VARCHAR(30),
    CONSTRAINT chk_organization_name CHECK (length(trim(organization_name)) > 0)
);
COMMENT ON TABLE organizations IS 'Организации, проводящие городские соревнования';

-- 2. Спортивные объекты.
CREATE TABLE venues (
    venue_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venue_name VARCHAR(150) NOT NULL,
    address VARCHAR(250) NOT NULL,
    spectator_capacity INTEGER NOT NULL CHECK (spectator_capacity > 0),
    UNIQUE (venue_name, address)
);
COMMENT ON TABLE venues IS 'Площадки для проведения соревнований';

-- 3. Сотрудники организаций, участвующие в подготовке.
CREATE TABLE staff_members (
    staff_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations(organization_id),
    full_name VARCHAR(160) NOT NULL,
    email VARCHAR(254) UNIQUE,
    phone VARCHAR(30)
);
COMMENT ON TABLE staff_members IS 'Справочник работников организаторов';

-- 4. Роли работников в конкретном соревновании.
CREATE TABLE staff_roles (
    role_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_code VARCHAR(30) NOT NULL UNIQUE,
    role_name VARCHAR(120) NOT NULL UNIQUE
);
COMMENT ON TABLE staff_roles IS 'Координатор, судья, ответственный за заявки и другие роли';

-- 5. Возможные статусы соревнования.
CREATE TABLE competition_statuses (
    status_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_code VARCHAR(30) NOT NULL UNIQUE,
    status_name VARCHAR(100) NOT NULL UNIQUE
);

-- 6. Городские соревнования.
CREATE TABLE competitions (
    competition_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    competition_code VARCHAR(50) NOT NULL UNIQUE,
    competition_name VARCHAR(200) NOT NULL,
    organization_id BIGINT NOT NULL REFERENCES organizations(organization_id),
    venue_id BIGINT NOT NULL REFERENCES venues(venue_id),
    status_id BIGINT NOT NULL REFERENCES competition_statuses(status_id),
    start_at TIMESTAMP NOT NULL,
    end_at TIMESTAMP NOT NULL,
    registration_deadline TIMESTAMP NOT NULL,
    description TEXT,
    CONSTRAINT chk_competition_dates CHECK (start_at < end_at),
    CONSTRAINT chk_registration_deadline CHECK (registration_deadline < start_at)
);
COMMENT ON TABLE competitions IS 'Основные сведения и сроки соревнований';
COMMENT ON COLUMN competitions.competition_code IS 'Устойчивый уникальный бизнес-код мероприятия';

-- 7. Назначения работников: один работник - одна роль в событии.
CREATE TABLE competition_staff (
    competition_id BIGINT NOT NULL REFERENCES competitions(competition_id),
    staff_id BIGINT NOT NULL REFERENCES staff_members(staff_id),
    role_id BIGINT NOT NULL REFERENCES staff_roles(role_id),
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (competition_id, staff_id)
);
COMMENT ON TABLE competition_staff IS 'Связь работников с мероприятиями и их ролями';

-- 8. Справочник организационных этапов.
CREATE TABLE stage_types (
    stage_type_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stage_code VARCHAR(40) NOT NULL UNIQUE,
    stage_name VARCHAR(160) NOT NULL UNIQUE
);

-- 9. Статусы выполнения этапов.
CREATE TABLE stage_statuses (
    stage_status_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_code VARCHAR(30) NOT NULL UNIQUE,
    status_name VARCHAR(100) NOT NULL UNIQUE
);

-- 10. Этапы: явное описание порядка организации соревнования.
CREATE TABLE competition_stages (
    stage_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    competition_id BIGINT NOT NULL REFERENCES competitions(competition_id),
    stage_type_id BIGINT NOT NULL REFERENCES stage_types(stage_type_id),
    step_number SMALLINT NOT NULL CHECK (step_number > 0),
    planned_start_at TIMESTAMP NOT NULL,
    planned_end_at TIMESTAMP NOT NULL,
    stage_status_id BIGINT NOT NULL REFERENCES stage_statuses(stage_status_id),
    responsible_staff_id BIGINT,
    notes TEXT,
    CONSTRAINT chk_stage_dates CHECK (planned_end_at >= planned_start_at),
    CONSTRAINT uq_stage_order UNIQUE (competition_id, step_number),
    CONSTRAINT uq_stage_type UNIQUE (competition_id, stage_type_id),
    CONSTRAINT fk_stage_assigned_staff
        FOREIGN KEY (competition_id, responsible_staff_id)
        REFERENCES competition_staff(competition_id, staff_id)
);
COMMENT ON TABLE competition_stages IS 'Упорядоченные этапы подготовки и проведения, сроки, статус, ответственный';
COMMENT ON COLUMN competition_stages.step_number IS 'Порядковый номер этапа внутри соревнования';

-- 11. Спортивные дисциплины (в примере - беговые дистанции).
CREATE TABLE disciplines (
    discipline_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    discipline_name VARCHAR(120) NOT NULL UNIQUE,
    distance_meters INTEGER NOT NULL CHECK (distance_meters > 0)
);

-- 12. Возрастные категории для стартов.
CREATE TABLE age_categories (
    age_category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    min_age INTEGER NOT NULL CHECK (min_age >= 0),
    max_age INTEGER,
    CONSTRAINT chk_age_interval CHECK (max_age IS NULL OR max_age >= min_age)
);

-- 13. Отдельные старты в программе соревнования.
CREATE TABLE program_events (
    program_event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    competition_id BIGINT NOT NULL REFERENCES competitions(competition_id),
    discipline_id BIGINT NOT NULL REFERENCES disciplines(discipline_id),
    age_category_id BIGINT NOT NULL REFERENCES age_categories(age_category_id),
    scheduled_start_at TIMESTAMP NOT NULL,
    participant_limit INTEGER NOT NULL CHECK (participant_limit > 0),
    CONSTRAINT uq_program_event
        UNIQUE (competition_id, discipline_id, age_category_id)
);
COMMENT ON TABLE program_events IS 'Программа: соревнование, дистанция, возрастная категория, время старта';

-- 14. Физические лица - участники соревнований.
CREATE TABLE participants (
    participant_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(160) NOT NULL,
    birth_date DATE NOT NULL,
    email VARCHAR(254) UNIQUE,
    phone VARCHAR(30)
);

-- 15. Статусы заявок участников.
CREATE TABLE registration_statuses (
    registration_status_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_code VARCHAR(30) NOT NULL UNIQUE,
    status_name VARCHAR(100) NOT NULL UNIQUE
);

-- 16. Заявки конкретного участника на конкретный старт.
CREATE TABLE registrations (
    registration_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    program_event_id BIGINT NOT NULL REFERENCES program_events(program_event_id),
    participant_id BIGINT NOT NULL REFERENCES participants(participant_id),
    registration_status_id BIGINT NOT NULL
        REFERENCES registration_statuses(registration_status_id),
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_registration UNIQUE (program_event_id, participant_id)
);
COMMENT ON TABLE registrations IS 'Связь многие-ко-многим: участник и старт, с атрибутами заявки';

-- 17. Результат каждого зарегистрированного спортсмена на старте.
-- Место НЕ хранится: оно вычисляется по времени финиша в запросе.
CREATE TABLE results (
    registration_id BIGINT PRIMARY KEY REFERENCES registrations(registration_id),
    outcome VARCHAR(12) NOT NULL,
    finish_time_ms BIGINT,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_outcome CHECK (outcome IN ('FINISHED', 'DNF', 'DQ')),
    CONSTRAINT chk_finish_time CHECK (
        (outcome = 'FINISHED' AND finish_time_ms IS NOT NULL AND finish_time_ms > 0)
        OR (outcome IN ('DNF', 'DQ') AND finish_time_ms IS NULL)
    )
);
COMMENT ON TABLE results IS 'Результаты: FINISHED - финиш, DNF - не финишировал, DQ - дисквалификация';
COMMENT ON COLUMN results.finish_time_ms IS 'Время результата в миллисекундах; место определяется SQL-запросом';

-- Индексы для внешних ключей и типовых выборок.
CREATE INDEX idx_staff_members_org ON staff_members(organization_id);
CREATE INDEX idx_competitions_organization ON competitions(organization_id);
CREATE INDEX idx_competitions_venue ON competitions(venue_id);
CREATE INDEX idx_competition_staff_staff ON competition_staff(staff_id);
CREATE INDEX idx_stages_comp_order ON competition_stages(competition_id, step_number);
CREATE INDEX idx_program_events_comp ON program_events(competition_id);
CREATE INDEX idx_registrations_participant ON registrations(participant_id);
CREATE INDEX idx_registrations_status ON registrations(registration_status_id);

COMMENT ON SCHEMA city_sport IS 'Нормализованная до 3NF база данных городских спортивных соревнований';
COMMIT;
-- После выполнения при новом подключении используйте:
-- SET search_path TO city_sport, public;