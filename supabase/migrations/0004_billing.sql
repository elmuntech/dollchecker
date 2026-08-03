-- DollChecker — subscriptions (Polar.sh).
--
-- Two things happen here:
--   1. `profiles` gains the billing state a subscription needs to be reconciled
--      against the provider — customer id, subscription id, status, period end.
--   2. `profiles.tier` stops being writable by its owner.
--
-- (2) is the important one. Migration 0001 granted a blanket
-- `profiles_update_own` policy, which was harmless while `tier` meant nothing.
-- The moment a tier unlocks paid features, that policy is a free upgrade for
-- anyone who can send a PATCH. Postgres column-level grants fix it properly:
-- the policy still allows the row, but the columns a user may write are now
-- exactly the ones that are theirs to choose. Billing columns are written only
-- by the webhook, which uses the service-role key and bypasses all of this.

alter table public.profiles
  add column if not exists polar_customer_id     text,
  add column if not exists polar_subscription_id text,
  -- Provider status verbatim ('active', 'canceled', 'past_due', …) so support
  -- can compare against the Polar dashboard without a translation table.
  add column if not exists subscription_status   text,
  add column if not exists current_period_end    timestamptz,
  add column if not exists billing_updated_at    timestamptz;

create index if not exists profiles_polar_customer_idx
  on public.profiles (polar_customer_id)
  where polar_customer_id is not null;

-- ---------------------------------------------------------------------------
-- Lock down the writable surface of `profiles`
-- ---------------------------------------------------------------------------
revoke update on public.profiles from authenticated;
grant update (display_name, locale) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- billing_events — webhook idempotency + an audit trail
--
-- Polar retries a webhook until it gets a 2xx, so the same event id can arrive
-- several times; the primary key is what makes a replay a no-op. No RLS policy
-- is defined on purpose: nothing but the service role should ever read this.
-- ---------------------------------------------------------------------------
create table if not exists public.billing_events (
  id            text primary key,
  type          text not null,
  user_id       uuid references auth.users (id) on delete set null,
  payload       jsonb,
  received_at   timestamptz not null default now()
);

alter table public.billing_events enable row level security;

create index if not exists billing_events_user_idx
  on public.billing_events (user_id, received_at desc);

-- ---------------------------------------------------------------------------
-- apply_subscription_state
--
-- Single writer for the billing columns, called by the polar-webhook function
-- with the service-role key. Keeping it in SQL means the "what does this status
-- mean for the tier" rule lives next to the data, and an out-of-order webhook
-- (Polar makes no ordering guarantee) cannot move a subscription backwards:
-- an event older than the one already recorded is ignored.
-- ---------------------------------------------------------------------------
create or replace function public.apply_subscription_state(
  p_user_id           uuid,
  p_customer_id       text,
  p_subscription_id   text,
  p_status            text,
  p_current_period_end timestamptz,
  p_event_at          timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set tier = case
                  when p_status in ('active', 'trialing') then 'premium'::subscription_tier
                  else 'free'::subscription_tier
                end,
         polar_customer_id     = coalesce(p_customer_id, polar_customer_id),
         polar_subscription_id = coalesce(p_subscription_id, polar_subscription_id),
         subscription_status   = p_status,
         current_period_end    = p_current_period_end,
         billing_updated_at    = p_event_at
   where id = p_user_id
     and (billing_updated_at is null or billing_updated_at <= p_event_at);
end;
$$;

revoke execute on function public.apply_subscription_state(
  uuid, text, text, text, timestamptz, timestamptz) from public, anon, authenticated;
