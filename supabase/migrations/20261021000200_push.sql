-- Push notifications: playdate invites, friend requests and arena coins reach you
-- even when Club Kitten is closed.
--
-- Triggers call the `notify` edge function through pg_net. They need two Vault secrets,
-- added once from the SQL editor (see PUSH.md):
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/notify', 'notify_url');
--   select vault.create_secret('<long random string>', 'notify_secret');
-- Until both exist, nothing is sent and nothing fails.

create extension if not exists pg_net with schema extensions;

create table public.device_tokens (
  token text primary key check (char_length(token) between 32 and 200),
  user_id uuid not null references public.profiles on delete cascade,
  env text not null check (env in ('development', 'production')),
  updated_at timestamptz not null default now()
);
create index device_tokens_user on public.device_tokens (user_id);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;

-- Saves this phone's push token for the signed-in player (a token moves with whoever
-- signed in last on that phone).
create function public.register_device(p_token text, p_env text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  insert into public.device_tokens (token, user_id, env) values (lower(p_token), auth.uid(), p_env)
  on conflict (token) do update set user_id = excluded.user_id, env = excluded.env, updated_at = now();
end $$;

create function public.unregister_device(p_token text) returns void
language sql security definer set search_path = '' as $$
  delete from public.device_tokens where token = lower(p_token) and user_id = auth.uid();
$$;

revoke execute on function public.register_device(text, text), public.unregister_device(text) from public, anon;
grant execute on function public.register_device(text, text), public.unregister_device(text) to authenticated;

-- Hands one notification to the edge function. Never blocks or fails the change that caused it.
create function public.send_push(p_user uuid, p_title text, p_body text, p_kind text) returns void
language plpgsql security definer set search_path = '' as $$
declare url text; secret text;
begin
  if not exists (select 1 from public.device_tokens where user_id = p_user) then return; end if;
  select decrypted_secret into url from vault.decrypted_secrets where name = 'notify_url';
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'notify_secret';
  if url is null or secret is null then return; end if;
  perform net.http_post(
    url := url,
    body := jsonb_build_object('user_id', p_user, 'title', p_title, 'body', p_body, 'kind', p_kind),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', secret),
    timeout_milliseconds := 5000
  );
exception when others then
  raise warning 'push not sent: %', sqlerrm;
end $$;
revoke execute on function public.send_push(uuid, text, text, text) from public, anon, authenticated;

create function public.push_on_invite() returns trigger
language plpgsql security definer set search_path = '' as $$
declare host_name text; cat_name text;
begin
  select display_name into host_name from public.profiles where id = new.host_id;
  cat_name := coalesce(new.host_cat ->> 'name', 'Their cat');
  perform public.send_push(new.guest_id, host_name || ' invited you to a playdate 🐾',
                           cat_name || ' wants to meet your cat. Hurry, it expires in 15 minutes!', 'playdate');
  return new;
end $$;

create function public.push_on_friend_request() returns trigger
language plpgsql security definer set search_path = '' as $$
declare from_name text;
begin
  select display_name into from_name from public.profiles where id = new.from_id;
  perform public.send_push(new.to_id, from_name || ' wants to be friends',
                           'Open Club Kitten to accept and visit each other''s lounges.', 'friend_request');
  return new;
end $$;

create function public.push_on_coins() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cat_name text;
begin
  if new.source <> 'arena' then return new; end if;
  -- One push an hour at most, however many battles your defender wins.
  if exists (select 1 from public.coin_grants
             where user_id = new.user_id and source = 'arena' and id <> new.id
               and created_at > now() - interval '1 hour') then
    return new;
  end if;
  select cat ->> 'name' into cat_name from public.arena_defenders where user_id = new.user_id;
  perform public.send_push(new.user_id, coalesce(cat_name, 'Your defender') || ' won in the arena! 🏆',
                           '+' || new.amount || ' coins are waiting for you.', 'arena');
  return new;
end $$;

create trigger playdate_invite_push after insert on public.playdates
  for each row when (new.status = 'invited') execute function public.push_on_invite();
create trigger friend_request_push after insert on public.friend_requests
  for each row execute function public.push_on_friend_request();
create trigger arena_coins_push after insert on public.coin_grants
  for each row execute function public.push_on_coins();
