-- AcademicOS web — ilk şema
-- Bu dosya tablo sahibi rol (academicos_owner) ile çalıştırılır.
-- Uygulama ayrı, RLS'ye tabi bir rol (academicos_app) ile bağlanır.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Geçerli istek kullanıcısını işlem (transaction) değişkeninden okur.
CREATE OR REPLACE FUNCTION app_current_user() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

-- ---------------------------------------------------------------
-- Kimlik doğrulama tabloları (yalnızca auth modülü erişir)
-- ---------------------------------------------------------------
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL,
  name          text NOT NULL,
  password_hash text NOT NULL,
  timezone      text NOT NULL DEFAULT 'Europe/Nicosia',
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE auth_sessions (
  id          text PRIMARY KEY,               -- oturum belirtecinin SHA-256 özeti
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL
);
CREATE INDEX auth_sessions_user_idx ON auth_sessions (user_id);

CREATE TABLE login_attempts (
  id         bigserial PRIMARY KEY,
  key        text NOT NULL,
  success    boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX login_attempts_key_idx ON login_attempts (key, created_at);

-- ---------------------------------------------------------------
-- Akademik veri (kullanıcıya özel, RLS ile izole)
-- ---------------------------------------------------------------
CREATE TABLE courses (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code        text NOT NULL,
  name        text NOT NULL,
  instructor  text,                                  -- NULL = belirtilmedi
  delivery    text NOT NULL DEFAULT 'yuz_yuze' CHECK (delivery IN ('yuz_yuze','cevrimici')),
  notes       text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX courses_user_idx ON courses (user_id);

CREATE TABLE course_meetings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id   uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  weekday     smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),  -- 1 = Pazartesi
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  CHECK (end_time > start_time)
);
CREATE INDEX course_meetings_course_idx ON course_meetings (course_id);

