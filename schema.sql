-- DECKS
create table if not exists public.decks (
  id text primary key,
  name text not null,
  color text not null,
  icon text not null,
  cover_image_url text,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.decks enable row level security;

drop policy if exists "decks_select_own" on public.decks;
create policy "decks_select_own" on public.decks for select using (auth.uid() = user_id);

drop policy if exists "decks_insert_own" on public.decks;
create policy "decks_insert_own" on public.decks for insert with check (auth.uid() = user_id);

drop policy if exists "decks_update_own" on public.decks;
create policy "decks_update_own" on public.decks for update using (auth.uid() = user_id);

drop policy if exists "decks_delete_own" on public.decks;
create policy "decks_delete_own" on public.decks for delete using (auth.uid() = user_id);


-- WORDS
create table if not exists public.words (
  id text primary key,
  word_text text not null,
  image_url text,
  confidence double precision not null default 0,
  source_scan_id text,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.words enable row level security;

drop policy if exists "words_select_own" on public.words;
create policy "words_select_own" on public.words for select using (auth.uid() = user_id);

drop policy if exists "words_insert_own" on public.words;
create policy "words_insert_own" on public.words for insert with check (auth.uid() = user_id);

drop policy if exists "words_update_own" on public.words;
create policy "words_update_own" on public.words for update using (auth.uid() = user_id);

drop policy if exists "words_delete_own" on public.words;
create policy "words_delete_own" on public.words for delete using (auth.uid() = user_id);


-- WORD DETAILS
create table if not exists public.word_details (
  word_id text primary key references public.words(id) on delete cascade,
  definition text not null,
  example text not null,
  part_of_speech text not null,
  phonetic text not null,
  audio_url text not null,
  raw_json jsonb
);

alter table public.word_details enable row level security;

drop policy if exists "word_details_select_own" on public.word_details;
create policy "word_details_select_own" on public.word_details for select using (
  exists (
    select 1 from public.words
    where words.id = word_details.word_id
    and words.user_id = auth.uid()
  )
);

drop policy if exists "word_details_insert_own" on public.word_details;
create policy "word_details_insert_own" on public.word_details for insert with check (
  exists (
    select 1 from public.words
    where words.id = word_details.word_id
    and words.user_id = auth.uid()
  )
);

drop policy if exists "word_details_update_own" on public.word_details;
create policy "word_details_update_own" on public.word_details for update using (
  exists (
    select 1 from public.words
    where words.id = word_details.word_id
    and words.user_id = auth.uid()
  )
);

drop policy if exists "word_details_delete_own" on public.word_details;
create policy "word_details_delete_own" on public.word_details for delete using (
  exists (
    select 1 from public.words
    where words.id = word_details.word_id
    and words.user_id = auth.uid()
  )
);


-- DECK WORDS
create table if not exists public.deck_words (
  deck_id text not null references public.decks(id) on delete cascade,
  word_id text not null references public.words(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (deck_id, word_id)
);

alter table public.deck_words enable row level security;

drop policy if exists "deck_words_select_own" on public.deck_words;
create policy "deck_words_select_own" on public.deck_words for select using (
  exists (
    select 1 from public.decks
    where decks.id = deck_words.deck_id
    and decks.user_id = auth.uid()
  )
);

drop policy if exists "deck_words_insert_own" on public.deck_words;
create policy "deck_words_insert_own" on public.deck_words for insert with check (
  exists (
    select 1 from public.decks
    where decks.id = deck_words.deck_id
    and decks.user_id = auth.uid()
  )
);

drop policy if exists "deck_words_delete_own" on public.deck_words;
create policy "deck_words_delete_own" on public.deck_words for delete using (
  exists (
    select 1 from public.decks
    where decks.id = deck_words.deck_id
    and decks.user_id = auth.uid()
  )
);


-- FLASHCARDS
create table if not exists public.flashcards (
  id text primary key default gen_random_uuid()::text,
  deck_id text not null references public.decks(id) on delete cascade,
  word_id text references public.words(id) on delete cascade,
  front_text text,
  back_text text,
  media_url text,
  media_type text,
  position integer default 0,
  is_deleted boolean default false,
  revision bigint default 0,
  modified_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (deck_id, word_id)
);

alter table public.flashcards enable row level security;

drop policy if exists "flashcards_select_own" on public.flashcards;
create policy "flashcards_select_own" on public.flashcards for select using (
  exists (
    select 1 from public.decks
    where decks.id = flashcards.deck_id
    and decks.user_id = auth.uid()
  )
);

drop policy if exists "flashcards_insert_own" on public.flashcards;
create policy "flashcards_insert_own" on public.flashcards for insert with check (
  exists (
    select 1 from public.decks
    where decks.id = flashcards.deck_id
    and decks.user_id = auth.uid()
  )
);

drop policy if exists "flashcards_update_own" on public.flashcards;
create policy "flashcards_update_own" on public.flashcards for update using (
  exists (
    select 1 from public.decks
    where decks.id = flashcards.deck_id
    and decks.user_id = auth.uid()
  )
);

drop policy if exists "flashcards_delete_own" on public.flashcards;
create policy "flashcards_delete_own" on public.flashcards for delete using (
  exists (
    select 1 from public.decks
    where decks.id = flashcards.deck_id
    and decks.user_id = auth.uid()
  )
);

-- Indexes for incremental sync / queries
create index if not exists idx_flashcards_deck_updated on public.flashcards (deck_id, updated_at);
create index if not exists idx_flashcards_updated on public.flashcards (updated_at);
create index if not exists idx_flashcards_revision on public.flashcards (revision);

-- Trigger to update `updated_at` and bump `revision`
create or replace function public.touch_flashcards_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  if tg_op = 'INSERT' then
    new.revision = coalesce(new.revision, 0) + 1;
  elsif tg_op = 'UPDATE' then
    new.revision = coalesce(new.revision, 0) + 1;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_flashcards_touch on public.flashcards;
create trigger trg_flashcards_touch
before insert or update on public.flashcards
for each row execute function public.touch_flashcards_updated_at();


-- CAPTURES
create table if not exists public.captures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text,
  public_url text,
  created_at timestamptz not null default now(),
  uploaded bool not null default false,
  meta jsonb
);

alter table public.captures enable row level security;

drop policy if exists "captures_all_own" on public.captures;
create policy "captures_all_own" on public.captures for all using (auth.uid() = user_id);


-- OBJECT LABELS
create table if not exists public.object_labels (
  id bigint primary key generated by default as identity,
  capture_id uuid not null references public.captures(id) on delete cascade,
  label text not null,
  confidence numeric,
  bbox jsonb,
  language text
);

alter table public.object_labels enable row level security;

drop policy if exists "object_labels_select_own" on public.object_labels;
create policy "object_labels_select_own" on public.object_labels for select using (
  exists (
    select 1 from public.captures 
    where captures.id = object_labels.capture_id 
    and captures.user_id = auth.uid()
  )
);

drop policy if exists "object_labels_insert_own" on public.object_labels;
create policy "object_labels_insert_own" on public.object_labels for insert with check (
  exists (
    select 1 from public.captures 
    where captures.id = object_labels.capture_id 
    and captures.user_id = auth.uid()
  )
);

drop policy if exists "object_labels_update_own" on public.object_labels;
create policy "object_labels_update_own" on public.object_labels for update using (
  exists (
    select 1 from public.captures 
    where captures.id = object_labels.capture_id 
    and captures.user_id = auth.uid()
  )
);

drop policy if exists "object_labels_delete_own" on public.object_labels;
create policy "object_labels_delete_own" on public.object_labels for delete using (
  exists (
    select 1 from public.captures 
    where captures.id = object_labels.capture_id 
    and captures.user_id = auth.uid()
  )
);


-- STUDY SESSIONS
create table if not exists public.study_sessions (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id text not null references public.decks(id) on delete cascade,
  mode text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  is_synced boolean not null default false
);

alter table public.study_sessions enable row level security;

drop policy if exists "study_sessions_select_own" on public.study_sessions;
create policy "study_sessions_select_own" on public.study_sessions
  for select using (auth.uid() = user_id);

drop policy if exists "study_sessions_insert_own" on public.study_sessions;
create policy "study_sessions_insert_own" on public.study_sessions
  for insert with check (auth.uid() = user_id);

drop policy if exists "study_sessions_update_own" on public.study_sessions;
create policy "study_sessions_update_own" on public.study_sessions
  for update using (auth.uid() = user_id);

drop policy if exists "study_sessions_delete_own" on public.study_sessions;
create policy "study_sessions_delete_own" on public.study_sessions
  for delete using (auth.uid() = user_id);


-- STUDY RESULTS
create table if not exists public.study_results (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id text not null references public.study_sessions(id) on delete cascade,
  word_id text not null references public.words(id) on delete cascade,
  is_correct boolean not null,
  time_taken bigint not null,
  is_synced boolean not null default false
);

alter table public.study_results enable row level security;

drop policy if exists "study_results_select_own" on public.study_results;
create policy "study_results_select_own" on public.study_results
  for select using (auth.uid() = user_id);

drop policy if exists "study_results_insert_own" on public.study_results;
create policy "study_results_insert_own" on public.study_results
  for insert with check (auth.uid() = user_id);

drop policy if exists "study_results_update_own" on public.study_results;
create policy "study_results_update_own" on public.study_results
  for update using (auth.uid() = user_id);

drop policy if exists "study_results_delete_own" on public.study_results;
create policy "study_results_delete_own" on public.study_results
  for delete using (auth.uid() = user_id);


-- USER PROGRESS
create table if not exists public.user_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_words_mastered integer not null default 0,
  current_streak integer not null default 0,
  last_study_date timestamptz not null default now(),
  lifetime_accuracy double precision not null default 0,
  is_synced boolean not null default false
);

alter table public.user_progress enable row level security;

drop policy if exists "user_progress_select_own" on public.user_progress;
create policy "user_progress_select_own" on public.user_progress
  for select using (auth.uid() = user_id);

drop policy if exists "user_progress_insert_own" on public.user_progress;
create policy "user_progress_insert_own" on public.user_progress
  for insert with check (auth.uid() = user_id);

drop policy if exists "user_progress_update_own" on public.user_progress;
create policy "user_progress_update_own" on public.user_progress
  for update using (auth.uid() = user_id);

drop policy if exists "user_progress_delete_own" on public.user_progress;
create policy "user_progress_delete_own" on public.user_progress
  for delete using (auth.uid() = user_id);


-- DAILY PROGRESS
create table if not exists public.daily_progress (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date text not null,
  words_studied integer not null default 0,
  correct_answers integer not null default 0,
  is_synced boolean not null default false
);

alter table public.daily_progress enable row level security;

drop policy if exists "daily_progress_select_own" on public.daily_progress;
create policy "daily_progress_select_own" on public.daily_progress
  for select using (auth.uid() = user_id);

drop policy if exists "daily_progress_insert_own" on public.daily_progress;
create policy "daily_progress_insert_own" on public.daily_progress
  for insert with check (auth.uid() = user_id);

drop policy if exists "daily_progress_update_own" on public.daily_progress;
create policy "daily_progress_update_own" on public.daily_progress
  for update using (auth.uid() = user_id);

drop policy if exists "daily_progress_delete_own" on public.daily_progress;
create policy "daily_progress_delete_own" on public.daily_progress
  for delete using (auth.uid() = user_id);