-- ================================================================
-- ДЕМОНСТРАЦИОННОЕ НАПОЛНЕНИЕ И КОНТРОЛЬНЫЕ SQL-ЗАПРОСЫ.
-- Запускать ПОСЛЕ 01_schema_variant4.sql, подключившись
-- к базе city_sports_db. Демонстрационные данные вымышлены.
-- ================================================================
BEGIN;
SET search_path TO city_sport, public;

-- Заполнение справочников статусов и ролей.
INSERT INTO competition_statuses (status_code, status_name) VALUES
('PLANNED', 'Подготовка'), ('ACTIVE', 'Проводится'), ('COMPLETED', 'Завершено')
ON CONFLICT (status_code) DO NOTHING;

INSERT INTO stage_statuses (status_code, status_name) VALUES
('PENDING', 'Не начат'), ('RUNNING', 'В работе'), ('DONE', 'Выполнен')
ON CONFLICT (status_code) DO NOTHING;

INSERT INTO registration_statuses (status_code, status_name) VALUES
('SUBMITTED', 'Подана'), ('CONFIRMED', 'Подтверждена'),
('REJECTED', 'Отклонена'), ('CANCELLED', 'Отменена')
ON CONFLICT (status_code) DO NOTHING;

INSERT INTO staff_roles (role_code, role_name) VALUES
('COORDINATOR', 'Координатор соревнования'),
('REFEREE', 'Главный судья'),
('REGISTRAR', 'Ответственный за заявки')
ON CONFLICT (role_code) DO NOTHING;

INSERT INTO stage_types (stage_code, stage_name) VALUES
('RULES', 'Утверждение регламента'),
('VENUE', 'Согласование спортивной площадки'),
('STAFF', 'Назначение судей и ответственных'),
('ANNOUNCEMENT', 'Публикация объявления'),
('REGISTRATION', 'Прием заявок'),
('START_LIST', 'Формирование стартовых протоколов'),
('RACES', 'Проведение спортивных стартов'),
('RESULTS', 'Утверждение результатов'),
('AWARDS', 'Награждение и итоговый отчет')
ON CONFLICT (stage_code) DO NOTHING;

-- Сведения о месте и организаторе.
INSERT INTO organizations (organization_name, contact_email, contact_phone)
VALUES ('Городской спортивный центр', 'info@sport.example', '+7-900-111-22-33')
ON CONFLICT (organization_name) DO NOTHING;

INSERT INTO venues (venue_name, address, spectator_capacity)
VALUES ('Центральный городской стадион', 'ул. Спортивная, 10', 3000)
ON CONFLICT (venue_name, address) DO NOTHING;

INSERT INTO staff_members (organization_id, full_name, email, phone)
SELECT o.organization_id, v.full_name, v.email, v.phone
FROM (VALUES
  ('Иван Петров', 'petrov@sport.example', '+7-900-000-00-01'),
  ('Елена Соколова', 'sokolova@sport.example', '+7-900-000-00-02'),
  ('Мария Волкова', 'volkova@sport.example', '+7-900-000-00-03')
) AS v(full_name, email, phone)
CROSS JOIN organizations o
WHERE o.organization_name = 'Городской спортивный центр'
ON CONFLICT (email) DO NOTHING;

-- Уникальный код позволяет найти соревнование без знания его ID.
INSERT INTO competitions (
  competition_code, competition_name, organization_id, venue_id,
  status_id, start_at, end_at, registration_deadline, description
)
SELECT 'CITY-RUN-2026-09', 'Городской осенний забег',
       o.organization_id, v.venue_id, cs.status_id,
       TIMESTAMP '2026-09-30 09:00', TIMESTAMP '2026-09-30 17:00',
       TIMESTAMP '2026-09-28 23:59',
       'Открытые городские соревнования по бегу на 5 и 10 километров'
FROM organizations o
CROSS JOIN venues v
CROSS JOIN competition_statuses cs
WHERE o.organization_name = 'Городской спортивный центр'
  AND v.venue_name = 'Центральный городской стадион'
  AND v.address = 'ул. Спортивная, 10'
  AND cs.status_code = 'COMPLETED'
ON CONFLICT (competition_code) DO NOTHING;

