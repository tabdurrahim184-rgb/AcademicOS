-- Docker ilk açılışta rolleri ve veritabanını oluşturur. Parolalar docker-compose ortamından gelir.
\set app_pw `echo "$APP_DB_PASSWORD"`
\set owner_pw `echo "$OWNER_DB_PASSWORD"`
CREATE ROLE academicos_owner LOGIN PASSWORD :'owner_pw' NOSUPERUSER NOBYPASSRLS;
CREATE ROLE academicos_app LOGIN PASSWORD :'app_pw' NOSUPERUSER NOBYPASSRLS;
CREATE DATABASE academicos OWNER academicos_owner;
