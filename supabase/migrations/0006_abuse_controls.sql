-- DollChecker — abuse and cost controls.
--
-- The threat this project actually faces is not a volumetric flood — the
-- platform absorbs that — but somebody spending our model budget. Three holes
-- are closed here.
--
-- 1. The scan quota was read at the start of a request and written at the end,
--    as an absolute value. Fifty concurrent requests all read `used = 0`, all
--    passed the check, and all wrote `1`: a ten-scan cap that a burst walked
--    straight through, and a lost update besides. `consume_scan_quota` takes
--    the allowance *before* the model call, under a row lock.
--
-- 2. Nothing anywhere was rate limited. `hit_rate_limit` gives every function a
--    fixed-window counter it can call per user and per IP.
--
-- 3. Nothing recorded what the model cost. `ai_usage` does, which is what makes
--    an attack visible before the invoice does.
--
-- None of these are reachable from a client: every function here is revoked
-- from `authenticated` and called with the service-role key.

-- ---------------------------------------------------------------------------
-- 1. Atomic scan quota
-- ---------------------------------------------------------------------------

/* Takes one scan from the caller's monthly allowance.
 *
 * `for update` is the whole point: it serializes concurrent calls on one
 * profile, so a burst queues instead of racing. Premium is unlimited but still
 * counted — usage is worth knowing even when it is not billed.
 *
 * Returns `allowed = false` rather than raising: an exhausted quota is an
 * ordinary answer, not an error.
 */
create or replace function public.consume_scan_quota(
  p_user_id uuid,
  p_limit    int
)
returns table (allowed boolean, used int, remaining int, tier text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier  subscription_tier;
  v_used  int;
  v_reset timestamptz;
begin
  select p.tier, p.scan_quota_used, p.quota_reset_at
    into v_tier, v_used, v_reset
    from public.profiles p
   where p.id = p_user_id
     for update;

  if not found then
    -- No profile means no account to charge; the caller treats this as denied.
    return query select false, 0, 0, 'free'::text;
    return;
  end if;

  -- The monthly rollover happens here rather than in a scheduled job: the only
  -- moment it matters is when someone tries to scan.
  if v_reset is null or now() >= v_reset then
    v_used  := 0;
    v_reset := date_trunc('month', now()) + interval '1 month';
  end if;

  if v_tier <> 'free' then
    update public.profiles
       set scan_quota_used = v_used + 1,
           quota_reset_at  = v_reset
     where id = p_user_id;
    return query select true, v_used + 1, null::int, v_tier::text;
    return;
  end if;

  if v_used >= p_limit then
    -- Still write back, so a rollover that just happened is not recomputed on
    -- every subsequent attempt.
    update public.profiles
       set scan_quota_used = v_used,
           quota_reset_at  = v_reset
     where id = p_user_id;
    return query select false, v_used, 0, v_tier::text;
    return;
  end if;

  update public.profiles
     set scan_quota_used = v_used + 1,
         quota_reset_at  = v_reset
   where id = p_user_id;
  return query select true, v_used + 1, p_limit - (v_used + 1), v_tier::text;
end;
$$;

/* Gives the allowance back when the work it was taken for did not happen.
 *
 * The alternative — charge only on success — is what created the race in the
 * first place. Reserve, then refund on failure: a lost refund costs the user
 * one scan, while a lost reservation costs us an unbounded number of them.
 */
create or replace function public.refund_scan_quota(p_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
     set scan_quota_used = greatest(0, scan_quota_used - 1)
   where id = p_user_id;
$$;

revoke execute on function public.consume_scan_quota(uuid, int)
  from public, anon, authenticated;
revoke execute on function public.refund_scan_quota(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Rate limiting
-- ---------------------------------------------------------------------------

/* One row per (bucket, window). A fixed window rather than a sliding one:
 * predictable, one statement, and the burst it permits at a boundary is
 * bounded by the limit itself — which is the right trade for a counter that
 * every request pays for.
 */
create table if not exists public.rate_limits (
  bucket       text        not null,
  window_start timestamptz not null,
  count        int         not null default 0,
  primary key (bucket, window_start)
);

create index if not exists rate_limits_window_idx
  on public.rate_limits (window_start);

alter table public.rate_limits enable row level security;
-- No policies on purpose: nothing but the service role touches this.

/* Counts one hit against `p_bucket` and says whether it is allowed.
 *
 * Old windows are swept opportunistically — only when a brand new window row
 * is created, so the cost lands on one request in a window rather than on all
 * of them, and no scheduled job has to exist.
 */
create or replace function public.hit_rate_limit(
  p_bucket         text,
  p_limit          int,
  p_window_seconds int
)
returns table (allowed boolean, hits int, retry_after int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_epoch  bigint := floor(extract(epoch from now()));
  v_start  timestamptz := to_timestamp(v_epoch - (v_epoch % p_window_seconds));
  v_count  int;
begin
  insert into public.rate_limits as r (bucket, window_start, count)
  values (p_bucket, v_start, 1)
  on conflict (bucket, window_start)
    do update set count = r.count + 1
  returning r.count into v_count;

  if v_count = 1 then
    delete from public.rate_limits
     where window_start < now() - interval '1 day';
  end if;

  return query select
    v_count <= p_limit,
    v_count,
    greatest(1, ceil(extract(epoch from (
      v_start + make_interval(secs => p_window_seconds) - now()
    )))::int);
end;
$$;

revoke execute on function public.hit_rate_limit(text, int, int)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Model usage
-- ---------------------------------------------------------------------------

/* What each model call cost, so abuse is visible before the invoice is.
 * Deliberately not linked to the scan or the message: it survives their
 * deletion, because the spend happened either way.
 */
create table if not exists public.ai_usage (
  id            bigserial primary key,
  user_id       uuid references auth.users (id) on delete set null,
  function_name text not null,
  model         text,
  input_tokens  int  not null default 0,
  output_tokens int  not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists ai_usage_created_idx
  on public.ai_usage (created_at desc);
create index if not exists ai_usage_user_idx
  on public.ai_usage (user_id, created_at desc);

alter table public.ai_usage enable row level security;
-- No policies: service role only. Users have no business reading this, and it
-- would leak nothing useful to them anyway.

/* Spend per user over a window — the query an alert would run.
 * Kept as a view so "who is burning the budget" is one select, not a script
 * someone has to rewrite at the moment they need it most.
 */
create or replace view public.ai_usage_last_day as
  select
    user_id,
    function_name,
    count(*)             as calls,
    sum(input_tokens)    as input_tokens,
    sum(output_tokens)   as output_tokens,
    max(created_at)      as last_call
  from public.ai_usage
  where created_at > now() - interval '1 day'
  group by user_id, function_name
  order by sum(input_tokens) + sum(output_tokens) desc;

revoke all on public.ai_usage_last_day from public, anon, authenticated;
