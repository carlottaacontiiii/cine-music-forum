-- Aggiornamento 1: permette a chi ha proposto di modificare la propria proposta.
-- Supabase > SQL Editor > New query > incolla tutto > Run. Va eseguito una volta sola.

-- Un genere scritto a mano ("Altro") resta corto.
alter table public.items drop constraint if exists items_genres_len;
alter table public.items add constraint items_genres_len
  check (char_length(array_to_string(genres, '')) <= 60);

-- Modifica: solo con il token della proposta (salvato nel browser di chi l'ha fatta).
-- Se il titolo è già stato estratto, tipo e generi restano quelli di prima.
create or replace function public.update_item(
  p_id uuid, p_token uuid, p_kind text, p_title text, p_creator text,
  p_genres text[], p_note text, p_anon boolean, p_nick text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare n int;
begin
  update public.items set
    kind    = case when status = 'chosen' then kind   else p_kind   end,
    genres  = case when status = 'chosen' then genres else p_genres end,
    title   = p_title,
    creator = nullif(trim(p_creator), ''),
    note    = nullif(trim(p_note), ''),
    anon    = p_anon,
    nick    = case when p_anon then null else nullif(trim(p_nick), '') end
  where id = p_id and owner_token = p_token;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;
revoke all on function public.update_item(uuid, uuid, text, text, text, text[], text, boolean, text) from public;
grant execute on function public.update_item(uuid, uuid, text, text, text, text[], text, boolean, text) to anon, authenticated;
