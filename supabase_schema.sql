-- =============================================================================
-- OmniCore — Supabase SQL Schema
-- =============================================================================
-- Run this in your Supabase project's SQL Editor (Dashboard → SQL Editor → New
-- query → paste → Run). It creates all tables needed for optional cloud sync,
-- with Row Level Security so each user can only see their own data.
--
-- Auth is STRICTLY OPTIONAL. The app works 100% offline without this. These
-- tables are only used when a user signs in with Google and the app syncs
-- preferences / file metadata / mail configs across devices.
-- =============================================================================

-- Extensions ------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- =============================================================================
-- 1. user_preferences — synced app settings (theme mode, AI key override, etc.)
-- =============================================================================
create table if not exists public.user_preferences (
  user_id   uuid not null references auth.users(id) on delete cascade,
  key       text not null,
  value     text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

comment on table public.user_preferences is
  'Synced OmniCore preferences (theme, AI key override, nav state, etc.).';

-- =============================================================================
-- 2. file_nodes — synced file metadata (NOT the file bytes — just the index)
-- =============================================================================
create table if not exists public.file_nodes (
  id          text not null,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  path        text not null,
  kind        text not null default 'other',
  size_bytes  integer not null default 0,
  parent_id   text,
  modified_at bigint not null default 0,
  is_favorite boolean not null default false,
  tags        text not null default '',
  indexed_at  bigint not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists idx_file_nodes_parent on public.file_nodes(user_id, parent_id);
create index if not exists idx_file_nodes_kind   on public.file_nodes(user_id, kind);

comment on table public.file_nodes is
  'Synced file index metadata (paths + tags only, no file bytes).';

-- =============================================================================
-- 3. gallery_items — synced photo metadata + AI tags
-- =============================================================================
create table if not exists public.gallery_items (
  id          text not null,
  user_id     uuid not null references auth.users(id) on delete cascade,
  path        text not null,
  captured_at bigint not null default 0,
  width       integer not null default 0,
  height      integer not null default 0,
  tags        text not null default '',
  ai_state    text not null default 'pending',
  rotation    double precision not null default 0.0,
  pinned      boolean not null default true,
  updated_at  timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists idx_gallery_captured on public.gallery_items(user_id, captured_at);

comment on table public.gallery_items is
  'Synced gallery photo metadata + on-device AI tags.';

-- =============================================================================
-- 4. mail_messages — synced mail store (subjects, scores, outbox queue)
-- =============================================================================
create table if not exists public.mail_messages (
  id             text not null,
  user_id        uuid not null references auth.users(id) on delete cascade,
  from_addr      text not null,
  from_name      text not null,
  subject        text not null,
  preview        text not null default '',
  body           text not null default '',
  received_at    bigint not null default 0,
  status         text not null default 'inbox',
  mail_rate      integer not null default 0,
  is_starred     boolean not null default false,
  has_attachment boolean not null default false,
  attachments    text not null default '',
  updated_at     timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists idx_mail_status   on public.mail_messages(user_id, status);
create index if not exists idx_mail_received on public.mail_messages(user_id, received_at);

comment on table public.mail_messages is
  'Synced mail messages + AI Mail Rate scores + outbox queue.';

-- =============================================================================
-- 5. mail_accounts — synced SMTP/IMAP account configs (passwords should be
--    encrypted client-side before storing; the password_enc column is opaque
--    to Supabase)
-- =============================================================================
create table if not exists public.mail_accounts (
  id           text not null,
  user_id      uuid not null references auth.users(id) on delete cascade,
  email        text not null,
  display_name text not null,
  imap_host    text not null,
  imap_port    integer not null default 993,
  smtp_host    text not null,
  smtp_port    integer not null default 587,
  username     text not null,
  password_enc text not null,
  use_tls      boolean not null default true,
  updated_at   timestamptz not null default now(),
  primary key (user_id, id)
);

comment on table public.mail_accounts is
  'Synced mail account configs. password_enc is client-side encrypted.';

-- =============================================================================
-- 6. beam_transfers — OmniBeam transfer history (synced for cross-device log)
-- =============================================================================
create table if not exists public.beam_transfers (
  id          text not null,
  user_id     uuid not null references auth.users(id) on delete cascade,
  device_id   text not null,
  device_name text not null,
  file_name   text not null,
  size_bytes  integer not null default 0,
  sent_bytes  integer not null default 0,
  started_at  bigint not null default 0,
  status      text not null default 'queued',
  transport   text not null default 'webrtc',
  updated_at  timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists idx_beam_started on public.beam_transfers(user_id, started_at);

comment on table public.beam_transfers is
  'Synced OmniBeam transfer history log.';

-- =============================================================================
-- 7. updated_at trigger — keep the updated_at column fresh on every update
-- =============================================================================
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'user_preferences', 'file_nodes', 'gallery_items',
    'mail_messages', 'mail_accounts', 'beam_transfers'
  ]
  loop
    execute format(
      'drop trigger if exists set_updated_at on public.%I;
       create trigger set_updated_at before update on public.%I
       for each row execute function public.handle_updated_at();',
      t, t
    );
  end loop;
end;
$$;

-- =============================================================================
-- 8. Row Level Security — each user can only access their own rows
-- =============================================================================

-- Enable RLS on all tables.
alter table public.user_preferences enable row level security;
alter table public.file_nodes      enable row level security;
alter table public.gallery_items   enable row level security;
alter table public.mail_messages   enable row level security;
alter table public.mail_accounts   enable row level security;
alter table public.beam_transfers  enable row level security;

-- Helper: policies are the same shape for every table — a user can do
-- everything (select/insert/update/delete) on rows where user_id = auth.uid().

-- user_preferences
drop policy if exists "user_preferences_select_own" on public.user_preferences;
drop policy if exists "user_preferences_insert_own" on public.user_preferences;
drop policy if exists "user_preferences_update_own" on public.user_preferences;
drop policy if exists "user_preferences_delete_own" on public.user_preferences;

create policy "user_preferences_select_own" on public.user_preferences
  for select using (auth.uid() = user_id);
create policy "user_preferences_insert_own" on public.user_preferences
  for insert with check (auth.uid() = user_id);
create policy "user_preferences_update_own" on public.user_preferences
  for update using (auth.uid() = user_id);
create policy "user_preferences_delete_own" on public.user_preferences
  for delete using (auth.uid() = user_id);

-- file_nodes
drop policy if exists "file_nodes_select_own" on public.file_nodes;
drop policy if exists "file_nodes_insert_own" on public.file_nodes;
drop policy if exists "file_nodes_update_own" on public.file_nodes;
drop policy if exists "file_nodes_delete_own" on public.file_nodes;

create policy "file_nodes_select_own" on public.file_nodes
  for select using (auth.uid() = user_id);
create policy "file_nodes_insert_own" on public.file_nodes
  for insert with check (auth.uid() = user_id);
create policy "file_nodes_update_own" on public.file_nodes
  for update using (auth.uid() = user_id);
create policy "file_nodes_delete_own" on public.file_nodes
  for delete using (auth.uid() = user_id);

-- gallery_items
drop policy if exists "gallery_items_select_own" on public.gallery_items;
drop policy if exists "gallery_items_insert_own" on public.gallery_items;
drop policy if exists "gallery_items_update_own" on public.gallery_items;
drop policy if exists "gallery_items_delete_own" on public.gallery_items;

create policy "gallery_items_select_own" on public.gallery_items
  for select using (auth.uid() = user_id);
create policy "gallery_items_insert_own" on public.gallery_items
  for insert with check (auth.uid() = user_id);
create policy "gallery_items_update_own" on public.gallery_items
  for update using (auth.uid() = user_id);
create policy "gallery_items_delete_own" on public.gallery_items
  for delete using (auth.uid() = user_id);

-- mail_messages
drop policy if exists "mail_messages_select_own" on public.mail_messages;
drop policy if exists "mail_messages_insert_own" on public.mail_messages;
drop policy if exists "mail_messages_update_own" on public.mail_messages;
drop policy if exists "mail_messages_delete_own" on public.mail_messages;

create policy "mail_messages_select_own" on public.mail_messages
  for select using (auth.uid() = user_id);
create policy "mail_messages_insert_own" on public.mail_messages
  for insert with check (auth.uid() = user_id);
create policy "mail_messages_update_own" on public.mail_messages
  for update using (auth.uid() = user_id);
create policy "mail_messages_delete_own" on public.mail_messages
  for delete using (auth.uid() = user_id);

-- mail_accounts
drop policy if exists "mail_accounts_select_own" on public.mail_accounts;
drop policy if exists "mail_accounts_insert_own" on public.mail_accounts;
drop policy if exists "mail_accounts_update_own" on public.mail_accounts;
drop policy if exists "mail_accounts_delete_own" on public.mail_accounts;

create policy "mail_accounts_select_own" on public.mail_accounts
  for select using (auth.uid() = user_id);
create policy "mail_accounts_insert_own" on public.mail_accounts
  for insert with check (auth.uid() = user_id);
create policy "mail_accounts_update_own" on public.mail_accounts
  for update using (auth.uid() = user_id);
create policy "mail_accounts_delete_own" on public.mail_accounts
  for delete using (auth.uid() = user_id);

-- beam_transfers
drop policy if exists "beam_transfers_select_own" on public.beam_transfers;
drop policy if exists "beam_transfers_insert_own" on public.beam_transfers;
drop policy if exists "beam_transfers_update_own" on public.beam_transfers;
drop policy if exists "beam_transfers_delete_own" on public.beam_transfers;

create policy "beam_transfers_select_own" on public.beam_transfers
  for select using (auth.uid() = user_id);
create policy "beam_transfers_insert_own" on public.beam_transfers
  for insert with check (auth.uid() = user_id);
create policy "beam_transfers_update_own" on public.beam_transfers
  for update using (auth.uid() = user_id);
create policy "beam_transfers_delete_own" on public.beam_transfers
  for delete using (auth.uid() = user_id);

-- =============================================================================
-- DONE.
--
-- After running this:
--   1. Go to Supabase Dashboard → Authentication → Providers → Google.
--      Enable Google OAuth and add your Android SHA-1 fingerprint + package
--      name (com.omnicore).
--   2. Build the app with:
--        flutter build apk --release \
--          --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
--          --dart-define=SUPABASE_ANON_KEY=ey...
--   3. Tap the profile circle (top-right) → "Login with Google (Optional)".
--
-- If you skip step 2, the app runs 100% offline with no login prompt.
-- =============================================================================
