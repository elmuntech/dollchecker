-- DollChecker V1 — toy collection, development dashboard, play coach.
--
-- Adds:
--   * a stable per-user toy identity (name + brand) so repeat scans of the same
--     toy collapse into one collection entry;
--   * denormalized "latest scan" columns on `toys` so the collection grid renders
--     from a single cheap select;
--   * `upsert_toy_from_scan` — called by the analyze-toy Edge Function with the
--     service-role key, which both resolves the toy and links the scan to it;
--   * `child_skill_summary` — aggregation powering the development dashboard.

-- ---------------------------------------------------------------------------
-- toys: identity + denormalized latest-scan snapshot
-- ---------------------------------------------------------------------------
alter table public.toys
  add column if not exists name_key text
    generated always as (lower(btrim(coalesce(name, '')))) stored,
  add column if not exists brand_key text
    generated always as (lower(btrim(coalesce(brand, '')))) stored,
  add column if not exists notes text,
  add column if not exists scan_count int not null default 0,
  add column if not exists last_scanned_at timestamptz,
  add column if not exists last_scan_id uuid references public.scans (id) on delete set null,
  add column if not exists latest_safety safety_level,
  add column if not exists latest_educational_score int
    check (latest_educational_score between 0 and 100),
  add column if not exists updated_at timestamptz not null default now();

-- One collection entry per (user, toy name, brand). Unnamed toys (the model could
-- not identify the item) are excluded so they never collapse into a single row.
create unique index if not exists toys_identity_idx
  on public.toys (user_id, name_key, brand_key)
  where name_key <> '';

create index if not exists toys_user_owned_idx on public.toys (user_id, owned);
create index if not exists toys_last_scanned_idx
  on public.toys (user_id, last_scanned_at desc nulls last);
create index if not exists scans_toy_idx on public.scans (toy_id);
-- ---------------------------------------------------------------------------
-- play_ideas: the Play Coach feed orders by recency, which needs a timestamp.
-- ---------------------------------------------------------------------------
alter table public.play_ideas
  add column if not exists created_at timestamptz not null default now();

create index if not exists play_ideas_user_fav_idx
  on public.play_ideas (user_id, is_favorited);
create index if not exists play_ideas_user_created_idx
  on public.play_ideas (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- upsert_toy_from_scan
--
-- Resolves (or creates) the collection entry for a freshly analyzed toy, links
-- the scan to it, and refreshes the denormalized snapshot. Returns the toy id,
-- or null when the toy could not be named.
--
-- SECURITY INVOKER: the Edge Function calls this with the service-role key,
-- which bypasses RLS. Execute is revoked from client roles below so a signed-in
-- user can never pass someone else's p_user_id.
-- ---------------------------------------------------------------------------
create or replace function public.upsert_toy_from_scan(
  p_user_id           uuid,
  p_scan_id           uuid,
  p_name              text,
  p_brand             text,
  p_category          text,
  p_image_url         text,
  p_safety            safety_level,
  p_educational_score int
)
returns uuid
language plpgsql
set search_path = public
as $$
declare
  v_toy_id uuid;
begin
  if coalesce(btrim(p_name), '') = '' then
    return null;
  end if;

  insert into public.toys as t (
    user_id, name, brand, category, primary_image_url,
    scan_count, last_scanned_at, last_scan_id,
    latest_safety, latest_educational_score, updated_at
  )
  values (
    p_user_id,
    btrim(p_name),
    nullif(btrim(coalesce(p_brand, '')), ''),
    nullif(btrim(coalesce(p_category, '')), ''),
    p_image_url,
    1, now(), p_scan_id,
    p_safety, p_educational_score, now()
  )
  on conflict (user_id, name_key, brand_key) where name_key <> ''
  do update set
    -- Keep the first non-null value for descriptive fields; always refresh the
    -- "latest scan" snapshot.
    category                 = coalesce(t.category, excluded.category),
    primary_image_url        = coalesce(t.primary_image_url, excluded.primary_image_url),
    scan_count               = t.scan_count + 1,
    last_scanned_at          = now(),
    last_scan_id             = p_scan_id,
    latest_safety            = excluded.latest_safety,
    latest_educational_score = excluded.latest_educational_score,
    updated_at               = now()
  returning t.id into v_toy_id;

  update public.scans
     set toy_id = v_toy_id
   where id = p_scan_id
     and user_id = p_user_id;

  return v_toy_id;
end;
$$;

revoke execute on function public.upsert_toy_from_scan(
  uuid, uuid, text, text, text, text, safety_level, int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- child_skill_summary
--
-- Average / best score per development skill across a child's scans (or across
-- every scan when p_child_id is null). SECURITY INVOKER + an explicit
-- auth.uid() filter, so a user only ever aggregates their own rows.
-- ---------------------------------------------------------------------------
create or replace function public.child_skill_summary(p_child_id uuid default null)
returns table (
  skill      skill_key,
  avg_score  numeric,
  max_score  int,
  scan_count bigint
)
language sql
stable
set search_path = public
as $$
  select
    ds.skill,
    round(avg(ds.score)::numeric, 1) as avg_score,
    max(ds.score)                    as max_score,
    count(distinct ds.scan_id)       as scan_count
  from public.development_scores ds
  join public.scans s on s.id = ds.scan_id
  where ds.user_id = auth.uid()
    and (p_child_id is null or s.child_profile_id = p_child_id)
  group by ds.skill;
$$;

grant execute on function public.child_skill_summary(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Backfill: link existing scans to collection entries.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select id, user_id,
           identification ->> 'name'     as name,
           identification ->> 'brand'    as brand,
           identification ->> 'category' as category,
           image_url, safety_overall, educational_score
      from public.scans
     where toy_id is null
     order by created_at
  loop
    perform public.upsert_toy_from_scan(
      r.user_id, r.id, r.name, r.brand, r.category,
      r.image_url, r.safety_overall, r.educational_score);
  end loop;
end;
$$;
