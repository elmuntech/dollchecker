-- DollChecker — initial schema, RLS, and storage.
-- All user data is isolated per-user via Row-Level Security keyed on auth.uid().

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type safety_level as enum ('green', 'yellow', 'red');
create type subscription_tier as enum ('free', 'premium');

-- Canonical development-skill keys. Kept in English machine values so scores are
-- stable for storage/aggregation; the Flutter app maps them to localized labels.
create type skill_key as enum (
  'fine_motor', 'gross_motor', 'creativity', 'problem_solving', 'language',
  'numeracy', 'logic', 'stem', 'social_emotional', 'imagination', 'memory',
  'spatial_reasoning', 'hand_eye_coordination', 'focus_attention',
  'reading_readiness', 'independent_play', 'collaboration', 'sensory',
  'confidence', 'curiosity'
);

-- ---------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  display_name       text,
  locale             text not null default 'en' check (locale in ('en', 'ru')),
  tier               subscription_tier not null default 'free',
  scan_quota_used    int  not null default 0,
  quota_reset_at     timestamptz not null default (date_trunc('month', now()) + interval '1 month'),
  created_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- child_profiles
-- ---------------------------------------------------------------------------
create table public.child_profiles (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  name         text not null,
  birth_date   date,
  gender       text,           -- optional; free text ('boy'|'girl'|other|null)
  avatar_url   text,
  notes        text,
  created_at   timestamptz not null default now()
);
create index child_profiles_user_id_idx on public.child_profiles (user_id);

-- ---------------------------------------------------------------------------
-- toys (inventory / canonical item)
-- ---------------------------------------------------------------------------
create table public.toys (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  name               text,
  brand              text,
  category           text,
  primary_image_url  text,
  owned              boolean not null default true,
  acquired_at        date,
  created_at         timestamptz not null default now()
);
create index toys_user_id_idx on public.toys (user_id);

-- ---------------------------------------------------------------------------
-- scans (one analysis event)
-- ---------------------------------------------------------------------------
create table public.scans (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  child_profile_id   uuid references public.child_profiles (id) on delete set null,
  toy_id             uuid references public.toys (id) on delete set null,
  image_url          text,
  identification     jsonb,           -- { name, brand, category, confidence, detected_language }
  age_min_months     int,
  age_max_months     int,
  age_label          text,
  materials          text[] not null default '{}',
  safety_overall     safety_level,
  safety_score       int check (safety_score between 0 and 100),
  safety             jsonb,           -- { hazards[], summary, disclaimer, supervision_level, ... }
  educational_score  int check (educational_score between 0 and 100),
  raw_response       jsonb,           -- full model output for audit/support
  model_used         text,
  locale             text not null default 'en',
  created_at         timestamptz not null default now()
);
create index scans_user_id_created_idx on public.scans (user_id, created_at desc);
create index scans_child_idx on public.scans (child_profile_id);

-- ---------------------------------------------------------------------------
-- development_scores (normalized, one row per skill per scan)
-- ---------------------------------------------------------------------------
create table public.development_scores (
  id               uuid primary key default gen_random_uuid(),
  scan_id          uuid not null references public.scans (id) on delete cascade,
  user_id          uuid not null references auth.users (id) on delete cascade,
  skill            skill_key not null,
  score            int not null check (score between 0 and 100),
  reason           text,
  how_to_maximize  text
);
create index dev_scores_scan_idx on public.development_scores (scan_id);
create index dev_scores_user_skill_idx on public.development_scores (user_id, skill);

-- ---------------------------------------------------------------------------
-- play_ideas
-- ---------------------------------------------------------------------------
create table public.play_ideas (
  id                uuid primary key default gen_random_uuid(),
  scan_id           uuid not null references public.scans (id) on delete cascade,
  user_id           uuid not null references auth.users (id) on delete cascade,
  title             text not null,
  description       text,
  skills_targeted   text[] not null default '{}',
  min_age_months    int,
  duration_minutes  int,
  difficulty        text check (difficulty in ('easy', 'medium', 'hard')),
  is_favorited      boolean not null default false
);
create index play_ideas_scan_idx on public.play_ideas (scan_id);

-- ---------------------------------------------------------------------------
-- Auto-provision a profile row when a new auth user is created
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles           enable row level security;
alter table public.child_profiles     enable row level security;
alter table public.toys               enable row level security;
alter table public.scans              enable row level security;
alter table public.development_scores enable row level security;
alter table public.play_ideas         enable row level security;

-- profiles: a user can read/update only their own row
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Generic owner policies for the user-owned tables.
create policy "child_profiles_all_own" on public.child_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "toys_all_own" on public.toys
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "scans_all_own" on public.scans
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "dev_scores_all_own" on public.development_scores
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "play_ideas_all_own" on public.play_ideas
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Note: the analyze-toy Edge Function writes with the service-role key, which
-- bypasses RLS. These policies protect direct client access from the Flutter app.

-- ---------------------------------------------------------------------------
-- Storage: private bucket for toy images, RLS by owning user (path = {user_id}/...)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('toy-images', 'toy-images', false)
on conflict (id) do nothing;

create policy "toy_images_read_own" on storage.objects
  for select using (
    bucket_id = 'toy-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "toy_images_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'toy-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "toy_images_delete_own" on storage.objects
  for delete using (
    bucket_id = 'toy-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
