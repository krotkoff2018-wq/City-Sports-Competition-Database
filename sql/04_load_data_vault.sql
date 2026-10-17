-- Запустить ПОСЛЕ загрузки 3NF (02_demo_variant4.sql) и создания схемы (03...)
-- Отдельная транзакция; не удаляет данные 3NF.
BEGIN;
-- HUBS
INSERT INTO data_vault.hub_organization (organization_hk, organization_name)
SELECT data_vault.dv_key('ORG', o.organization_name), o.organization_name FROM city_sport.organizations o WHERE o.organization_name IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.hub_venue (venue_hk, venue_business_key)
SELECT data_vault.dv_key('VENUE', v.venue_name || '|' || v.address), v.venue_name || '|' || v.address FROM city_sport.venues v WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.hub_competition (competition_hk, competition_code)
SELECT data_vault.dv_key('COMP', c.competition_code), c.competition_code FROM city_sport.competitions c WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.hub_stage_type (stage_type_hk, stage_code)
SELECT data_vault.dv_key('STAGE', st.stage_code), st.stage_code FROM city_sport.stage_types st WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.hub_program_event (program_event_hk, event_business_key)
SELECT data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name), c.competition_code || '|' || d.discipline_name || '|' || ac.category_name FROM city_sport.program_events pe JOIN city_sport.competitions c ON c.competition_id=pe.competition_id JOIN city_sport.disciplines d ON d.discipline_id=pe.discipline_id JOIN city_sport.age_categories ac ON ac.age_category_id=pe.age_category_id WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.hub_participant (participant_hk, participant_email)
SELECT data_vault.dv_key('PARTICIPANT', p.email), p.email FROM city_sport.participants p WHERE p.email IS NOT NULL
ON CONFLICT DO NOTHING;

-- LINKS
INSERT INTO data_vault.link_competition_organization (competition_organization_hk, competition_hk, organization_hk)
SELECT data_vault.dv_key('LINK_COMPETITION_ORGANIZATION', (data_vault.dv_key('COMP', c.competition_code))::text || '|' || (data_vault.dv_key('ORG', o.organization_name))::text), data_vault.dv_key('COMP', c.competition_code), data_vault.dv_key('ORG', o.organization_name)
FROM city_sport.competitions c JOIN city_sport.organizations o ON o.organization_id=c.organization_id
WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.link_competition_venue (competition_venue_hk, competition_hk, venue_hk)
SELECT data_vault.dv_key('LINK_COMPETITION_VENUE', (data_vault.dv_key('COMP', c.competition_code))::text || '|' || (data_vault.dv_key('VENUE', v.venue_name || '|' || v.address))::text), data_vault.dv_key('COMP', c.competition_code), data_vault.dv_key('VENUE', v.venue_name || '|' || v.address)
FROM city_sport.competitions c JOIN city_sport.venues v ON v.venue_id=c.venue_id
WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.link_competition_stage (competition_stage_hk, competition_hk, stage_type_hk)
SELECT data_vault.dv_key('LINK_COMPETITION_STAGE', (data_vault.dv_key('COMP', c.competition_code))::text || '|' || (data_vault.dv_key('STAGE', st.stage_code))::text), data_vault.dv_key('COMP', c.competition_code), data_vault.dv_key('STAGE', st.stage_code)
FROM city_sport.competition_stages cs JOIN city_sport.competitions c ON c.competition_id=cs.competition_id JOIN city_sport.stage_types st ON st.stage_type_id=cs.stage_type_id
WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.link_competition_program_event (competition_program_event_hk, competition_hk, program_event_hk)
SELECT data_vault.dv_key('LINK_COMPETITION_PROGRAM_EVENT', (data_vault.dv_key('COMP', c.competition_code))::text || '|' || (data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name))::text), data_vault.dv_key('COMP', c.competition_code), data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name)
FROM city_sport.program_events pe JOIN city_sport.competitions c ON c.competition_id=pe.competition_id JOIN city_sport.disciplines d ON d.discipline_id=pe.discipline_id JOIN city_sport.age_categories ac ON ac.age_category_id=pe.age_category_id
WHERE TRUE
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.link_registration (registration_hk, program_event_hk, participant_hk)
SELECT data_vault.dv_key('LINK_REGISTRATION', (data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name))::text || '|' || (data_vault.dv_key('PARTICIPANT', p.email))::text), data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name), data_vault.dv_key('PARTICIPANT', p.email)
FROM city_sport.registrations r JOIN city_sport.participants p ON p.participant_id=r.participant_id JOIN city_sport.program_events pe ON pe.program_event_id=r.program_event_id JOIN city_sport.competitions c ON c.competition_id=pe.competition_id JOIN city_sport.disciplines d ON d.discipline_id=pe.discipline_id JOIN city_sport.age_categories ac ON ac.age_category_id=pe.age_category_id
WHERE p.email IS NOT NULL
ON CONFLICT DO NOTHING;

