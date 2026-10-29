-- Cine Music Forum: crea la tabella delle proposte e le regole di accesso.
-- Supabase > SQL Editor > New query > incolla tutto > Run.

create table if not exists public.items (
  id          uuid primary key,
  owner_token uuid not null,
  kind        text not null check (kind in ('film','album')),
  title       text not null check (char_length(title) between 1 and 80),
  creator     text check (char_length(creator) <= 60),
  genres      text[] not null check (cardinality(genres) between 1 and 2),
  note        text check (char_length(note) <= 200),
  anon        boolean not null default false,
  nick        text check (char_length(nick) <= 30),
  status      text not null default 'pool' check (status in ('pool','chosen')),
  chosen_at   timestamptz,
  theme       text check (char_length(theme) <= 60),
  created_at  timestamptz not null default now(),
  check (anon or (nick is not null and char_length(nick) > 0)),
  check (not anon or nick is null)
);

alter table public.items enable row level security;

-- Togli i permessi di default e concedi solo le colonne necessarie.
-- owner_token non è mai leggibile: serve solo a chi ha proposto per eliminare la propria proposta.
revoke all on public.items from anon, authenticated;
grant select (id, kind, title, creator, genres, note, anon, nick, status, chosen_at, theme, created_at)
  on public.items to anon, authenticated;
grant insert (id, owner_token, kind, title, creator, genres, note, anon, nick)
  on public.items to anon, authenticated;
grant update (status, chosen_at, theme)
  on public.items to anon, authenticated;

drop policy if exists "leggi tutto" on public.items;
drop policy if exists "proponi" on public.items;
drop policy if exists "estrai" on public.items;
create policy "leggi tutto" on public.items for select using (true);
create policy "proponi"     on public.items for insert with check (status = 'pool');
create policy "estrai"      on public.items for update using (true) with check (true);

-- Eliminazione: solo chi ha il token della proposta (salvato nel suo browser).
create or replace function public.delete_item(p_id uuid, p_token uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.items where id = p_id and owner_token = p_token;
$$;
revoke all on function public.delete_item(uuid, uuid) from public;
grant execute on function public.delete_item(uuid, uuid) to anon, authenticated;
