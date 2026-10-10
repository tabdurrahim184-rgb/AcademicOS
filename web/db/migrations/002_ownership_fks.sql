-- Güvenlik: PostgreSQL yabancı anahtar kontrolleri RLS'yi atlar. Tek kolonlu FK'ler,
-- kimliği bilinen başka bir kullanıcının kaydına referans verilmesine izin verirdi.
-- Bütün kullanıcıya ait ilişkiler (kolon, user_id) çiftiyle sahibine bağlanır.

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['courses','topics','sources','study_sessions','questions','attempts','review_cards'] LOOP
    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (id, user_id)', t, t || '_id_user_key');
  END LOOP;
END $$;

-- (tablo, kolon, hedef, silme davranışı)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('course_meetings','course_id','courses','CASCADE'),
    ('topics','course_id','courses','CASCADE'),
    ('sources','course_id','courses','CASCADE'),
    ('sources','topic_id','topics','SET NULL (topic_id)'),
    ('source_files','source_id','sources','CASCADE'),
    ('source_chunks','source_id','sources','CASCADE'),
    ('notes','course_id','courses','CASCADE'),
    ('notes','topic_id','topics','SET NULL (topic_id)'),
    ('assessments','course_id','courses','CASCADE'),
    ('study_sessions','course_id','courses','CASCADE'),
    ('study_sessions','topic_id','topics','SET NULL (topic_id)'),
    ('session_messages','session_id','study_sessions','CASCADE'),
    ('questions','course_id','courses','CASCADE'),
    ('questions','topic_id','topics','SET NULL (topic_id)'),
    ('questions','source_id','sources','SET NULL (source_id)'),
    ('attempts','question_id','questions','CASCADE'),
    ('attempts','session_id','study_sessions','SET NULL (session_id)'),
    ('mistakes','question_id','questions','CASCADE'),
    ('mistakes','attempt_id','attempts','CASCADE'),
    ('review_cards','question_id','questions','CASCADE'),
    ('review_log','card_id','review_cards','CASCADE')
  ) AS v(tbl, col, target, ondelete) LOOP
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', r.tbl, r.tbl || '_' || r.col || '_fkey');
    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I, user_id) REFERENCES %I (id, user_id) ON DELETE %s',
      r.tbl, r.tbl || '_' || r.col || '_owner_fkey', r.col, r.target, r.ondelete);
  END LOOP;
END $$;
