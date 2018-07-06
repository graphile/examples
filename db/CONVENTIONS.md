# Conventions used in this database schema:

### Naming

- snake_case for tables, functions, columns (avoids having to put them in quotes in most cases)
- plural table names (avoids conflicts with e.g. `user` built ins, is better depluralized by PostGraphile)
- trigger functions valid for one table only are named tg_[table_name]__[task_name]
- trigger functions valid for many tables are named tg__[task_name]
- trigger names should be prefixed with `_NNN_` where NNN is a three digit number that defines the priority of the trigger (use _500_ if unsure)
- prefer lowercase over UPPERCASE, except for the `NEW`, `OLD` and `TG_OP` keywords. (This is Benjie's personal preference.)

### Security

- all functions should define `set search_path from current` because of `CVE-2018-1058`
- @omit smart comments should not be used for permissions, instead deferring to PostGraphile's RBAC support
- all tables (public or not) should enable RLS
- relevant RLS policy should be defined before granting a permission
- `grant select` should never specify a column list; instead use one-to-one relations as permission boundaries

### Explicitness

- all functions should explicitly state immutable/stable/volatile
- do not override search_path for convenience - prefer to be explicit

### Functions

- if a function can be expressed as a single SQL statement it should use the `sql` language if possible. Other functions should use `plpgsql`.

### Relations

- all foreign key `references` statements should have `on delete` clauses. Some may also want `on update` clauses, but that's optional
- all comments should be defined using '"escape" string constants' - e.g. `E'...'` - because this more easily allows adding smart comments
- defining things (primary key, checks, unique constraints, etc) within the `create table` statement is preferable to adding them after

### General conventions (e.g. for PostGraphile compatibility)

- avoid plv8 and other extensions that aren't built in because they can be complex for people to install (and this is a demo project)
- functions should not use IN/OUT/INOUT parameters
- @omit smart comments should be used heavily to remove fields we don't currently need in GraphQL - we can always remove them later

### Definitions

Please adhere to the following templates (respecting newlines):


Tables:

```sql
create table <schema_name>.<table_name> (
  ...
);
```

SQL functions:

```sql
create function <fn_name>(<args...>) returns <return_value> as $$
  select ...
  from ...
  inner join ...
  on ...
  where ...
  and ...
  order by ...
  limit ...;
$$ language sql <strict?> <immutable|stable|volatile> <security definer?> set search_path from current;
```

PL/pgSQL functions:

```sql
create function <fn_name>(<args...>) returns <return_value> as $$
declare
  v_[varname] <type>[ = <default>];
  ...
begin
  if ... then
    ...
  end if;
  return <value>;
end;
$$ language plpgsql <strict?> <immutable|stable|volatile> <security definer?> set search_path from current;
```

Triggers:

```sql
create trigger _NNN_trigger_name
  <before|after> <insert|update|delete> on <schema_name>.<table_name>
  for each row [when (<condition>)]
  execute procedure <schema_name.function_name>(...);
```

Comments:

```sql
comment on <table|column|function|...> <fully.qualified.name> is
  E'...';
```