-- SATELLITES; повторный импорт неизменившейся версии пропускается.
INSERT INTO data_vault.sat_organization_details (organization_hk, hashdiff, contact_email, contact_phone)
SELECT data_vault.dv_key('ORG', o.organization_name), data_vault.dv_hashdiff((o.contact_email)::text, (o.contact_phone)::text),
       o.contact_email, o.contact_phone
FROM city_sport.organizations o
WHERE (TRUE) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_organization_details s
  WHERE s.organization_hk = data_vault.dv_key('ORG', o.organization_name) AND s.hashdiff = data_vault.dv_hashdiff((o.contact_email)::text, (o.contact_phone)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_venue_details (venue_hk, hashdiff, spectator_capacity)
SELECT data_vault.dv_key('VENUE', v.venue_name || '|' || v.address), data_vault.dv_hashdiff((v.spectator_capacity)::text),
       v.spectator_capacity
FROM city_sport.venues v
WHERE (TRUE) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_venue_details s
  WHERE s.venue_hk = data_vault.dv_key('VENUE', v.venue_name || '|' || v.address) AND s.hashdiff = data_vault.dv_hashdiff((v.spectator_capacity)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_competition_details (competition_hk, hashdiff, competition_name, status_code, start_at, end_at, registration_deadline, description)
SELECT data_vault.dv_key('COMP', c.competition_code), data_vault.dv_hashdiff((c.competition_name)::text, (cs.status_code)::text, (c.start_at)::text, (c.end_at)::text, (c.registration_deadline)::text, (c.description)::text),
       c.competition_name, cs.status_code, c.start_at, c.end_at, c.registration_deadline, c.description
FROM city_sport.competitions c JOIN city_sport.competition_statuses cs ON cs.status_id=c.status_id
WHERE (TRUE) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_competition_details s
  WHERE s.competition_hk = data_vault.dv_key('COMP', c.competition_code) AND s.hashdiff = data_vault.dv_hashdiff((c.competition_name)::text, (cs.status_code)::text, (c.start_at)::text, (c.end_at)::text, (c.registration_deadline)::text, (c.description)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_stage_type_details (stage_type_hk, hashdiff, stage_name)
SELECT data_vault.dv_key('STAGE', st.stage_code), data_vault.dv_hashdiff((st.stage_name)::text),
       st.stage_name
FROM city_sport.stage_types st
WHERE (TRUE) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_stage_type_details s
  WHERE s.stage_type_hk = data_vault.dv_key('STAGE', st.stage_code) AND s.hashdiff = data_vault.dv_hashdiff((st.stage_name)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_competition_stage_details (competition_stage_hk, hashdiff, step_number, planned_start_at, planned_end_at, stage_status_code, responsible_staff_name)
SELECT data_vault.dv_key('LINK_COMPETITION_STAGE', data_vault.dv_key('COMP', c.competition_code)::text || '|' || data_vault.dv_key('STAGE', st.stage_code)::text), data_vault.dv_hashdiff((stage.step_number)::text, (stage.planned_start_at)::text, (stage.planned_end_at)::text, (ss.status_code)::text, (staff.full_name)::text),
       stage.step_number, stage.planned_start_at, stage.planned_end_at, ss.status_code, staff.full_name
FROM city_sport.competition_stages stage JOIN city_sport.competitions c ON c.competition_id=stage.competition_id JOIN city_sport.stage_types st ON st.stage_type_id=stage.stage_type_id JOIN city_sport.stage_statuses ss ON ss.stage_status_id=stage.stage_status_id LEFT JOIN city_sport.staff_members staff ON staff.staff_id=stage.responsible_staff_id
WHERE (TRUE) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_competition_stage_details s
  WHERE s.competition_stage_hk = data_vault.dv_key('LINK_COMPETITION_STAGE', data_vault.dv_key('COMP', c.competition_code)::text || '|' || data_vault.dv_key('STAGE', st.stage_code)::text) AND s.hashdiff = data_vault.dv_hashdiff((stage.step_number)::text, (stage.planned_start_at)::text, (stage.planned_end_at)::text, (ss.status_code)::text, (staff.full_name)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_program_event_details (program_event_hk, hashdiff, discipline_name, distance_meters, category_name, min_age, max_age, scheduled_start_at, participant_limit)
SELECT data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name), data_vault.dv_hashdiff((d.discipline_name)::text, (d.distance_meters)::text, (ac.category_name)::text, (ac.min_age)::text, (ac.max_age)::text, (pe.scheduled_start_at)::text, (pe.participant_limit)::text),
       d.discipline_name, d.distance_meters, ac.category_name, ac.min_age, ac.max_age, pe.scheduled_start_at, pe.participant_limit
FROM city_sport.program_events pe JOIN city_sport.competitions c ON c.competition_id=pe.competition_id JOIN city_sport.disciplines d ON d.discipline_id=pe.discipline_id JOIN city_sport.age_categories ac ON ac.age_category_id=pe.age_category_id
WHERE (TRUE) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_program_event_details s
  WHERE s.program_event_hk = data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name) AND s.hashdiff = data_vault.dv_hashdiff((d.discipline_name)::text, (d.distance_meters)::text, (ac.category_name)::text, (ac.min_age)::text, (ac.max_age)::text, (pe.scheduled_start_at)::text, (pe.participant_limit)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_participant_details (participant_hk, hashdiff, full_name, birth_date, phone)
SELECT data_vault.dv_key('PARTICIPANT', p.email), data_vault.dv_hashdiff((p.full_name)::text, (p.birth_date)::text, (p.phone)::text),
       p.full_name, p.birth_date, p.phone
FROM city_sport.participants p
WHERE (p.email IS NOT NULL) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_participant_details s
  WHERE s.participant_hk = data_vault.dv_key('PARTICIPANT', p.email) AND s.hashdiff = data_vault.dv_hashdiff((p.full_name)::text, (p.birth_date)::text, (p.phone)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_registration_details (registration_hk, hashdiff, registration_status_code, registered_at)
SELECT data_vault.dv_key('LINK_REGISTRATION', data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name)::text || '|' || data_vault.dv_key('PARTICIPANT', p.email)::text), data_vault.dv_hashdiff((rs.status_code)::text, (r.registered_at)::text),
       rs.status_code, r.registered_at
FROM city_sport.registrations r JOIN city_sport.registration_statuses rs ON rs.registration_status_id=r.registration_status_id JOIN city_sport.participants p ON p.participant_id=r.participant_id JOIN city_sport.program_events pe ON pe.program_event_id=r.program_event_id JOIN city_sport.competitions c ON c.competition_id=pe.competition_id JOIN city_sport.disciplines d ON d.discipline_id=pe.discipline_id JOIN city_sport.age_categories ac ON ac.age_category_id=pe.age_category_id
WHERE (p.email IS NOT NULL) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_registration_details s
  WHERE s.registration_hk = data_vault.dv_key('LINK_REGISTRATION', data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name)::text || '|' || data_vault.dv_key('PARTICIPANT', p.email)::text) AND s.hashdiff = data_vault.dv_hashdiff((rs.status_code)::text, (r.registered_at)::text)
)
ON CONFLICT DO NOTHING;

INSERT INTO data_vault.sat_result_details (registration_hk, hashdiff, outcome, finish_time_ms, recorded_at)
SELECT data_vault.dv_key('LINK_REGISTRATION', data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name)::text || '|' || data_vault.dv_key('PARTICIPANT', p.email)::text), data_vault.dv_hashdiff((res.outcome)::text, (res.finish_time_ms)::text, (res.recorded_at)::text),
       res.outcome, res.finish_time_ms, res.recorded_at
FROM city_sport.results res JOIN city_sport.registrations r ON r.registration_id=res.registration_id JOIN city_sport.participants p ON p.participant_id=r.participant_id JOIN city_sport.program_events pe ON pe.program_event_id=r.program_event_id JOIN city_sport.competitions c ON c.competition_id=pe.competition_id JOIN city_sport.disciplines d ON d.discipline_id=pe.discipline_id JOIN city_sport.age_categories ac ON ac.age_category_id=pe.age_category_id
WHERE (p.email IS NOT NULL) AND NOT EXISTS (
  SELECT 1 FROM data_vault.sat_result_details s
  WHERE s.registration_hk = data_vault.dv_key('LINK_REGISTRATION', data_vault.dv_key('EVENT', c.competition_code || '|' || d.discipline_name || '|' || ac.category_name)::text || '|' || data_vault.dv_key('PARTICIPANT', p.email)::text) AND s.hashdiff = data_vault.dv_hashdiff((res.outcome)::text, (res.finish_time_ms)::text, (res.recorded_at)::text)
)
ON CONFLICT DO NOTHING;

COMMIT;