-- Migration: Create starters table in Supabase
-- Fields requested: id, title, summary, category, angles text[], notion_page_ids text[], created_at, updated_at

create table if not exists public.starters (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text,
  category text,
  angles text[] default '{}',
  notion_page_ids text[] default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable Row Level Security
alter table public.starters enable row level security;

-- Drop existing policy if present
drop policy if exists "Allow all access to starters" on public.starters;

-- Allow anon and authenticated access to read/write starters
create policy "Allow all access to starters"
  on public.starters
  for all
  using (true)
  with check (true);

-- Index for category and created_at sorting
create index if not exists idx_starters_category on public.starters(category);
create index if not exists idx_starters_created_at on public.starters(created_at desc);

-- Trigger to automatically update updated_at timestamp
create or replace function public.handle_starters_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_starters_updated_at on public.starters;

create trigger set_starters_updated_at
  before update on public.starters
  for each row
  execute function public.handle_starters_updated_at();
