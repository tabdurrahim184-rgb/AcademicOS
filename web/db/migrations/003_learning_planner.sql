-- Öğrenme hedefleri, eminlik bilgisi, telafi işaretleri, planlayıcı ve yapay zekâ kullanım kaydı.

-- Konu: telafi (geçmiş açık) işareti
ALTER TABLE topics ADD COLUMN is_catch_up boolean NOT NULL DEFAULT false;

-- Öğrenme hedefleri
CREATE TABLE learning_objectives (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  topic_id    uuid NOT NULL,
  text        text NOT NULL CHECK (length(text) BETWEEN 3 AND 500),
  ord         integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (id, user_id),
  FOREIGN KEY (topic_id, user_id) REFERENCES topics (id, user_id) ON DELETE CASCADE
);
CREATE INDEX learning_objectives_topic_idx ON learning_objectives (topic_id, ord);

ALTER TABLE questions ADD COLUMN objective_id uuid;
ALTER TABLE questions ADD CONSTRAINT questions_objective_owner_fkey
  FOREIGN KEY (objective_id, user_id) REFERENCES learning_objectives (id, user_id) ON DELETE SET NULL (objective_id);

-- Cevap verirken öğrencinin eminlik düzeyi (aralıklı tekrar kalitesini etkiler)
ALTER TABLE attempts ADD COLUMN confidence text CHECK (confidence IN ('tahmin','kismen','emin'));
-- "Emin olduğu halde yanlış" = kavram yanılgısı
ALTER TABLE mistakes ADD COLUMN misconception boolean NOT NULL DEFAULT false;
ALTER TABLE mistakes ADD COLUMN ai_explanation text;

-- Planlayıcı ayarları (kullanıcı başına tek satır)
CREATE TABLE planner_settings (
  user_id               uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  weekday_capacity_min  integer NOT NULL DEFAULT 150 CHECK (weekday_capacity_min BETWEEN 0 AND 720),
  weekend_capacity_min  integer NOT NULL DEFAULT 180 CHECK (weekend_capacity_min BETWEEN 0 AND 720),
  max_task_min          integer NOT NULL DEFAULT 50  CHECK (max_task_min BETWEEN 15 AND 180),
  break_min             integer NOT NULL DEFAULT 10  CHECK (break_min BETWEEN 0 AND 60),
  catch_up_share        integer NOT NULL DEFAULT 60  CHECK (catch_up_share BETWEEN 0 AND 100),
  semester_end          date,
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- Ders çalışmaya uygun zaman aralıkları (haftalık tekrar eden)
CREATE TABLE availability_windows (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  weekday     smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  CHECK (end_time > start_time)
);
CREATE INDEX availability_windows_user_idx ON availability_windows (user_id, weekday);

-- Plan görevleri
CREATE TABLE plan_tasks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id       uuid NOT NULL,
  topic_id        uuid,
  kind            text NOT NULL CHECK (kind IN ('telafi','guncel','tekrar','eksik','sinav','materyal','serbest')),
  title           text NOT NULL,
  detail          text NOT NULL DEFAULT '',
  origin_key      text NOT NULL,
  scheduled_date  date NOT NULL,
  start_time      time NOT NULL,
  duration_min    integer NOT NULL CHECK (duration_min BETWEEN 5 AND 240),
  status          text NOT NULL DEFAULT 'planlandi' CHECK (status IN ('planlandi','tamamlandi','atlandi')),
  locked          boolean NOT NULL DEFAULT false,  -- kullanıcı oluşturdu/taşıdı: planlayıcı dokunmaz
  completed_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (course_id, user_id) REFERENCES courses (id, user_id) ON DELETE CASCADE,
  FOREIGN KEY (topic_id, user_id) REFERENCES topics (id, user_id) ON DELETE SET NULL (topic_id)
);
CREATE INDEX plan_tasks_user_date_idx ON plan_tasks (user_id, scheduled_date, start_time);

-- Yapay zekâ kullanım kaydı (maliyet ve limit takibi)
CREATE TABLE ai_usage (
  id             bigserial PRIMARY KEY,
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider       text NOT NULL,
  model          text NOT NULL,
  purpose        text NOT NULL,
  input_tokens   integer NOT NULL DEFAULT 0,
  output_tokens  integer NOT NULL DEFAULT 0,
  ok             boolean NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_usage_user_idx ON ai_usage (user_id, created_at);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['learning_objectives','planner_settings','availability_windows','plan_tasks','ai_usage'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I USING (user_id = app_current_user()) WITH CHECK (user_id = app_current_user())',
      t || '_owner_only', t);
  END LOOP;
END $$;
