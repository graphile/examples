#!/bin/bash
set -e
set -x
export NODE_ENV=development

# This will generate passwords that are safe to use in envvars without needing to be escaped:
GENERATED_PASSWORD="$(openssl rand -base64 30 | tr '+/' '-_')"
GENERATED_PASSWORD2="$(openssl rand -base64 30 | tr '+/' '-_')"

# This is our '.env' config file, we're writing it now so that if something goes wrong we won't lose the passwords.
cat >> .env <<CONFIG
export ROOT_DATABASE_URL="postgresql://graphiledemo:$GENERATED_PASSWORD@localhost/graphiledemo"
export AUTH_DATABASE_URL="postgresql://graphiledemo_authenticator:$GENERATED_PASSWORD2@localhost/graphiledemo"
export TEST_ROOT_DATABASE_URL="postgresql://graphiledemo:$GENERATED_PASSWORD@localhost/graphiledemo_test"
export TEST_AUTH_DATABASE_URL="postgresql://graphiledemo_authenticator:$GENERATED_PASSWORD2@localhost/graphiledemo_test"
export SECRET="$(openssl rand -base64 48)"
export JWT_SECRET="$(openssl rand -base64 48)"
export CLIENT_PORT=8350
export PORT=8349
export ROOT_DOMAIN="localhost:\$PORT"
export ROOT_URL="http://\$ROOT_DOMAIN"
export REDIS_URL="redis://localhost/3"

# Create an application, then add the secrets below https://github.com/settings/applications/new
# Name: GraphileDemo
# Homepage URL: http://localhost:8349
# Authorization callback URL: http://localhost:8349/auth/github/callback
# Client ID:
export GITHUB_KEY=""
# Client Secret:
export GITHUB_SECRET=""
CONFIG

# To source our .env file from the shell it has to be executable.
chmod +x .env

# Now we'll create the roles, databases and extensions in PostgreSQL:
psql -X -v ON_ERROR_STOP=1 template1 <<SQL
-- Ref: https://devcenter.heroku.com/articles/heroku-postgresql#connection-permissions

-- This is the root role for the database
CREATE ROLE graphiledemo WITH LOGIN PASSWORD '${GENERATED_PASSWORD}' SUPERUSER;

-- This is the no-access role that PostGraphile will run as by default
CREATE ROLE graphiledemo_authenticator WITH LOGIN PASSWORD '${GENERATED_PASSWORD2}' NOINHERIT;

-- This is the role that PostGraphile will switch to (from graphiledemo_authenticator) during a transaction
CREATE ROLE graphiledemo_visitor;

-- This enables PostGraphile to switch from graphiledemo_authenticator to graphiledemo_visitor
GRANT graphiledemo_visitor TO graphiledemo_authenticator;

-- Here's our main database
CREATE DATABASE graphiledemo OWNER graphiledemo;
REVOKE ALL ON DATABASE graphiledemo FROM PUBLIC;
GRANT CONNECT ON DATABASE graphiledemo TO graphiledemo;
GRANT CONNECT ON DATABASE graphiledemo TO graphiledemo_authenticator;
GRANT ALL ON DATABASE graphiledemo TO graphiledemo;

-- Some extensions require superuser privileges, so we create them before migration time.
\\connect graphiledemo
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS plv8;

-- This is a copy of the setup above for our test database
CREATE DATABASE graphiledemo_test OWNER graphiledemo;
REVOKE ALL ON DATABASE graphiledemo_test FROM PUBLIC;
GRANT CONNECT ON DATABASE graphiledemo_test TO graphiledemo;
GRANT CONNECT ON DATABASE graphiledemo_test TO graphiledemo_authenticator;
GRANT ALL ON DATABASE graphiledemo_test TO graphiledemo;
\\connect graphiledemo_test
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS plv8;
SQL

# All done
echo "✅ Setup success"
psql -X1 -v ON_ERROR_STOP=1 graphiledemo -f db/schema.sql