CREATE TABLE topics (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id   uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title       text NOT NULL,
  week        smallint CHECK (week BETWEEN 1 AND 20),
  description text NOT NULL DEFAULT '',
  status      text NOT NULL DEFAULT 'materyal_eksik' CHECK (status IN (
                'materyal_eksik','materyal_alindi','okundu','not_cikarildi',
                'soru_calisildi','tekrar_gerekiyor','tamamlandi')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX topics_course_idx ON topics (course_id);

CREATE TABLE sources (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id          uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  topic_id           uuid REFERENCES topics(id) ON DELETE SET NULL,
  title              text NOT NULL,
  kind               text NOT NULL CHECK (kind IN ('hoca','kendi_notum','arkadas','akademik','diger')),
  filename           text NOT NULL,
  mime               text NOT NULL,
  size_bytes         integer NOT NULL,
  sha256             text NOT NULL,
  file_type          text NOT NULL,     -- pdf, docx, pptx, txt, srt, vtt, image
  extraction_status  text NOT NULL CHECK (extraction_status IN ('tamam','metin_yok','hata','desteklenmiyor')),
  extraction_note    text NOT NULL DEFAULT '',
  unit_count         integer NOT NULL DEFAULT 0,   -- sayfa / slayt / altyazı bloğu sayısı
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sources_course_idx ON sources (course_id);

CREATE TABLE source_files (
  source_id  uuid PRIMARY KEY REFERENCES sources(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content    bytea NOT NULL
);

CREATE TABLE source_chunks (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_id     uuid NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  ord           integer NOT NULL,
  locator_type  text NOT NULL CHECK (locator_type IN ('sayfa','slayt','zaman','bolum')),
  locator       text NOT NULL,
  content       text NOT NULL,
  tsv           tsvector GENERATED ALWAYS AS (to_tsvector('turkish'::regconfig, content)) STORED
);
CREATE INDEX source_chunks_source_idx ON source_chunks (source_id, ord);
CREATE INDEX source_chunks_tsv_idx ON source_chunks USING gin (tsv);

CREATE TABLE notes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id   uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  topic_id    uuid REFERENCES topics(id) ON DELETE SET NULL,
  title       text NOT NULL,
  body        text NOT NULL,
  origin      text NOT NULL DEFAULT 'kullanici' CHECK (origin IN ('kullanici','yapay_zeka')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notes_course_idx ON notes (course_id);

CREATE TABLE assessments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id   uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('vize','final','odev','proje','sunum','quiz','diger')),
  title       text NOT NULL,
  due_at      timestamptz,             -- NULL = "Tarih bekleniyor"
  weight      numeric(5,2) CHECK (weight IS NULL OR (weight >= 0 AND weight <= 100)),
  score       numeric(5,2) CHECK (score IS NULL OR (score >= 0 AND score <= 100)),
  notes       text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX assessments_course_idx ON assessments (course_id);

CREATE TABLE study_sessions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id              uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  topic_id               uuid REFERENCES topics(id) ON DELETE SET NULL,
  mode                   text NOT NULL CHECK (mode IN (
                           'konu_anlatimi','sokratik','sinav_hazirligi','aktif_hatirlama',
                           'derinlemesine','gazetecilik','tartisma','eksik_tamamlama','hizli_tekrar','okuma')),
  goal                   text NOT NULL DEFAULT '',
  source_ids             uuid[] NOT NULL DEFAULT '{}',
  only_selected_sources  boolean NOT NULL DEFAULT true,
  status                 text NOT NULL DEFAULT 'aktif' CHECK (status IN ('aktif','tamamlandi')),
  started_at             timestamptz NOT NULL DEFAULT now(),
  last_activity_at       timestamptz NOT NULL DEFAULT now(),
  ended_at               timestamptz
);
CREATE INDEX study_sessions_user_idx ON study_sessions (user_id, last_activity_at DESC);

CREATE TABLE session_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id  uuid NOT NULL REFERENCES study_sessions(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('ogrenci','ogretmen','sistem')),
  content     text NOT NULL,
  citations   jsonb NOT NULL DEFAULT '[]',
  provider    text,
  model       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX session_messages_session_idx ON session_messages (session_id, created_at);

CREATE TABLE questions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id    uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  topic_id     uuid REFERENCES topics(id) ON DELETE SET NULL,
  source_id    uuid REFERENCES sources(id) ON DELETE SET NULL,
  type         text NOT NULL CHECK (type IN (
                 'coktan_secmeli','dogru_yanlis','kisa_cevap','bosluk_doldurma',
                 'kavram_aciklama','karsilastirma','acik_uclu','vaka_analizi','eslestirme')),
  prompt       text NOT NULL,
  options      jsonb NOT NULL DEFAULT '[]',   -- çoktan seçmeli şıklar / eşleştirme sağ sütun
  answer       jsonb NOT NULL DEFAULT 'null', -- doğru cevap (nesnel türler)
  rubric       text NOT NULL DEFAULT '',      -- açık uçlu türler için değerlendirme ölçütü
  explanation  text NOT NULL DEFAULT '',
  concept      text NOT NULL DEFAULT '',
  origin       text NOT NULL DEFAULT 'kullanici' CHECK (origin IN ('kullanici','yapay_zeka','ogretim_elemani')),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX questions_course_idx ON questions (course_id);

CREATE TABLE attempts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id     uuid NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  session_id      uuid REFERENCES study_sessions(id) ON DELETE SET NULL,
  response        jsonb NOT NULL,
  is_correct      boolean,                 -- NULL = henüz değerlendirilmedi
  score           numeric(5,2),
  grading_method  text NOT NULL CHECK (grading_method IN ('otomatik','yapay_zeka','oz_degerlendirme','bekliyor')),
  feedback        text NOT NULL DEFAULT '',
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX attempts_question_idx ON attempts (question_id, created_at DESC);
CREATE INDEX attempts_session_idx ON attempts (session_id);

CREATE TABLE mistakes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id  uuid NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  attempt_id   uuid NOT NULL REFERENCES attempts(id) ON DELETE CASCADE,
  concept      text NOT NULL DEFAULT '',
  status       text NOT NULL DEFAULT 'acik' CHECK (status IN ('acik','cozuldu')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at  timestamptz
);
CREATE INDEX mistakes_user_idx ON mistakes (user_id, status);

CREATE TABLE review_cards (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id       uuid NOT NULL UNIQUE REFERENCES questions(id) ON DELETE CASCADE,
  ease              numeric(4,2) NOT NULL DEFAULT 2.5,
  interval_days     integer NOT NULL DEFAULT 0,
  repetitions       integer NOT NULL DEFAULT 0,
  lapses            integer NOT NULL DEFAULT 0,
  due_at            timestamptz NOT NULL DEFAULT now(),
  last_reviewed_at  timestamptz
);
CREATE INDEX review_cards_due_idx ON review_cards (user_id, due_at);

CREATE TABLE review_log (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  card_id        uuid NOT NULL REFERENCES review_cards(id) ON DELETE CASCADE,
  quality        smallint NOT NULL CHECK (quality BETWEEN 0 AND 5),
  interval_days  integer NOT NULL,
  ease           numeric(4,2) NOT NULL,
  reviewed_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- Row Level Security: her satır yalnızca sahibine görünür.
-- FORCE: tablo sahibi rol bile politikaya tabidir.
-- ---------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'courses','course_meetings','topics','sources','source_files','source_chunks',
    'notes','assessments','study_sessions','session_messages','questions','attempts',
    'mistakes','review_cards','review_log'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I USING (user_id = app_current_user()) WITH CHECK (user_id = app_current_user())',
      t || '_owner_only', t);
  END LOOP;
END $$;
