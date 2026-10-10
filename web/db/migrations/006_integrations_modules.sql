-- DEBİM/Moodle entegrasyonu, Bölüm Projesi, Akademik Tartışmalar, İş Merkezi,
-- arka plan işleri (OCR / transkripsiyon) ve transkriptler.

-- ---------------------------------------------------------------- DEBİM / Moodle
CREATE TABLE lms_connections (
  user_id          uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  site_url         text NOT NULL,
  token_enc        text NOT NULL,            -- AES-256-GCM ile şifreli web servis anahtarı (şifre DEĞİL)
  site_name        text NOT NULL DEFAULT '',
  lms_user_id      bigint,
  lms_full_name    text NOT NULL DEFAULT '',
  connected_at     timestamptz NOT NULL DEFAULT now(),
  last_sync_at     timestamptz
);

CREATE TABLE lms_course_links (
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lms_course_id  bigint NOT NULL,
  lms_course_name text NOT NULL,
  course_id      uuid NOT NULL,
  PRIMARY KEY (user_id, lms_course_id),
  FOREIGN KEY (course_id, user_id) REFERENCES courses (id, user_id) ON DELETE CASCADE
);

CREATE TABLE lms_file_refs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_id      uuid NOT NULL,
  lms_course_id  bigint NOT NULL,
  lms_module_id  bigint NOT NULL,
  file_path      text NOT NULL,
  time_modified  bigint NOT NULL DEFAULT 0,
  imported_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, lms_module_id, file_path, time_modified),
  FOREIGN KEY (source_id, user_id) REFERENCES sources (id, user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------- Bölüm Projesi (GZT440)
CREATE TABLE project_profiles (
  user_id             uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  title               text NOT NULL DEFAULT '',
  aim                 text NOT NULL DEFAULT '',
  research_questions  text NOT NULL DEFAULT '',
  method              text NOT NULL DEFAULT '',
  format              text NOT NULL DEFAULT '',   -- haber dosyası, belgesel, araştırma raporu vb.
  advisor             text NOT NULL DEFAULT '',
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE project_entries (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('kaynak','gorusme','geribildirim','taslak','revizyon','cekim','teslim','gorev')),
  title       text NOT NULL CHECK (length(title) BETWEEN 1 AND 300),
  body        text NOT NULL DEFAULT '',
  event_date  date,
  due_date    date,
  status      text NOT NULL DEFAULT 'acik' CHECK (status IN ('acik','tamamlandi')),
  source_id   uuid,
  created_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (source_id, user_id) REFERENCES sources (id, user_id) ON DELETE SET NULL (source_id)
);
CREATE INDEX project_entries_user_idx ON project_entries (user_id, kind, created_at);

-- ---------------------------------------------------------------- Akademik Tartışmalar
CREATE TABLE debates (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id             uuid,
  theme                 text NOT NULL CHECK (theme IN ('bilim','akil','insan','ahlak','adalet','devlet','toplum','sanat','kainat','diger')),
  title                 text NOT NULL CHECK (length(title) BETWEEN 2 AND 300),
  claim                 text NOT NULL DEFAULT '',   -- tartışılan iddia (doğru anlaşılmış hâli)
  academic_context      text NOT NULL DEFAULT '',
  counter_arguments     text NOT NULL DEFAULT '',
  islamic_perspective   text NOT NULL DEFAULT '',
  class_answer          text NOT NULL DEFAULT '',   -- sınıfta söylenebilecek doğal cevap
  weaknesses            text NOT NULL DEFAULT '',   -- itirazlar ve zayıf noktalar
  uncertainties         text NOT NULL DEFAULT '',
  created_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, user_id),
  FOREIGN KEY (course_id, user_id) REFERENCES courses (id, user_id) ON DELETE SET NULL (course_id)
);

