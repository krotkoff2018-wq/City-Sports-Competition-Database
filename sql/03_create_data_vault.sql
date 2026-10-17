-- Лабораторная работа 1, вариант 4: ДОПОЛНИТЕЛЬНАЯ модель Data Vault 2.0
-- Запуск в базе city_sports_db ПОСЛЕ 01_schema_variant4.sql
-- Объекты 3NF в city_sport НЕ изменяются; Data Vault размещен в data_vault.
-- Обучающий пример: MD5 служит детерминированным техническим hash key,
-- а не средством криптографической защиты персональных данных.
BEGIN;
CREATE SCHEMA IF NOT EXISTS data_vault;

CREATE OR REPLACE FUNCTION data_vault.dv_key(p_entity text, p_business_key text)
RETURNS char(32) LANGUAGE SQL IMMUTABLE STRICT AS
$$ SELECT md5(p_entity || '|' || p_business_key)::char(32) $$;

CREATE OR REPLACE FUNCTION data_vault.dv_hashdiff(VARIADIC p_values text[])
RETURNS char(32) LANGUAGE SQL IMMUTABLE AS
$$ SELECT md5(array_to_string(p_values, '|', '<NULL>'))::char(32) $$;

-- HUB: устойчивые бизнес-ключи объектов. Атрибуты - в Satellite.
CREATE TABLE IF NOT EXISTS data_vault.hub_organization (
  organization_hk char(32) PRIMARY KEY,
  organization_name varchar(200) NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport'
);

CREATE TABLE IF NOT EXISTS data_vault.hub_venue (
  venue_hk char(32) PRIMARY KEY,
  venue_business_key varchar(450) NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport'
);

CREATE TABLE IF NOT EXISTS data_vault.hub_competition (
  competition_hk char(32) PRIMARY KEY,
  competition_code varchar(50) NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport'
);

CREATE TABLE IF NOT EXISTS data_vault.hub_stage_type (
  stage_type_hk char(32) PRIMARY KEY,
  stage_code varchar(40) NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport'
);

CREATE TABLE IF NOT EXISTS data_vault.hub_program_event (
  program_event_hk char(32) PRIMARY KEY,
  event_business_key varchar(500) NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport'
);

CREATE TABLE IF NOT EXISTS data_vault.hub_participant (
  participant_hk char(32) PRIMARY KEY,
  participant_email varchar(254) NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport'
);

-- LINK: историзируемые факты связей между Hub.
CREATE TABLE IF NOT EXISTS data_vault.link_competition_organization (
  competition_organization_hk char(32) PRIMARY KEY,
  competition_hk char(32) NOT NULL REFERENCES data_vault.hub_competition(competition_hk),
  organization_hk char(32) NOT NULL REFERENCES data_vault.hub_organization(organization_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  UNIQUE (competition_hk, organization_hk)
);

CREATE TABLE IF NOT EXISTS data_vault.link_competition_venue (
  competition_venue_hk char(32) PRIMARY KEY,
  competition_hk char(32) NOT NULL REFERENCES data_vault.hub_competition(competition_hk),
  venue_hk char(32) NOT NULL REFERENCES data_vault.hub_venue(venue_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  UNIQUE (competition_hk, venue_hk)
);

CREATE TABLE IF NOT EXISTS data_vault.link_competition_stage (
  competition_stage_hk char(32) PRIMARY KEY,
  competition_hk char(32) NOT NULL REFERENCES data_vault.hub_competition(competition_hk),
  stage_type_hk char(32) NOT NULL REFERENCES data_vault.hub_stage_type(stage_type_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  UNIQUE (competition_hk, stage_type_hk)
);

CREATE TABLE IF NOT EXISTS data_vault.link_competition_program_event (
  competition_program_event_hk char(32) PRIMARY KEY,
  competition_hk char(32) NOT NULL REFERENCES data_vault.hub_competition(competition_hk),
  program_event_hk char(32) NOT NULL REFERENCES data_vault.hub_program_event(program_event_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  UNIQUE (competition_hk, program_event_hk)
);

CREATE TABLE IF NOT EXISTS data_vault.link_registration (
  registration_hk char(32) PRIMARY KEY,
  program_event_hk char(32) NOT NULL REFERENCES data_vault.hub_program_event(program_event_hk),
  participant_hk char(32) NOT NULL REFERENCES data_vault.hub_participant(participant_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  UNIQUE (program_event_hk, participant_hk)
);

-- SATELLITE: значения описательных атрибутов и метаданные загрузки.
CREATE TABLE IF NOT EXISTS data_vault.sat_organization_details (
  organization_hk char(32) NOT NULL REFERENCES data_vault.hub_organization(organization_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  contact_email varchar(254),
  contact_phone varchar(30),
  PRIMARY KEY (organization_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_venue_details (
  venue_hk char(32) NOT NULL REFERENCES data_vault.hub_venue(venue_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  spectator_capacity integer,
  PRIMARY KEY (venue_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_competition_details (
  competition_hk char(32) NOT NULL REFERENCES data_vault.hub_competition(competition_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  competition_name varchar(200),
  status_code varchar(30),
  start_at timestamp,
  end_at timestamp,
  registration_deadline timestamp,
  description text,
  PRIMARY KEY (competition_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_stage_type_details (
  stage_type_hk char(32) NOT NULL REFERENCES data_vault.hub_stage_type(stage_type_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  stage_name varchar(160),
  PRIMARY KEY (stage_type_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_competition_stage_details (
  competition_stage_hk char(32) NOT NULL REFERENCES data_vault.link_competition_stage(competition_stage_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  step_number smallint,
  planned_start_at timestamp,
  planned_end_at timestamp,
  stage_status_code varchar(30),
  responsible_staff_name varchar(160),
  PRIMARY KEY (competition_stage_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_program_event_details (
  program_event_hk char(32) NOT NULL REFERENCES data_vault.hub_program_event(program_event_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  discipline_name varchar(120),
  distance_meters integer,
  category_name varchar(100),
  min_age integer,
  max_age integer,
  scheduled_start_at timestamp,
  participant_limit integer,
  PRIMARY KEY (program_event_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_participant_details (
  participant_hk char(32) NOT NULL REFERENCES data_vault.hub_participant(participant_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  full_name varchar(160),
  birth_date date,
  phone varchar(30),
  PRIMARY KEY (participant_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_registration_details (
  registration_hk char(32) NOT NULL REFERENCES data_vault.link_registration(registration_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  registration_status_code varchar(30),
  registered_at timestamp,
  PRIMARY KEY (registration_hk, load_dts)
);

CREATE TABLE IF NOT EXISTS data_vault.sat_result_details (
  registration_hk char(32) NOT NULL REFERENCES data_vault.link_registration(registration_hk),
  load_dts timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  record_source varchar(50) NOT NULL DEFAULT 'city_sport',
  hashdiff char(32) NOT NULL,
  outcome varchar(12),
  finish_time_ms bigint,
  recorded_at timestamp,
  PRIMARY KEY (registration_hk, load_dts)
);

COMMENT ON SCHEMA data_vault IS 'Учебное аналитическое хранилище Data Vault 2.0, отдельно от операционной 3NF';
COMMIT;