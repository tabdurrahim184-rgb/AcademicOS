-- Yalnızca yerel açık kaynak istemciler için ChatGPT OAuth bağlantısı.
-- Kimlik bilgileri AES-256-GCM ile şifrelenerek uygulama veritabanında tutulur.
CREATE TABLE chatgpt_connections (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  client_id text NOT NULL,
  host_id text NOT NULL,
  account_sub text NOT NULL,
  account_email text NOT NULL DEFAULT '',
  credentials_enc text NOT NULL,
  model text NOT NULL DEFAULT '',
  connected_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE chatgpt_auth_attempts (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  state text NOT NULL,
  nonce text NOT NULL,
  verifier_enc text NOT NULL,
  client_id text NOT NULL,
  host_id text NOT NULL,
  redirect_uri text NOT NULL,
  account_sub text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['chatgpt_connections','chatgpt_auth_attempts'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY %I ON %I USING (user_id = app_current_user()) WITH CHECK (user_id = app_current_user())',t || '_owner_only',t);
  END LOOP;
END $$;
