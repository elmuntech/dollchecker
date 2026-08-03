-- DollChecker — AI chat about a scanned toy.
--
-- The scan answers "is this toy any good?". Everything a parent asks next —
-- "my two-year-old ignores it, what now?", "is the noise a problem?" — has no
-- home. This table is that conversation, one thread per scan.
--
-- Chat is a premium feature. Unlike a scan, a conversation has no natural end,
-- so a free tier would be an unbounded model bill per user; the function
-- enforces the tier and this schema stays simple as a result.

create table public.chat_messages (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- The thread. Deleting the scan takes its conversation with it: the messages
  -- only make sense next to the analysis they discuss.
  scan_id     uuid not null references public.scans (id) on delete cascade,
  role        text not null check (role in ('user', 'assistant')),
  content     text not null check (length(content) between 1 and 8000),
  created_at  timestamptz not null default now()
);

create index chat_messages_thread_idx
  on public.chat_messages (scan_id, created_at);
create index chat_messages_user_idx
  on public.chat_messages (user_id, created_at desc);

alter table public.chat_messages enable row level security;

-- Readable and deletable by the owner; writing is the function's job (with the
-- service-role key). A client that could insert an `assistant` row could put
-- words in the assistant's mouth and have them read back as context later.
create policy "chat_messages_select_own" on public.chat_messages
  for select using (auth.uid() = user_id);
create policy "chat_messages_delete_own" on public.chat_messages
  for delete using (auth.uid() = user_id);