INSERT INTO competition_staff (competition_id, staff_id, role_id)
SELECT c.competition_id, s.staff_id, sr.role_id
FROM (VALUES
 ('petrov@sport.example', 'COORDINATOR'),
 ('sokolova@sport.example', 'REFEREE'),
 ('volkova@sport.example', 'REGISTRAR')
) AS x(email, role_code)
JOIN staff_members s ON s.email = x.email
JOIN staff_roles sr ON sr.role_code = x.role_code
JOIN competitions c ON c.competition_code = 'CITY-RUN-2026-09'
ON CONFLICT (competition_id, staff_id) DO NOTHING;

-- Последовательность этапов подготовки и проведения.
INSERT INTO competition_stages (
  competition_id, stage_type_id, step_number,
  planned_start_at, planned_end_at, stage_status_id, responsible_staff_id
)
SELECT c.competition_id, st.stage_type_id, p.step_number,
       p.date_from::timestamp, p.date_to::timestamp, ss.stage_status_id, sm.staff_id
FROM (VALUES
 (1, 'RULES', '2026-09-01 09:00', '2026-09-03 18:00', 'DONE', 'petrov@sport.example'),
 (2, 'VENUE', '2026-09-04 09:00', '2026-09-06 18:00', 'DONE', 'petrov@sport.example'),
 (3, 'STAFF', '2026-09-07 09:00', '2026-09-09 18:00', 'DONE', 'petrov@sport.example'),
 (4, 'ANNOUNCEMENT', '2026-09-10 09:00', '2026-09-11 18:00', 'DONE', 'volkova@sport.example'),
 (5, 'REGISTRATION', '2026-09-12 09:00', '2026-09-28 23:59', 'DONE', 'volkova@sport.example'),
 (6, 'START_LIST', '2026-09-29 09:00', '2026-09-29 19:00', 'DONE', 'sokolova@sport.example'),
 (7, 'RACES', '2026-09-30 09:00', '2026-09-30 17:00', 'DONE', 'sokolova@sport.example'),
 (8, 'RESULTS', '2026-09-30 15:00', '2026-09-30 18:00', 'DONE', 'sokolova@sport.example'),
 (9, 'AWARDS', '2026-09-30 17:00', '2026-10-01 18:00', 'DONE', 'petrov@sport.example')
) AS p(step_number, stage_code, date_from, date_to, status_code, email)
JOIN competitions c ON c.competition_code = 'CITY-RUN-2026-09'
JOIN stage_types st ON st.stage_code = p.stage_code
JOIN stage_statuses ss ON ss.status_code = p.status_code
JOIN staff_members sm ON sm.email = p.email
ON CONFLICT (competition_id, stage_type_id) DO NOTHING;

-- Дистанции, возрастные группы и программа стартов.
INSERT INTO disciplines (discipline_name, distance_meters) VALUES
('Бег 5 км', 5000), ('Бег 10 км', 10000)
ON CONFLICT (discipline_name) DO NOTHING;

INSERT INTO age_categories (category_name, min_age, max_age) VALUES
('Взрослые 18–39', 18, 39), ('Мастера 40+', 40, NULL)
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO program_events (
  competition_id, discipline_id, age_category_id,
  scheduled_start_at, participant_limit
)
SELECT c.competition_id, d.discipline_id, a.age_category_id,
       x.start_at::timestamp, x.participant_limit
FROM (VALUES
  ('Бег 5 км', 'Взрослые 18–39', '2026-09-30 10:00', 100),
  ('Бег 10 км', 'Мастера 40+', '2026-09-30 12:00', 80)
) AS x(discipline_name, category_name, start_at, participant_limit)
JOIN competitions c ON c.competition_code = 'CITY-RUN-2026-09'
JOIN disciplines d ON d.discipline_name = x.discipline_name
JOIN age_categories a ON a.category_name = x.category_name
ON CONFLICT (competition_id, discipline_id, age_category_id) DO NOTHING;

INSERT INTO participants (full_name, birth_date, email, phone) VALUES
('Анна Сергеева', '2001-06-18', 'anna@example.test', '+7-900-001-01-01'),
('Борис Егоров', '1996-04-22', 'boris@example.test', '+7-900-001-01-02'),
('Виктор Фролов', '1980-09-15', 'viktor@example.test', '+7-900-001-01-03')
ON CONFLICT (email) DO NOTHING;

