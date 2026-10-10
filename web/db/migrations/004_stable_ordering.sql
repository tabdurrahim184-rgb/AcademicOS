-- Aynı işlemde eklenen satırlar now() ile aynı zamanı alıyordu; sıralama belirsizdi.
-- clock_timestamp() her satır için gerçek ekleme anını verir.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['courses','topics','sources','notes','assessments','questions','attempts','mistakes','session_messages','plan_tasks'] LOOP
    EXECUTE format('ALTER TABLE %I ALTER COLUMN created_at SET DEFAULT clock_timestamp()', t);
  END LOOP;
END $$;
ALTER TABLE study_sessions ALTER COLUMN started_at SET DEFAULT clock_timestamp();
