-- Cloud save: one row per player holding their whole game, so progress survives
-- deleting the app and can be restored. The phone stays the main copy; the server
-- keeps the newest version it has been sent.

create table public.saves (
  user_id uuid primary key references public.profiles on delete cascade,
  data jsonb not null,
  version bigint not null check (version >= 0),
  device_id text not null check (char_length(device_id) between 1 and 64),
  updated_at timestamptz not null default now()
);

alter table public.saves enable row level security;
create policy "read own save" on public.saves
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.saves from anon, authenticated;

-- Stores the save only if it is newer than the one on the server.
-- Returns {"accepted": bool, "version": <server version after the call>}.
create function public.push_save(p_data jsonb, p_version bigint, p_device text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare stored bigint;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if octet_length(p_data::text) > 1000000 then raise exception 'Save is too large'; end if;

  insert into public.saves (user_id, data, version, device_id)
  values (auth.uid(), p_data, p_version, left(p_device, 64))
  on conflict (user_id) do update
    set data = excluded.data, version = excluded.version,
        device_id = excluded.device_id, updated_at = now()
    where public.saves.version < excluded.version
  returning version into stored;

  if stored is null then
    select version into stored from public.saves where user_id = auth.uid();
    return jsonb_build_object('accepted', false, 'version', stored);
  end if;
  return jsonb_build_object('accepted', true, 'version', stored);
end $$;
