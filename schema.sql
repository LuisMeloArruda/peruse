-- DECKS
create table if not exists public.decks (
  id text primary key,
  name text not null,
  color text not null,
  icon text not null,
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