#!/bin/bash
set -e
export NODE_ENV=development

if [ -x .env ]; then
  . ./.env
  if [ "$SUPERUSER_PASSWORD" = "" ]; then
    echo ".env already exists, but it doesn't define SUPERUSER_PASSWORD - aborting!"
    exit 1;
  fi
  if [ "$AUTH_USER_PASSWORD" = "" ]; then
    echo ".env already exists, but it doesn't define AUTH_USER_PASSWORD - aborting!"
    exit 1;
  fi
  echo "Configuration already exists, using existing secrets."
else
  # This will generate passwords that are safe to use in envvars without needing to be escaped:
  SUPERUSER_PASSWORD="$(openssl rand -base64 30 | tr '+/' '-_')"
  AUTH_USER_PASSWORD="$(openssl rand -base64 30 | tr '+/' '-_')"

  # This is our '.env' config file, we're writing it now so that if something goes wrong we won't lose the passwords.
  cat >> .env <<CONFIG
# Password for the 'graphiledemo' user, which owns the database
export SUPERUSER_PASSWORD="$SUPERUSER_PASSWORD"

# Password for the 'graphiledemo_authenticator' user, which has very limited
# privileges, but can switch into graphiledemo_visitor
export AUTH_USER_PASSWORD="$AUTH_USER_PASSWORD"

# This secret is used for signing cookies
export SECRET="$(openssl rand -base64 48)"

# This secret is used for signing JWT tokens (we don't use this by default)
export JWT_SECRET="$(openssl rand -base64 48)"


# These are the connection strings for the DB and the test DB.
export ROOT_DATABASE_URL="postgresql://graphiledemo:\$SUPERUSER_PASSWORD@localhost/graphiledemo"
export AUTH_DATABASE_URL="postgresql://graphiledemo_authenticator:\$AUTH_USER_PASSWORD@localhost/graphiledemo"
export TEST_ROOT_DATABASE_URL="postgresql://graphiledemo:\$SUPERUSER_PASSWORD@localhost/graphiledemo_test"
export TEST_AUTH_DATABASE_URL="postgresql://graphiledemo_authenticator:\$AUTH_USER_PASSWORD@localhost/graphiledemo_test"

# This port is the one you'll connect to
export PORT=8349

# This is the port that create-react-app runs as, don't connect to it directly
export CLIENT_PORT=8350

# This is needed any time we use absolute URLs, e.g. for OAuth callback URLs
export ROOT_DOMAIN="localhost:\$PORT"
export ROOT_URL="http://\$ROOT_DOMAIN"

# Our session store uses redis
export REDIS_URL="redis://localhost/3"

# Create a GitHub application, by visiting
# https://github.com/settings/applications/new and then enter the Client
# ID/Secret below
#
#   Name: GraphileDemo
#   Homepage URL: http://localhost:8349
#   Authorization callback URL: http://localhost:8349/auth/github/callback
#
# Client ID:
export GITHUB_KEY=""
# Client Secret:
export GITHUB_SECRET=""
CONFIG
  echo "Passwords generated and configuration written to .env"

  # To source our .env file from the shell it has to be executable.
  chmod +x .env
fi

echo "Installing or reinstalling the roles and database..."
# Now we can reset the database
psql -X -v ON_ERROR_STOP=1 template1 <<SQL
-- RESET database
DROP DATABASE IF EXISTS graphiledemo;
DROP DATABASE IF EXISTS graphiledemo_test;
DROP ROLE IF EXISTS graphiledemo_visitor;
DROP ROLE IF EXISTS graphiledemo_admin;
DROP ROLE IF EXISTS graphiledemo_authenticator;
DROP ROLE IF EXISTS graphiledemo;

-- Now to set up the database cleanly:

-- Ref: https://devcenter.heroku.com/articles/heroku-postgresql#connection-permissions

-- This is the root role for the database
CREATE ROLE graphiledemo WITH LOGIN PASSWORD '${SUPERUSER_PASSWORD}' SUPERUSER;

-- This is the no-access role that PostGraphile will run as by default
CREATE ROLE graphiledemo_authenticator WITH LOGIN PASSWORD '${AUTH_USER_PASSWORD}' NOINHERIT;

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
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- This is a copy of the setup above for our test database
CREATE DATABASE graphiledemo_test OWNER graphiledemo;
REVOKE ALL ON DATABASE graphiledemo_test FROM PUBLIC;
GRANT CONNECT ON DATABASE graphiledemo_test TO graphiledemo;
GRANT CONNECT ON DATABASE graphiledemo_test TO graphiledemo_authenticator;
GRANT ALL ON DATABASE graphiledemo_test TO graphiledemo;
\\connect graphiledemo_test
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SQL

echo "Roles and databases created, now sourcing the initial database schema"
psql -X1 -v ON_ERROR_STOP=1 graphiledemo -f db/jobs.sql
psql -X1 -v ON_ERROR_STOP=1 graphiledemo -f db/schema.sql
# All done
echo "✅ Setup success"
