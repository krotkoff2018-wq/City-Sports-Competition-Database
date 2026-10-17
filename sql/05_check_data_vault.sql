-- Проверить создание Data Vault в pgAdmin → Query Tool базы city_sports_db.
SELECT
  count(*) FILTER (WHERE left(table_name, 4) = 'hub_') AS hub_tables,
  count(*) FILTER (WHERE left(table_name, 5) = 'link_') AS link_tables,
  count(*) FILTER (WHERE left(table_name, 4) = 'sat_') AS satellite_tables,
  count(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'data_vault' AND table_type = 'BASE TABLE';
-- Ожидаемо: 6 Hub, 5 Link, 9 Satellite, всего 20 таблиц.

-- Проверки результатов переноса из демонстрационной 3NF:
SELECT (SELECT count(*) FROM data_vault.hub_competition) AS competitions,
       (SELECT count(*) FROM data_vault.hub_participant) AS participants,
       (SELECT count(*) FROM data_vault.link_competition_stage) AS stages,
       (SELECT count(*) FROM data_vault.link_registration) AS registrations,
       (SELECT count(*) FROM data_vault.sat_result_details) AS results;
-- Для демонстрационных данных: 1, 3, 9, 3, 3.

-- Этапы соревнования: бизнес-ключ из Hub + характеристика из Satellite.
SELECT hc.competition_code, hst.stage_code, sat.step_number,
       sat.stage_status_code, sat.responsible_staff_name
FROM data_vault.link_competition_stage l
JOIN data_vault.hub_competition hc ON hc.competition_hk=l.competition_hk
JOIN data_vault.hub_stage_type hst ON hst.stage_type_hk=l.stage_type_hk
JOIN data_vault.sat_competition_stage_details sat ON sat.competition_stage_hk=l.competition_stage_hk
WHERE sat.load_dts=(
    SELECT max(s2.load_dts) FROM data_vault.sat_competition_stage_details s2
    WHERE s2.competition_stage_hk=l.competition_stage_hk)
ORDER BY hc.competition_code, sat.step_number;