CREATE TABLE debate_sources (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  debate_id   uuid NOT NULL,
  kind        text NOT NULL CHECK (kind IN ('kuran','hadis','klasik_eser','cagdas_eser','akademik','diger')),
  reference   text NOT NULL CHECK (length(reference) BETWEEN 2 AND 500),  -- ör. "Âl-i İmrân 3/190", "Buhârî, İlim, 10"
  quote       text NOT NULL DEFAULT '',
  note        text NOT NULL DEFAULT '',
  verified    boolean NOT NULL DEFAULT false, -- öğrenci kaynağı bizzat kontrol etti mi?
  created_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  FOREIGN KEY (debate_id, user_id) REFERENCES debates (id, user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------- İş Merkezi
CREATE TABLE work_clients (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  note        text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (id, user_id),
  UNIQUE (user_id, name)
);

-- Tekrarlayan sabit iş taahhütleri (ör. canlı program). Bitiş saati bilinmiyorsa NULL.
CREATE TABLE work_commitments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id   uuid NOT NULL,
  title       text NOT NULL,
  weekday     smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_time  time NOT NULL,
  end_time    time,
  FOREIGN KEY (client_id, user_id) REFERENCES work_clients (id, user_id) ON DELETE CASCADE
);

CREATE TABLE work_tasks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id       uuid NOT NULL,
  kind            text NOT NULL CHECK (kind IN ('haber','reels','video','desifre','sosyal_medya','tasarim','web_haberi','revizyon','diger')),
  title           text NOT NULL CHECK (length(title) BETWEEN 2 AND 300),
  requested_by    text NOT NULL DEFAULT '',
  description     text NOT NULL DEFAULT '',
  due_at          timestamptz,
  priority        text NOT NULL DEFAULT 'normal' CHECK (priority IN ('dusuk','normal','yuksek','acil')),
  estimate_min    integer NOT NULL DEFAULT 60 CHECK (estimate_min BETWEEN 5 AND 1440),
  status          text NOT NULL DEFAULT 'bekliyor' CHECK (status IN ('bekliyor','yapiliyor','revizyonda','teslim_edildi','iptal')),
  scheduled_date  date,
  start_time      time,
  minute_list     jsonb NOT NULL DEFAULT '[]',   -- Reels dakika listesi: [{start, end, note}]
  created_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, user_id),
  FOREIGN KEY (client_id, user_id) REFERENCES work_clients (id, user_id) ON DELETE CASCADE
);
CREATE INDEX work_tasks_user_idx ON work_tasks (user_id, status, due_at);

CREATE TABLE work_task_history (
  id          bigserial PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  task_id     uuid NOT NULL,
  event       text NOT NULL,   -- durum değişikliği, revizyon notu
  note        text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  FOREIGN KEY (task_id, user_id) REFERENCES work_tasks (id, user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------- Arka plan işleri (OCR, transkripsiyon)
CREATE TABLE jobs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('ocr','transkripsiyon')),
  target_id   uuid NOT NULL,                    -- kaynak (OCR) veya kayıt (transkripsiyon)
  status      text NOT NULL DEFAULT 'bekliyor' CHECK (status IN ('bekliyor','calisiyor','tamamlandi','hata','iptal')),
  progress    integer NOT NULL DEFAULT 0,       -- tamamlanan birim (sayfa / parça)
  total       integer NOT NULL DEFAULT 0,
  message     text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX jobs_user_idx ON jobs (user_id, created_at DESC);

-- ---------------------------------------------------------------- Ses / video kayıtları ve transkriptler
CREATE TABLE recordings (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  archive       text NOT NULL CHECK (archive IN ('ders','is')),
  course_id     uuid,
  client_id     uuid,
  title         text NOT NULL,
  filename      text NOT NULL,
  mime          text NOT NULL,
  size_bytes    bigint NOT NULL,
  duration_sec  numeric(10,2),
  status        text NOT NULL DEFAULT 'yuklendi' CHECK (status IN ('yuklendi','desifre_ediliyor','hazir','hata')),
  created_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (id, user_id),
  FOREIGN KEY (course_id, user_id) REFERENCES courses (id, user_id) ON DELETE SET NULL (course_id),
  FOREIGN KEY (client_id, user_id) REFERENCES work_clients (id, user_id) ON DELETE SET NULL (client_id)
);

CREATE TABLE recording_files (
  recording_id  uuid PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content       bytea NOT NULL,
  FOREIGN KEY (recording_id, user_id) REFERENCES recordings (id, user_id) ON DELETE CASCADE
);

CREATE TABLE transcript_segments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recording_id  uuid NOT NULL,
  ord           integer NOT NULL,
  start_sec     numeric(10,2) NOT NULL,
  end_sec       numeric(10,2) NOT NULL,
  raw_text      text NOT NULL,           -- sağlayıcıdan gelen ham metin (değiştirilmez)
  text          text NOT NULL,           -- kullanıcının düzelttiği metin
  speaker       text,
  FOREIGN KEY (recording_id, user_id) REFERENCES recordings (id, user_id) ON DELETE CASCADE
);
CREATE INDEX transcript_segments_rec_idx ON transcript_segments (recording_id, ord);

-- OCR ile elde edilen metin düzenlenebilir; ham OCR çıktısı ayrıca saklanır.
ALTER TABLE source_chunks ADD COLUMN raw_ocr text;

-- ---------------------------------------------------------------- RLS
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'lms_connections','lms_course_links','lms_file_refs','project_profiles','project_entries','debates','debate_sources',
    'work_clients','work_commitments','work_tasks','work_task_history','jobs','recordings','recording_files','transcript_segments'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I USING (user_id = app_current_user()) WITH CHECK (user_id = app_current_user())',
      t || '_owner_only', t);
  END LOOP;
END $$;