INSERT INTO registrations (program_event_id, participant_id, registration_status_id)
SELECT pe.program_event_id, p.participant_id, rs.registration_status_id
FROM (VALUES
 ('anna@example.test', 'Бег 5 км', 'Взрослые 18–39'),
 ('boris@example.test', 'Бег 5 км', 'Взрослые 18–39'),
 ('viktor@example.test', 'Бег 10 км', 'Мастера 40+')
) AS x(email, discipline_name, category_name)
JOIN participants p ON p.email = x.email
JOIN disciplines d ON d.discipline_name = x.discipline_name
JOIN age_categories a ON a.category_name = x.category_name
JOIN competitions c ON c.competition_code = 'CITY-RUN-2026-09'
JOIN program_events pe ON pe.competition_id = c.competition_id
  AND pe.discipline_id = d.discipline_id
  AND pe.age_category_id = a.age_category_id
JOIN registration_statuses rs ON rs.status_code = 'CONFIRMED'
ON CONFLICT (program_event_id, participant_id) DO NOTHING;

-- Результаты вымышленного завершенного соревнования для проверки отчетов.
INSERT INTO results (registration_id, outcome, finish_time_ms)
SELECT r.registration_id, 'FINISHED', x.finish_time_ms
FROM (VALUES
 ('anna@example.test', 1280345::bigint),
 ('boris@example.test', 1420567::bigint),
 ('viktor@example.test', 2880555::bigint)
) AS x(email, finish_time_ms)
JOIN participants p ON p.email = x.email
JOIN registrations r ON r.participant_id = p.participant_id
ON CONFLICT (registration_id) DO NOTHING;
COMMIT;

SET search_path TO city_sport, public;

-- КОНТРОЛЬНЫЙ ЗАПРОС №1. План организации по шагам.
SELECT cs.step_number AS step_no,
       st.stage_name AS organization_step,
       cs.planned_start_at,
       cs.planned_end_at,
       ss.status_name AS step_status,
       sm.full_name AS responsible_person
FROM competition_stages cs
JOIN competitions c ON c.competition_id = cs.competition_id
JOIN stage_types st ON st.stage_type_id = cs.stage_type_id
JOIN stage_statuses ss ON ss.stage_status_id = cs.stage_status_id
LEFT JOIN staff_members sm ON sm.staff_id = cs.responsible_staff_id
WHERE c.competition_code = 'CITY-RUN-2026-09'
ORDER BY cs.step_number;

-- КОНТРОЛЬНЫЙ ЗАПРОС №2. Стартовый список и статус заявок.
SELECT d.discipline_name, ac.category_name, p.full_name,
       rs.status_name AS application_status
FROM registrations r
JOIN participants p ON p.participant_id = r.participant_id
JOIN registration_statuses rs ON rs.registration_status_id = r.registration_status_id
JOIN program_events pe ON pe.program_event_id = r.program_event_id
JOIN disciplines d ON d.discipline_id = pe.discipline_id
JOIN age_categories ac ON ac.age_category_id = pe.age_category_id
ORDER BY d.distance_meters, ac.category_name, p.full_name;

-- КОНТРОЛЬНЫЙ ЗАПРОС №3. Итоговый протокол по всем стартам.
-- RANK вычисляет место по времени внутри каждого отдельного старта.
SELECT d.discipline_name, ac.category_name, p.full_name,
       ROUND(res.finish_time_ms / 1000.0, 3) AS finish_seconds,
       RANK() OVER (
         PARTITION BY pe.program_event_id
         ORDER BY res.finish_time_ms
       ) AS place
FROM results res
JOIN registrations r ON r.registration_id = res.registration_id
JOIN participants p ON p.participant_id = r.participant_id
JOIN program_events pe ON pe.program_event_id = r.program_event_id
JOIN disciplines d ON d.discipline_id = pe.discipline_id
JOIN age_categories ac ON ac.age_category_id = pe.age_category_id
WHERE res.outcome = 'FINISHED'
ORDER BY d.distance_meters, ac.category_name, place;