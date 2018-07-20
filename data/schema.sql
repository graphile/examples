--
-- PostgreSQL database dump
--

-- Dumped from database version 10.4
-- Dumped by pg_dump version 10.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: app_jobs; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_jobs;


--
-- Name: app_private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_private;


--
-- Name: app_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA app_public;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: jobs; Type: TABLE; Schema: app_jobs; Owner: -
--

CREATE TABLE app_jobs.jobs (
    id integer NOT NULL,
    queue_name character varying DEFAULT (public.gen_random_uuid())::character varying NOT NULL,
    task_identifier character varying NOT NULL,
    payload json DEFAULT '{}'::json NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    last_error character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: add_job(character varying, json); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.add_job(identifier character varying, payload json) RETURNS app_jobs.jobs
    LANGUAGE sql
    AS $$
  INSERT INTO app_jobs.jobs(task_identifier, payload) VALUES(identifier, payload) RETURNING *;
$$;


--
-- Name: add_job(character varying, character varying, json); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.add_job(identifier character varying, queue_name character varying, payload json) RETURNS app_jobs.jobs
    LANGUAGE sql
    AS $$
  INSERT INTO app_jobs.jobs(task_identifier, queue_name, payload) VALUES(identifier, queue_name, payload) RETURNING *;
$$;


--
-- Name: complete_job(character varying, integer); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.complete_job(worker_id character varying, job_id integer) RETURNS app_jobs.jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_row app_jobs.jobs;
BEGIN
  DELETE FROM app_jobs.jobs
    WHERE id = job_id
    RETURNING * INTO v_row;

  UPDATE app_jobs.job_queues
    SET locked_by = null, locked_at = null
    WHERE queue_name = v_row.queue_name AND locked_by = worker_id;

  RETURN v_row;
END;
$$;


--
-- Name: do_notify(); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.do_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM pg_notify(TG_ARGV[0], '');
  RETURN NEW;
END;
$$;


--
-- Name: fail_job(character varying, integer, character varying); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.fail_job(worker_id character varying, job_id integer, error_message character varying) RETURNS app_jobs.jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_row app_jobs.jobs;
BEGIN
  UPDATE app_jobs.jobs
    SET
      last_error = error_message,
      run_at = greatest(now(), run_at) + (exp(least(attempts, 10))::text || ' seconds')::interval
    WHERE id = job_id
    RETURNING * INTO v_row;

  UPDATE app_jobs.job_queues
    SET locked_by = null, locked_at = null
    WHERE queue_name = v_row.queue_name AND locked_by = worker_id;

  RETURN v_row;
END;
$$;


--
-- Name: get_job(character varying, character varying[]); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.get_job(worker_id character varying, identifiers character varying[]) RETURNS app_jobs.jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_job_id int;
  v_queue_name varchar;
  v_default_job_expiry text = (4 * 60 * 60)::text;
  v_default_job_maximum_attempts text = '25';
  v_row app_jobs.jobs;
BEGIN
  IF worker_id IS NULL OR length(worker_id) < 10 THEN
    RAISE EXCEPTION 'Invalid worker ID';
  END IF;

  SELECT job_queues.queue_name, jobs.id INTO v_queue_name, v_job_id
    FROM app_jobs.job_queues
    INNER JOIN app_jobs.jobs USING (queue_name)
    WHERE (locked_at IS NULL OR locked_at < (now() - (COALESCE(current_setting('jobs.expiry', true), v_default_job_expiry) || ' seconds')::interval))
    AND run_at <= now()
    AND attempts < COALESCE(current_setting('jobs.maximum_attempts', true), v_default_job_maximum_attempts)::int
    AND (identifiers IS NULL OR task_identifier = any(identifiers))
    ORDER BY priority ASC, run_at ASC, id ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

  IF v_queue_name IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE app_jobs.job_queues
    SET
      locked_by = worker_id,
      locked_at = now()
    WHERE job_queues.queue_name = v_queue_name;

  UPDATE app_jobs.jobs
    SET attempts = attempts + 1
    WHERE id = v_job_id
    RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;


--
-- Name: jobs__decrease_job_queue_count(); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.jobs__decrease_job_queue_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE app_jobs.job_queues
    SET job_count = job_queues.job_count - 1
    WHERE queue_name = OLD.queue_name
    AND job_queues.job_count > 1;

  IF NOT FOUND THEN
    DELETE FROM app_jobs.job_queues WHERE queue_name = OLD.queue_name;
  END IF;

  RETURN OLD;
END;
$$;


--
-- Name: jobs__increase_job_queue_count(); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.jobs__increase_job_queue_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO app_jobs.job_queues(queue_name, job_count)
    VALUES(NEW.queue_name, 1)
    ON CONFLICT (queue_name) DO UPDATE SET job_count = job_queues.job_count + 1;

  RETURN NEW;
END;
$$;


--
-- Name: schedule_job(character varying, character varying, json, timestamp with time zone); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.schedule_job(identifier character varying, queue_name character varying, payload json, run_at timestamp with time zone) RETURNS app_jobs.jobs
    LANGUAGE sql
    AS $$
  INSERT INTO app_jobs.jobs(task_identifier, queue_name, payload, run_at) VALUES(identifier, queue_name, payload, run_at) RETURNING *;
$$;


--
-- Name: update_timestamps(); Type: FUNCTION; Schema: app_jobs; Owner: -
--

CREATE FUNCTION app_jobs.update_timestamps() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_at = NOW();
    NEW.updated_at = NOW();
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.created_at = OLD.created_at;
    NEW.updated_at = GREATEST(NOW(), OLD.updated_at + INTERVAL '1 millisecond');
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: users; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.users (
    id integer NOT NULL,
    username public.citext NOT NULL,
    name text,
    avatar_url text,
    is_admin boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_avatar_url_check CHECK ((avatar_url ~ '^https?://[^/]+'::text)),
    CONSTRAINT users_username_check CHECK ((username OPERATOR(public.~) '^[a-zA-Z]([a-zA-Z0-9][_]?)+$'::public.citext))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.users IS '@omit all
A user who can log in to the application.';


--
-- Name: COLUMN users.id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.id IS 'Unique identifier for the user.';


--
-- Name: COLUMN users.username; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.username IS 'Public-facing username (or ''handle'') of the user.';


--
-- Name: COLUMN users.name; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.name IS 'Public-facing name (or pseudonym) of the user.';


--
-- Name: COLUMN users.avatar_url; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.avatar_url IS 'Optional avatar URL.';


--
-- Name: COLUMN users.is_admin; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.users.is_admin IS 'If true, the user has elevated privileges.';


--
-- Name: link_or_register_user(integer, character varying, character varying, json, json); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.link_or_register_user(f_user_id integer, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json) RETURNS app_public.users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO "$user", public
    AS $$
declare
  v_matched_user_id int;
  v_matched_authentication_id int;
  v_email citext;
  v_name text;
  v_avatar_url text;
  v_user app_public.users;
  v_user_email app_public.user_emails;
begin
  -- See if a user account already matches these details
  select id, user_id
    into v_matched_authentication_id, v_matched_user_id
    from app_public.user_authentications
    where service = f_service
    and identifier = f_identifier
    limit 1;

  if v_matched_user_id is not null and f_user_id is not null and v_matched_user_id <> f_user_id then
    raise exception 'A different user already has this account linked.' using errcode='TAKEN';
  end if;

  v_email = f_profile ->> 'email';
  v_name := f_profile ->> 'name';
  v_avatar_url := f_profile ->> 'avatar_url';

  if v_matched_authentication_id is null then
    if f_user_id is not null then
      -- Link new account to logged in user account
      insert into app_public.user_authentications (user_id, service, identifier, details) values
        (f_user_id, f_service, f_identifier, f_profile) returning id, user_id into v_matched_authentication_id, v_matched_user_id;
      insert into app_private.user_authentication_secrets (user_authentication_id, details) values
        (v_matched_authentication_id, f_auth_details);
    elsif v_email is not null then
      -- See if the email is registered
      select * into v_user_email from app_public.user_emails where email = v_email and is_verified is true;
      if v_user_email is not null then
        -- User exists!
        insert into app_public.user_authentications (user_id, service, identifier, details) values
          (v_user_email.user_id, f_service, f_identifier, f_profile) returning id, user_id into v_matched_authentication_id, v_matched_user_id;
        insert into app_private.user_authentication_secrets (user_authentication_id, details) values
          (v_matched_authentication_id, f_auth_details);
      end if;
    end if;
  end if;
  if v_matched_user_id is null and f_user_id is null and v_matched_authentication_id is null then
    -- Create and return a new user account
    return app_private.register_user(f_service, f_identifier, f_profile, f_auth_details, true);
  else
    if v_matched_authentication_id is not null then
      update app_public.user_authentications
        set details = f_profile
        where id = v_matched_authentication_id;
      update app_private.user_authentication_secrets
        set details = f_auth_details
        where user_authentication_id = v_matched_authentication_id;
      update app_public.users
        set
          name = coalesce(users.name, v_name),
          avatar_url = coalesce(users.avatar_url, v_avatar_url)
        where id = v_matched_user_id
        returning  * into v_user;
      return v_user;
    else
      -- v_matched_authentication_id is null
      -- -> v_matched_user_id is null (they're paired)
      -- -> f_user_id is not null (because the if clause above)
      -- -> v_matched_authentication_id is not null (because of the separate if block above creating a user_authentications)
      -- -> contradiction.
      raise exception 'This should not occur';
    end if;
  end if;
end;
$$;


--
-- Name: FUNCTION link_or_register_user(f_user_id integer, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.link_or_register_user(f_user_id integer, f_service character varying, f_identifier character varying, f_profile json, f_auth_details json) IS 'If you''re logged in, this will link an additional OAuth login to your account if necessary. If you''re logged out it may find if an account already exists (based on OAuth details or email address) and return that, or create a new user account if necessary.';


--
-- Name: login(text, text); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.login(username text, password text) RETURNS app_public.users
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO "$user", public
    AS $$
declare
  v_user app_public.users;
  v_user_secret app_private.user_secrets;
  v_login_attempt_window_duration interval = interval '6 hours';
begin
  select users.* into v_user
  from app_public.users
  where
    -- Match username against users username, or any verified email address
    (
      users.username = login.username
    or
      exists(
        select 1
        from app_public.user_emails
        where user_id = users.id
        and is_verified is true
        and email = login.username::citext
      )
    );

  if not (v_user is null) then
    -- Load their secrets
    select * into v_user_secret from app_private.user_secrets
    where user_secrets.user_id = v_user.id;

    -- Have there been too many login attempts?
    if (
      v_user_secret.first_failed_password_attempt is not null
    and
      v_user_secret.first_failed_password_attempt > NOW() - v_login_attempt_window_duration
    and
      v_user_secret.password_attempts >= 20
    ) then
      raise exception 'User account locked - too many login attempts' using errcode = 'LOCKD';
    end if;

    -- Not too many login attempts, let's check the password
    if v_user_secret.password_hash = crypt(password, v_user_secret.password_hash) then
      -- Excellent - they're loggged in! Let's reset the attempt tracking
      update app_private.user_secrets
      set password_attempts = 0, first_failed_password_attempt = null
      where user_id = v_user.id;
      return v_user;
    else
      -- Wrong password, bump all the attempt tracking figures
      update app_private.user_secrets
      set
        password_attempts = (case when first_failed_password_attempt is null or first_failed_password_attempt < now() - v_login_attempt_window_duration then 1 else password_attempts + 1 end),
        first_failed_password_attempt = (case when first_failed_password_attempt is null or first_failed_password_attempt < now() - v_login_attempt_window_duration then now() else first_failed_password_attempt end)
      where user_id = v_user.id;
      return null;
    end if;
  else
    -- No user with that email/username was found
    return null;
  end if;
end;
$$;


--
-- Name: FUNCTION login(username text, password text); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.login(username text, password text) IS 'Returns a user that matches the username/password combo, or null on failure.';


--
-- Name: really_create_user(text, text, boolean, text, text, text); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.really_create_user(username text, email text, email_is_verified boolean, name text, avatar_url text, password text DEFAULT NULL::text) RETURNS app_public.users
    LANGUAGE plpgsql
    SET search_path TO "$user", public
    AS $$
declare
  v_user app_public.users;
  v_username text = username;
begin
  -- Sanitise the username, and make it unique if necessary.
  if v_username is null then
    v_username = coalesce(name, 'user');
  end if;
  v_username = regexp_replace(v_username, '^[^a-z]+', '', 'i');
  v_username = regexp_replace(v_username, '[^a-z0-9]+', '_', 'i');
  if v_username is null or length(v_username) < 3 then
    v_username = 'user';
  end if;
  select (
    case
    when i = 0 then v_username
    else v_username || i::text
    end
  ) into v_username from generate_series(0, 1000) i
  where not exists(
    select 1
    from app_public.users
    where users.username = (
      case
      when i = 0 then v_username
      else v_username || i::text
      end
    )
  )
  limit 1;

  -- Insert the new user
  insert into app_public.users (username, name, avatar_url) values
    (v_username, name, avatar_url)
    returning * into v_user;

	-- Add the user's email
  if email is not null then
    insert into app_public.user_emails (user_id, email, is_verified)
    values (v_user.id, email, email_is_verified);
  end if;

  -- Store the password
  if password is not null then
    update app_private.user_secrets
    set password_hash = crypt(password, gen_salt('bf'))
    where user_id = v_user.id;
  end if;

  return v_user;
end;
$$;


--
-- Name: FUNCTION really_create_user(username text, email text, email_is_verified boolean, name text, avatar_url text, password text); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.really_create_user(username text, email text, email_is_verified boolean, name text, avatar_url text, password text) IS 'Creates a user account. All arguments are optional, it trusts the calling method to perform sanitisation.';


--
-- Name: register_user(character varying, character varying, json, json, boolean); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean DEFAULT false) RETURNS app_public.users
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO "$user", public
    AS $$
declare
  v_user app_public.users;
  v_email citext;
  v_name text;
  v_username text;
  v_avatar_url text;
  v_user_authentication_id int;
begin
  -- Extract data from the user’s OAuth profile data.
  v_email := f_profile ->> 'email';
  v_name := f_profile ->> 'name';
  v_username := f_profile ->> 'username';
  v_avatar_url := f_profile ->> 'avatar_url';

  -- Create the user account
  v_user = app_private.really_create_user(
    username => v_username,
    email => v_email,
    email_is_verified => f_email_is_verified,
    name => v_name,
    avatar_url => v_avatar_url
  );

  -- Insert the user’s private account data (e.g. OAuth tokens)
  insert into app_public.user_authentications (user_id, service, identifier, details) values
    (v_user.id, f_service, f_identifier, f_profile) returning id into v_user_authentication_id;
  insert into app_private.user_authentication_secrets (user_authentication_id, details) values
    (v_user_authentication_id, f_auth_details);

  return v_user;
end;
$$;


--
-- Name: FUNCTION register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.register_user(f_service character varying, f_identifier character varying, f_profile json, f_auth_details json, f_email_is_verified boolean) IS 'Used to register a user from information gleaned from OAuth. Primarily used by link_or_register_user';


--
-- Name: tg__add_job_for_row(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg__add_job_for_row() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO "$user", public
    AS $$
begin
  perform app_jobs.add_job(tg_argv[0], json_build_object('id', NEW.id));
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg__add_job_for_row(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg__add_job_for_row() IS 'Useful shortcut to create a job on insert or update. Pass the task name as the trigger argument, and the record id will automatically be available on the JSON payload.';


--
-- Name: tg__update_timestamps(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg__update_timestamps() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO "$user", public
    AS $$
begin
  NEW.created_at = (case when TG_OP = 'INSERT' then NOW() else OLD.created_at end);
  NEW.updated_at = (case when TG_OP = 'UPDATE' and OLD.updated_at <= NOW() then OLD.updated_at + interval '1 millisecond' else NOW() end);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg__update_timestamps(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg__update_timestamps() IS 'This trigger should be called on all tables with created_at, updated_at - it ensures that they cannot be manipulated and that updated_at will always be larger than the previous updated_at.';


--
-- Name: tg_user_email_secrets__insert_with_user_email(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg_user_email_secrets__insert_with_user_email() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO "$user", public
    AS $$
declare
  v_verification_token text;
begin
  if NEW.is_verified is false then
    v_verification_token = encode(gen_random_bytes(4), 'hex');
  end if;
  insert into app_private.user_email_secrets(user_email_id, verification_token) values(NEW.id, v_verification_token);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg_user_email_secrets__insert_with_user_email(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg_user_email_secrets__insert_with_user_email() IS 'Ensures that every user_email record has an associated user_email_secret record.';


--
-- Name: tg_user_secrets__insert_with_user(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg_user_secrets__insert_with_user() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO "$user", public
    AS $$
begin
  insert into app_private.user_secrets(user_id) values(NEW.id);
  return NEW;
end;
$$;


--
-- Name: FUNCTION tg_user_secrets__insert_with_user(); Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON FUNCTION app_private.tg_user_secrets__insert_with_user() IS 'Ensures that every user record has an associated user_secret record.';


--
-- Name: tg_users__make_first_user_admin(); Type: FUNCTION; Schema: app_private; Owner: -
--

CREATE FUNCTION app_private.tg_users__make_first_user_admin() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO "$user", public
    AS $$
begin
  if not exists(select 1 from app_public.users) then
    NEW.is_admin = true;
  end if;
  return NEW;
end;
$$;


--
-- Name: current_user(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public."current_user"() RETURNS app_public.users
    LANGUAGE sql STABLE
    SET search_path TO "$user", public
    AS $$
  select users.* from app_public.users where id = app_public.current_user_id();
$$;


--
-- Name: current_user_id(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_id() RETURNS integer
    LANGUAGE sql STABLE
    SET search_path TO "$user", public
    AS $$
  select nullif(current_setting('jwt.claims.user_id', true), '')::int;
$$;


--
-- Name: FUNCTION current_user_id(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.current_user_id() IS '@omit
Handy method to get the current user ID for use in RLS policies, etc; in GraphQL, use `currentUser{id}` instead.';


--
-- Name: current_user_is_admin(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.current_user_is_admin() RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO "$user", public
    AS $$
  -- We're using exists here because it guarantees true/false rather than true/false/null
  select exists(
    select 1 from app_public.users where id = app_public.current_user_id() and is_admin = true
	);
$$;


--
-- Name: FUNCTION current_user_is_admin(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.current_user_is_admin() IS '@omit
Handy method to determine if the current user is an admin, for use in RLS policies, etc; in GraphQL should use `currentUser{isAdmin}` instead.';


--
-- Name: forgot_password(text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.forgot_password(email text) RETURNS boolean
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO "$user", public
    AS $$
declare
  v_user_email app_public.user_emails;
  v_reset_token text;
  v_reset_min_duration_between_emails interval = interval '30 minutes';
  v_reset_max_duration interval = interval '3 days';
begin
  -- Find the matching user_email
  select user_emails.* into v_user_email
  from app_public.user_emails
  where user_emails.email = forgot_password.email::citext
  order by is_verified desc, id desc;

  if not (v_user_email is null) then
    -- See if we've triggered a reset recently
    if exists(
      select 1
      from app_private.user_email_secrets
      where user_email_id = v_user_email.id
      and password_reset_email_sent_at is not null
      and password_reset_email_sent_at > now() - v_reset_min_duration_between_emails
    ) then
      return true;
    end if;

    -- Fetch or generate reset token
    update app_private.user_secrets
    set
      reset_password_token = (
        case
        when reset_password_token is null or reset_password_token_generated < NOW() - v_reset_max_duration
        then encode(gen_random_bytes(6), 'hex')
        else reset_password_token
        end
      ),
      reset_password_token_generated = (
        case
        when reset_password_token is null or reset_password_token_generated < NOW() - v_reset_max_duration
        then now()
        else reset_password_token_generated
        end
      )
    where user_id = v_user_email.user_id
    returning reset_password_token into v_reset_token;

    -- Don't allow spamming an email
    update app_private.user_email_secrets
    set password_reset_email_sent_at = now()
    where user_email_id = v_user_email.id;

    -- Trigger email send
    perform app_jobs.add_job('user__forgot_password', json_build_object('id', v_user_email.user_id, 'email', v_user_email.email::text, 'token', v_reset_token));
    return true;

  end if;
  return false;
end;
$$;


--
-- Name: FUNCTION forgot_password(email text); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.forgot_password(email text) IS '@resultFieldName success
If you''ve forgotten your password, give us one of your email addresses and we'' send you a reset token. Note this only works if you have added an email address!';


--
-- Name: forums; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.forums (
    id integer NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT forums_name_check CHECK ((length(name) > 0)),
    CONSTRAINT forums_slug_check CHECK (((length(slug) < 30) AND (slug ~ '^([a-z0-9]-?)+$'::text)))
);


--
-- Name: TABLE forums; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.forums IS 'A subject-based grouping of topics and posts.';


--
-- Name: COLUMN forums.slug; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.forums.slug IS 'An URL-safe alias for the `Forum`.';


--
-- Name: COLUMN forums.name; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.forums.name IS 'The name of the `Forum` (indicates its subject matter).';


--
-- Name: COLUMN forums.description; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.forums.description IS 'A brief description of the `Forum` including it''s purpose.';


--
-- Name: forums_about_cats(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.forums_about_cats() RETURNS SETOF app_public.forums
    LANGUAGE sql STABLE
    AS $$
  select * from app_public.forums where slug like 'cat-%';
$$;


--
-- Name: random_number(); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.random_number() RETURNS integer
    LANGUAGE sql STABLE
    AS $$
  select 4;
$$;


--
-- Name: FUNCTION random_number(); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.random_number() IS 'Chosen by fair dice roll. Guaranteed to be random. XKCD#221';


--
-- Name: reset_password(integer, text, text); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.reset_password(user_id integer, reset_token text, new_password text) RETURNS app_public.users
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO "$user", public
    AS $$
declare
  v_user app_public.users;
  v_user_secret app_private.user_secrets;
  v_reset_max_duration interval = interval '3 days';
begin
  select users.* into v_user
  from app_public.users
  where id = user_id;

  if not (v_user is null) then
    -- Load their secrets
    select * into v_user_secret from app_private.user_secrets
    where user_secrets.user_id = v_user.id;

    -- Have there been too many reset attempts?
    if (
      v_user_secret.first_failed_reset_password_attempt is not null
    and
      v_user_secret.first_failed_reset_password_attempt > NOW() - v_reset_max_duration
    and
      v_user_secret.reset_password_attempts >= 20
    ) then
      raise exception 'Password reset locked - too many reset attempts' using errcode = 'LOCKD';
    end if;

    -- Not too many reset attempts, let's check the token
    if v_user_secret.reset_password_token = reset_token then
      -- Excellent - they're legit; let's reset the password as requested
      update app_private.user_secrets
      set
        password_hash = crypt(new_password, gen_salt('bf')),
        password_attempts = 0,
        first_failed_password_attempt = null,
        reset_password_token = null,
        reset_password_token_generated = null,
        reset_password_attempts = 0,
        first_failed_reset_password_attempt = null
      where user_secrets.user_id = v_user.id;
      return v_user;
    else
      -- Wrong token, bump all the attempt tracking figures
      update app_private.user_secrets
      set
        reset_password_attempts = (case when first_failed_reset_password_attempt is null or first_failed_reset_password_attempt < now() - v_reset_max_duration then 1 else reset_password_attempts + 1 end),
        first_failed_reset_password_attempt = (case when first_failed_reset_password_attempt is null or first_failed_reset_password_attempt < now() - v_reset_max_duration then now() else first_failed_reset_password_attempt end)
      where user_secrets.user_id = v_user.id;
      return null;
    end if;
  else
    -- No user with that id was found
    return null;
  end if;
end;
$$;


--
-- Name: FUNCTION reset_password(user_id integer, reset_token text, new_password text); Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON FUNCTION app_public.reset_password(user_id integer, reset_token text, new_password text) IS 'After triggering forgotPassword, you''ll be sent a reset token. Combine this with your user ID and a new password to reset your password.';


--
-- Name: topics; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.topics (
    id integer NOT NULL,
    forum_id integer NOT NULL,
    user_id integer DEFAULT app_public.current_user_id() NOT NULL,
    title text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT topics_title_check CHECK ((length(title) > 0))
);


--
-- Name: TABLE topics; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.topics IS '@omit all
An individual message thread within a Forum.';


--
-- Name: COLUMN topics.title; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.title IS 'The title of the `Topic`.';


--
-- Name: COLUMN topics.body; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.topics.body IS 'The body of the `Topic`, which Posts reply to.';


--
-- Name: topics_body_summary(app_public.topics, integer); Type: FUNCTION; Schema: app_public; Owner: -
--

CREATE FUNCTION app_public.topics_body_summary(t app_public.topics, max_length integer DEFAULT 30) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO "$user", public
    AS $$
  select case
    when length(t.body) > max_length
    then left(t.body, max_length - 3) || '...'
    else t.body
    end;
$$;


--
-- Name: job_queues; Type: TABLE; Schema: app_jobs; Owner: -
--

CREATE TABLE app_jobs.job_queues (
    queue_name character varying NOT NULL,
    job_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp with time zone,
    locked_by character varying
);


--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: app_jobs; Owner: -
--

CREATE SEQUENCE app_jobs.jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: app_jobs; Owner: -
--

ALTER SEQUENCE app_jobs.jobs_id_seq OWNED BY app_jobs.jobs.id;


--
-- Name: user_authentication_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_authentication_secrets (
    user_authentication_id integer NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: user_email_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_email_secrets (
    user_email_id integer NOT NULL,
    verification_token text,
    password_reset_email_sent_at timestamp with time zone
);


--
-- Name: TABLE user_email_secrets; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON TABLE app_private.user_email_secrets IS 'The contents of this table should never be visible to the user. Contains data mostly related to email verification and avoiding spamming users.';


--
-- Name: COLUMN user_email_secrets.password_reset_email_sent_at; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON COLUMN app_private.user_email_secrets.password_reset_email_sent_at IS 'We store the time the last password reset was sent to this email to prevent the email getting flooded.';


--
-- Name: user_secrets; Type: TABLE; Schema: app_private; Owner: -
--

CREATE TABLE app_private.user_secrets (
    user_id integer NOT NULL,
    password_hash text,
    password_attempts integer DEFAULT 0 NOT NULL,
    first_failed_password_attempt timestamp with time zone,
    reset_password_token text,
    reset_password_token_generated timestamp with time zone,
    reset_password_attempts integer DEFAULT 0 NOT NULL,
    first_failed_reset_password_attempt timestamp with time zone
);


--
-- Name: TABLE user_secrets; Type: COMMENT; Schema: app_private; Owner: -
--

COMMENT ON TABLE app_private.user_secrets IS 'The contents of this table should never be visible to the user. Contains data mostly related to authentication.';


--
-- Name: forums_id_seq; Type: SEQUENCE; Schema: app_public; Owner: -
--

CREATE SEQUENCE app_public.forums_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forums_id_seq; Type: SEQUENCE OWNED BY; Schema: app_public; Owner: -
--

ALTER SEQUENCE app_public.forums_id_seq OWNED BY app_public.forums.id;


--
-- Name: posts; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.posts (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    user_id integer DEFAULT app_public.current_user_id() NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE posts; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.posts IS '@omit all
An individual message thread within a Forum.';


--
-- Name: COLUMN posts.id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.posts.id IS '@omit create,update';


--
-- Name: COLUMN posts.topic_id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.posts.topic_id IS '@omit update';


--
-- Name: COLUMN posts.user_id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.posts.user_id IS '@omit create,update';


--
-- Name: COLUMN posts.body; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.posts.body IS 'The body of the `Topic`, which Posts reply to.';


--
-- Name: COLUMN posts.created_at; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.posts.created_at IS '@omit create,update';


--
-- Name: COLUMN posts.updated_at; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.posts.updated_at IS '@omit create,update';


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: app_public; Owner: -
--

CREATE SEQUENCE app_public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: app_public; Owner: -
--

ALTER SEQUENCE app_public.posts_id_seq OWNED BY app_public.posts.id;


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: app_public; Owner: -
--

CREATE SEQUENCE app_public.topics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: app_public; Owner: -
--

ALTER SEQUENCE app_public.topics_id_seq OWNED BY app_public.topics.id;


--
-- Name: user_authentications; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.user_authentications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    service text NOT NULL,
    identifier text NOT NULL,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE user_authentications; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.user_authentications IS '@omit all
Contains information about the login providers this user has used, so that they may disconnect them should they wish.';


--
-- Name: COLUMN user_authentications.user_id; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.user_id IS '@omit';


--
-- Name: COLUMN user_authentications.service; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.service IS 'The login service used, e.g. `twitter` or `github`.';


--
-- Name: COLUMN user_authentications.identifier; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.identifier IS 'A unique identifier for the user within the login service.';


--
-- Name: COLUMN user_authentications.details; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_authentications.details IS '@omit
Additional profile details extracted from this login method';


--
-- Name: user_authentications_id_seq; Type: SEQUENCE; Schema: app_public; Owner: -
--

CREATE SEQUENCE app_public.user_authentications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_authentications_id_seq; Type: SEQUENCE OWNED BY; Schema: app_public; Owner: -
--

ALTER SEQUENCE app_public.user_authentications_id_seq OWNED BY app_public.user_authentications.id;


--
-- Name: user_emails; Type: TABLE; Schema: app_public; Owner: -
--

CREATE TABLE app_public.user_emails (
    id integer NOT NULL,
    user_id integer DEFAULT app_public.current_user_id() NOT NULL,
    email public.citext NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_emails_email_check CHECK ((email OPERATOR(public.~) '[^@]+@[^@]+\.[^@]+'::public.citext))
);


--
-- Name: TABLE user_emails; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON TABLE app_public.user_emails IS '@omit all
Information about a user''s email address.';


--
-- Name: COLUMN user_emails.email; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_emails.email IS 'The users email address, in `a@b.c` format.';


--
-- Name: COLUMN user_emails.is_verified; Type: COMMENT; Schema: app_public; Owner: -
--

COMMENT ON COLUMN app_public.user_emails.is_verified IS 'True if the user has is_verified their email address (by clicking the link in the email we sent them, or logging in with a social login provider), false otherwise.';


--
-- Name: user_emails_id_seq; Type: SEQUENCE; Schema: app_public; Owner: -
--

CREATE SEQUENCE app_public.user_emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: app_public; Owner: -
--

ALTER SEQUENCE app_public.user_emails_id_seq OWNED BY app_public.user_emails.id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: app_public; Owner: -
--

CREATE SEQUENCE app_public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: app_public; Owner: -
--

ALTER SEQUENCE app_public.users_id_seq OWNED BY app_public.users.id;


--
-- Name: jobs id; Type: DEFAULT; Schema: app_jobs; Owner: -
--

ALTER TABLE ONLY app_jobs.jobs ALTER COLUMN id SET DEFAULT nextval('app_jobs.jobs_id_seq'::regclass);


--
-- Name: forums id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.forums ALTER COLUMN id SET DEFAULT nextval('app_public.forums_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.posts ALTER COLUMN id SET DEFAULT nextval('app_public.posts_id_seq'::regclass);


--
-- Name: topics id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics ALTER COLUMN id SET DEFAULT nextval('app_public.topics_id_seq'::regclass);


--
-- Name: user_authentications id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications ALTER COLUMN id SET DEFAULT nextval('app_public.user_authentications_id_seq'::regclass);


--
-- Name: user_emails id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails ALTER COLUMN id SET DEFAULT nextval('app_public.user_emails_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.users ALTER COLUMN id SET DEFAULT nextval('app_public.users_id_seq'::regclass);


--
-- Name: job_queues job_queues_pkey; Type: CONSTRAINT; Schema: app_jobs; Owner: -
--

ALTER TABLE ONLY app_jobs.job_queues
    ADD CONSTRAINT job_queues_pkey PRIMARY KEY (queue_name);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: app_jobs; Owner: -
--

ALTER TABLE ONLY app_jobs.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: user_authentication_secrets user_authentication_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_authentication_secrets
    ADD CONSTRAINT user_authentication_secrets_pkey PRIMARY KEY (user_authentication_id);


--
-- Name: user_email_secrets user_email_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_email_secrets
    ADD CONSTRAINT user_email_secrets_pkey PRIMARY KEY (user_email_id);


--
-- Name: user_secrets user_secrets_pkey; Type: CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_secrets
    ADD CONSTRAINT user_secrets_pkey PRIMARY KEY (user_id);


--
-- Name: forums forums_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.forums
    ADD CONSTRAINT forums_pkey PRIMARY KEY (id);


--
-- Name: forums forums_slug_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.forums
    ADD CONSTRAINT forums_slug_key UNIQUE (slug);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: user_authentications uniq_user_authentications; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT uniq_user_authentications UNIQUE (service, identifier);


--
-- Name: user_authentications user_authentications_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT user_authentications_pkey PRIMARY KEY (id);


--
-- Name: user_emails user_emails_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails
    ADD CONSTRAINT user_emails_pkey PRIMARY KEY (id);


--
-- Name: user_emails user_emails_user_id_email_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails
    ADD CONSTRAINT user_emails_user_id_email_key UNIQUE (user_id, email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: uniq_user_emails_verified_email; Type: INDEX; Schema: app_public; Owner: -
--

CREATE UNIQUE INDEX uniq_user_emails_verified_email ON app_public.user_emails USING btree (email) WHERE (is_verified IS TRUE);


--
-- Name: jobs _100_timestamps; Type: TRIGGER; Schema: app_jobs; Owner: -
--

CREATE TRIGGER _100_timestamps BEFORE INSERT OR UPDATE ON app_jobs.jobs FOR EACH ROW EXECUTE PROCEDURE app_jobs.update_timestamps();


--
-- Name: jobs _500_decrease_job_queue_count; Type: TRIGGER; Schema: app_jobs; Owner: -
--

CREATE TRIGGER _500_decrease_job_queue_count BEFORE DELETE ON app_jobs.jobs FOR EACH ROW EXECUTE PROCEDURE app_jobs.jobs__decrease_job_queue_count();


--
-- Name: jobs _500_increase_job_queue_count; Type: TRIGGER; Schema: app_jobs; Owner: -
--

CREATE TRIGGER _500_increase_job_queue_count AFTER INSERT ON app_jobs.jobs FOR EACH ROW EXECUTE PROCEDURE app_jobs.jobs__increase_job_queue_count();


--
-- Name: jobs _900_notify_worker; Type: TRIGGER; Schema: app_jobs; Owner: -
--

CREATE TRIGGER _900_notify_worker AFTER INSERT ON app_jobs.jobs FOR EACH STATEMENT EXECUTE PROCEDURE app_jobs.do_notify('jobs:insert');


--
-- Name: users _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps AFTER INSERT OR UPDATE ON app_public.users FOR EACH ROW EXECUTE PROCEDURE app_private.tg__update_timestamps();


--
-- Name: user_emails _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps AFTER INSERT OR UPDATE ON app_public.user_emails FOR EACH ROW EXECUTE PROCEDURE app_private.tg__update_timestamps();


--
-- Name: user_authentications _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps AFTER INSERT OR UPDATE ON app_public.user_authentications FOR EACH ROW EXECUTE PROCEDURE app_private.tg__update_timestamps();


--
-- Name: forums _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps AFTER INSERT OR UPDATE ON app_public.forums FOR EACH ROW EXECUTE PROCEDURE app_private.tg__update_timestamps();


--
-- Name: topics _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps AFTER INSERT OR UPDATE ON app_public.topics FOR EACH ROW EXECUTE PROCEDURE app_private.tg__update_timestamps();


--
-- Name: posts _100_timestamps; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _100_timestamps AFTER INSERT OR UPDATE ON app_public.posts FOR EACH ROW EXECUTE PROCEDURE app_private.tg__update_timestamps();


--
-- Name: users _200_make_first_user_admin; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _200_make_first_user_admin BEFORE INSERT ON app_public.users FOR EACH ROW EXECUTE PROCEDURE app_private.tg_users__make_first_user_admin();


--
-- Name: users _500_insert_secrets; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_insert_secrets AFTER INSERT ON app_public.users FOR EACH ROW EXECUTE PROCEDURE app_private.tg_user_secrets__insert_with_user();


--
-- Name: user_emails _500_insert_secrets; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _500_insert_secrets AFTER INSERT ON app_public.user_emails FOR EACH ROW EXECUTE PROCEDURE app_private.tg_user_email_secrets__insert_with_user_email();


--
-- Name: user_emails _900_send_verification_email; Type: TRIGGER; Schema: app_public; Owner: -
--

CREATE TRIGGER _900_send_verification_email AFTER INSERT ON app_public.user_emails FOR EACH ROW WHEN ((new.is_verified IS FALSE)) EXECUTE PROCEDURE app_private.tg__add_job_for_row('user_emails__send_verification');


--
-- Name: user_authentication_secrets user_authentication_secrets_user_authentication_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_authentication_secrets
    ADD CONSTRAINT user_authentication_secrets_user_authentication_id_fkey FOREIGN KEY (user_authentication_id) REFERENCES app_public.user_authentications(id) ON DELETE CASCADE;


--
-- Name: user_email_secrets user_email_secrets_user_email_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_email_secrets
    ADD CONSTRAINT user_email_secrets_user_email_id_fkey FOREIGN KEY (user_email_id) REFERENCES app_public.user_emails(id) ON DELETE CASCADE;


--
-- Name: user_secrets user_secrets_user_id_fkey; Type: FK CONSTRAINT; Schema: app_private; Owner: -
--

ALTER TABLE ONLY app_private.user_secrets
    ADD CONSTRAINT user_secrets_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id);


--
-- Name: posts posts_topic_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.posts
    ADD CONSTRAINT posts_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES app_public.topics(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: topics topics_forum_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT topics_forum_id_fkey FOREIGN KEY (forum_id) REFERENCES app_public.forums(id) ON DELETE CASCADE;


--
-- Name: topics topics_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.topics
    ADD CONSTRAINT topics_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: user_authentications user_authentications_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_authentications
    ADD CONSTRAINT user_authentications_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: user_emails user_emails_user_id_fkey; Type: FK CONSTRAINT; Schema: app_public; Owner: -
--

ALTER TABLE ONLY app_public.user_emails
    ADD CONSTRAINT user_emails_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_public.users(id) ON DELETE CASCADE;


--
-- Name: job_queues; Type: ROW SECURITY; Schema: app_jobs; Owner: -
--

ALTER TABLE app_jobs.job_queues ENABLE ROW LEVEL SECURITY;

--
-- Name: user_authentication_secrets; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.user_authentication_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: user_email_secrets; Type: ROW SECURITY; Schema: app_private; Owner: -
--

ALTER TABLE app_private.user_email_secrets ENABLE ROW LEVEL SECURITY;

--
-- Name: forums delete_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_admin ON app_public.forums FOR DELETE USING (app_public.current_user_is_admin());


--
-- Name: topics delete_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_admin ON app_public.topics FOR DELETE USING (((user_id = app_public.current_user_id()) OR app_public.current_user_is_admin()));


--
-- Name: posts delete_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_admin ON app_public.posts FOR DELETE USING (((user_id = app_public.current_user_id()) OR app_public.current_user_is_admin()));


--
-- Name: user_emails delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.user_emails FOR DELETE USING ((user_id = app_public.current_user_id()));


--
-- Name: user_authentications delete_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_own ON app_public.user_authentications FOR DELETE USING ((user_id = app_public.current_user_id()));


--
-- Name: users delete_self; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY delete_self ON app_public.users FOR DELETE USING ((id = app_public.current_user_id()));


--
-- Name: forums; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.forums ENABLE ROW LEVEL SECURITY;

--
-- Name: forums insert_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_admin ON app_public.forums FOR INSERT WITH CHECK (app_public.current_user_is_admin());


--
-- Name: topics insert_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_admin ON app_public.topics FOR INSERT WITH CHECK ((user_id = app_public.current_user_id()));


--
-- Name: posts insert_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_admin ON app_public.posts FOR INSERT WITH CHECK ((user_id = app_public.current_user_id()));


--
-- Name: user_emails insert_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY insert_own ON app_public.user_emails FOR INSERT WITH CHECK ((user_id = app_public.current_user_id()));


--
-- Name: posts; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.posts ENABLE ROW LEVEL SECURITY;

--
-- Name: users select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.users FOR SELECT USING (true);


--
-- Name: forums select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.forums FOR SELECT USING (true);


--
-- Name: topics select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.topics FOR SELECT USING (true);


--
-- Name: posts select_all; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_all ON app_public.posts FOR SELECT USING (true);


--
-- Name: user_emails select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.user_emails FOR SELECT USING ((user_id = app_public.current_user_id()));


--
-- Name: user_authentications select_own; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY select_own ON app_public.user_authentications FOR SELECT USING ((user_id = app_public.current_user_id()));


--
-- Name: topics; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.topics ENABLE ROW LEVEL SECURITY;

--
-- Name: forums update_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_admin ON app_public.forums FOR UPDATE USING (app_public.current_user_is_admin());


--
-- Name: topics update_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_admin ON app_public.topics FOR UPDATE USING (((user_id = app_public.current_user_id()) OR app_public.current_user_is_admin()));


--
-- Name: posts update_admin; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_admin ON app_public.posts FOR UPDATE USING (((user_id = app_public.current_user_id()) OR app_public.current_user_is_admin()));


--
-- Name: users update_self; Type: POLICY; Schema: app_public; Owner: -
--

CREATE POLICY update_self ON app_public.users FOR UPDATE USING ((id = app_public.current_user_id()));


--
-- Name: user_authentications; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.user_authentications ENABLE ROW LEVEL SECURITY;

--
-- Name: user_emails; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.user_emails ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: app_public; Owner: -
--

ALTER TABLE app_public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA app_public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA app_public TO graphiledemo_visitor;


--
-- Name: TABLE users; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.users TO graphiledemo_visitor;


--
-- Name: COLUMN users.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(name) ON TABLE app_public.users TO graphiledemo_visitor;


--
-- Name: COLUMN users.avatar_url; Type: ACL; Schema: app_public; Owner: -
--

GRANT UPDATE(avatar_url) ON TABLE app_public.users TO graphiledemo_visitor;


--
-- Name: TABLE forums; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.forums TO graphiledemo_visitor;


--
-- Name: COLUMN forums.slug; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(slug),UPDATE(slug) ON TABLE app_public.forums TO graphiledemo_visitor;


--
-- Name: COLUMN forums.name; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(name),UPDATE(name) ON TABLE app_public.forums TO graphiledemo_visitor;


--
-- Name: COLUMN forums.description; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(description),UPDATE(description) ON TABLE app_public.forums TO graphiledemo_visitor;


--
-- Name: TABLE topics; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.topics TO graphiledemo_visitor;


--
-- Name: COLUMN topics.forum_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(forum_id) ON TABLE app_public.topics TO graphiledemo_visitor;


--
-- Name: COLUMN topics.title; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(title),UPDATE(title) ON TABLE app_public.topics TO graphiledemo_visitor;


--
-- Name: COLUMN topics.body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(body),UPDATE(body) ON TABLE app_public.topics TO graphiledemo_visitor;


--
-- Name: SEQUENCE forums_id_seq; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE app_public.forums_id_seq TO graphiledemo_visitor;


--
-- Name: TABLE posts; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.posts TO graphiledemo_visitor;


--
-- Name: COLUMN posts.topic_id; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(topic_id) ON TABLE app_public.posts TO graphiledemo_visitor;


--
-- Name: COLUMN posts.body; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(body),UPDATE(body) ON TABLE app_public.posts TO graphiledemo_visitor;


--
-- Name: SEQUENCE posts_id_seq; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE app_public.posts_id_seq TO graphiledemo_visitor;


--
-- Name: SEQUENCE topics_id_seq; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE app_public.topics_id_seq TO graphiledemo_visitor;


--
-- Name: TABLE user_authentications; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.user_authentications TO graphiledemo_visitor;


--
-- Name: SEQUENCE user_authentications_id_seq; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE app_public.user_authentications_id_seq TO graphiledemo_visitor;


--
-- Name: TABLE user_emails; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,DELETE ON TABLE app_public.user_emails TO graphiledemo_visitor;


--
-- Name: COLUMN user_emails.email; Type: ACL; Schema: app_public; Owner: -
--

GRANT INSERT(email) ON TABLE app_public.user_emails TO graphiledemo_visitor;


--
-- Name: SEQUENCE user_emails_id_seq; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE app_public.user_emails_id_seq TO graphiledemo_visitor;


--
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: app_public; Owner: -
--

GRANT SELECT,USAGE ON SEQUENCE app_public.users_id_seq TO graphiledemo_visitor;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE graphiledemo IN SCHEMA app_public REVOKE ALL ON SEQUENCES  FROM graphiledemo;
ALTER DEFAULT PRIVILEGES FOR ROLE graphiledemo IN SCHEMA app_public GRANT SELECT,USAGE ON SEQUENCES  TO graphiledemo_visitor;


--
-- PostgreSQL database dump complete
--

