-- push_quota: backs push-relay's daily-send quota gate (src/index.js's
-- checkAndIncrementQuota, called for every FCM send once a user_id is
-- present). One row per user, reset implicitly by comparing `day` to
-- current_date rather than a separate cron/cleanup job.
--
-- Apply once via the Supabase SQL editor, or:
--   psql "$SUPABASE_DB_URL" -f scripts/supabase-schema.sql

create table if not exists push_quota (
  user_id text primary key,
  day date not null default current_date,
  count integer not null default 0
);

-- Supabase enables RLS on new tables by default with no policies, which
-- denies even service_role without an explicit grant (service_role does
-- NOT implicitly bypass table-level GRANTs, only RLS policies).
-- checkAndIncrementQuota authenticates as service_role, so it needs this.
grant select, insert, update on public.push_quota to service_role;

-- Atomic increment-and-read: a single upsert statement, so concurrent
-- sends for the same user_id can't race past the limit. Returns the
-- post-increment count for *today* -- checkAndIncrementQuota compares
-- this directly against DAILY_PUSH_LIMIT.
create or replace function increment_push(p_user_id text)
returns integer
language plpgsql
as $$
declare
  new_count integer;
begin
  insert into push_quota (user_id, day, count)
  values (p_user_id, current_date, 1)
  on conflict (user_id) do update
    set count = case
        when push_quota.day = current_date then push_quota.count + 1
        else 1
      end,
      day = current_date
  returning count into new_count;

  return new_count;
end;
$$;

grant execute on function public.increment_push(text) to service_role;

create table if not exists relay_bindings (
  secret_hash text primary key,
  user_id text not null,
  bound_at timestamptz not null default now()
);

grant select, insert on public.relay_bindings to service_role;

create or replace function bind_relay_secret(p_secret_hash text, p_user_id text)
returns text
language plpgsql
as $$
declare
  bound_user_id text;
begin
  insert into public.relay_bindings (secret_hash, user_id)
  values (p_secret_hash, p_user_id)
  on conflict (secret_hash) do nothing;

  select user_id into bound_user_id
  from public.relay_bindings
  where secret_hash = p_secret_hash;

  return bound_user_id;
end;
$$;

grant execute on function public.bind_relay_secret(text, text) to service_role;
