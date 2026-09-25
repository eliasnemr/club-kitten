-- Club Kitten multiplayer: profiles, friends, guestbooks, playdates and egg grants.
-- Clients never write friendships, playdates or eggs directly; they go through the
-- security-definer functions below so limits and egg rolls are decided by the server.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null default 'Player' check (char_length(display_name) between 1 and 24),
  friend_code text not null unique
    default ('KIT-' || upper(substr(encode(extensions.gen_random_bytes(4), 'hex'), 1, 6))),
  gc_player_id text unique,               -- set only by the link-game-center function
  lounge jsonb not null default '{}'::jsonb,
  showcase jsonb not null default '[]'::jsonb,  -- up to 5 cats shown to visitors
  online_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "read own profile" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "update own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name, lounge, showcase, online_at, updated_at) on public.profiles to authenticated;

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Friendships (stored in both directions)
-- ---------------------------------------------------------------------------

create table public.friendships (
  user_id uuid not null references public.profiles on delete cascade,
  friend_id uuid not null references public.profiles on delete cascade,
  points int not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

alter table public.friendships enable row level security;
create policy "read own friendships" on public.friendships
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.friendships from anon, authenticated;

create function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.friendships where user_id = a and friend_id = b);
$$;

create function public.make_friends(a uuid, b uuid) returns void
language sql security definer set search_path = '' as $$
  insert into public.friendships (user_id, friend_id) values (a, b), (b, a)
  on conflict do nothing;
$$;
revoke execute on function public.make_friends(uuid, uuid) from public, anon, authenticated;

create function public.add_friend_by_code(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare target uuid;
begin
  select id into target from public.profiles where friend_code = upper(trim(p_code));
  if target is null then raise exception 'No player has that friend code'; end if;
  if target = auth.uid() then raise exception 'That is your own code'; end if;
  perform public.make_friends(auth.uid(), target);
  return target;
end $$;

-- Game Center friends who also play become friends automatically.
create function public.link_game_center_friends(p_ids text[]) returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0; r record;
begin
  for r in select id from public.profiles
           where gc_player_id = any (p_ids[1:500]) and id <> auth.uid() loop
    perform public.make_friends(auth.uid(), r.id);
    n := n + 1;
  end loop;
  return n;
end $$;

create function public.list_friends()
returns table (id uuid, display_name text, friend_code text, lounge jsonb, showcase jsonb,
               online_at timestamptz, points int)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.friend_code, p.lounge, p.showcase, p.online_at, f.points
  from public.friendships f join public.profiles p on p.id = f.friend_id
  where f.user_id = auth.uid()
  order by p.online_at desc;
$$;

-- Petting, treats and guestbook signatures raise friendship a little at a time.
create function public.bump_friendship(p_friend uuid, p_amount int) returns int
language plpgsql security definer set search_path = '' as $$
declare total int;
begin
  update public.friendships set points = points + least(greatest(p_amount, 1), 5)
  where (user_id = auth.uid() and friend_id = p_friend) or (user_id = p_friend and friend_id = auth.uid());
  select points into total from public.friendships where user_id = auth.uid() and friend_id = p_friend;
  if total is null then raise exception 'Not friends'; end if;
  return total;
end $$;

-- ---------------------------------------------------------------------------
-- Guestbook (safe chat: stickers and phrases are indexes, never free text)
-- ---------------------------------------------------------------------------

create table public.guestbook (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles on delete cascade,
  visitor_id uuid not null references public.profiles on delete cascade,
  sticker smallint not null check (sticker between 0 and 5),
  phrase smallint check (phrase between 0 and 5),
  gift text check (gift in ('treat', 'yarn')),
  thanked boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.guestbook enable row level security;
create policy "sign a friend's guestbook" on public.guestbook
  for insert to authenticated
  with check (visitor_id = (select auth.uid()) and public.are_friends(owner_id, (select auth.uid())));
create policy "read guestbooks you are in" on public.guestbook
  for select to authenticated
  using (owner_id = (select auth.uid()) or visitor_id = (select auth.uid()));
create policy "owner thanks visitors" on public.guestbook
  for update to authenticated using (owner_id = (select auth.uid()));
revoke update on public.guestbook from authenticated;
grant update (thanked) on public.guestbook to authenticated;

create function public.my_guestbook()
returns table (id uuid, visitor_name text, visitor_showcase jsonb, sticker smallint, phrase smallint,
               gift text, thanked boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select g.id, p.display_name, p.showcase, g.sticker, g.phrase, g.gift, g.thanked, g.created_at
  from public.guestbook g join public.profiles p on p.id = g.visitor_id
  where g.owner_id = auth.uid()
  order by g.created_at desc limit 50;
$$;

-- ---------------------------------------------------------------------------
-- Playdates and eggs
-- ---------------------------------------------------------------------------

create table public.playdates (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles on delete cascade,
  guest_id uuid not null references public.profiles on delete cascade,
  host_cat jsonb not null,
  guest_cat jsonb,
  host_rarity smallint not null check (host_rarity between 0 and 3),
  guest_rarity smallint check (guest_rarity between 0 and 3),
  status text not null default 'invited' check (status in ('invited', 'active', 'done', 'declined')),
  bond int not null default 10,
  last_act jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  chance int,
  result smallint,              -- null = no egg, otherwise rarity 0..3
  created_at timestamptz not null default now()
);

alter table public.playdates enable row level security;
create policy "players see their playdates" on public.playdates
  for select to authenticated using ((select auth.uid()) in (host_id, guest_id));
revoke insert, update, delete on public.playdates from anon, authenticated;

create table public.egg_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  rarity smallint not null check (rarity between 0 and 3),
  source text not null,
  claimed boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.egg_grants enable row level security;
create policy "read own eggs" on public.egg_grants
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.egg_grants from anon, authenticated;

create function public.playdates_today(p_user uuid) returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.playdates
  where (host_id = p_user or guest_id = p_user) and status in ('active', 'done')
    and started_at >= date_trunc('day', now());
$$;

create function public.invite_playdate(p_friend uuid, p_cat jsonb, p_rarity int) returns uuid
language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
  if not public.are_friends(auth.uid(), p_friend) then raise exception 'Not friends'; end if;
  if public.playdates_today(auth.uid()) >= 3 then raise exception 'No playdates left today'; end if;
  -- One open invite per pair.
  update public.playdates set status = 'declined'
  where host_id = auth.uid() and guest_id = p_friend and status = 'invited';
  insert into public.playdates (host_id, guest_id, host_cat, host_rarity)
  values (auth.uid(), p_friend, p_cat, least(greatest(p_rarity, 0), 3))
  returning id into new_id;
  return new_id;
end $$;

create function public.accept_playdate(p_id uuid, p_cat jsonb, p_rarity int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if public.playdates_today(auth.uid()) >= 3 then raise exception 'No playdates left today'; end if;
  update public.playdates
  set status = 'active', guest_cat = p_cat, guest_rarity = least(greatest(p_rarity, 0), 3), started_at = now()
  where id = p_id and guest_id = auth.uid() and status = 'invited'
    and created_at > now() - interval '15 minutes';
  if not found then raise exception 'That invite has expired'; end if;
end $$;

create function public.decline_playdate(p_id uuid) returns void
language sql security definer set search_path = '' as $$
  update public.playdates set status = 'declined'
  where id = p_id and auth.uid() in (host_id, guest_id) and status = 'invited';
$$;

-- Activities have per-player cooldowns (seconds) and bond gains, checked here.
create function public.playdate_act(p_id uuid, p_activity text) returns int
language plpgsql security definer set search_path = '' as $$
declare
  pd public.playdates;
  gain int; cooldown int; k text; last_at double precision;
begin
  select * into pd from public.playdates where id = p_id for update;
  if pd is null or auth.uid() not in (pd.host_id, pd.guest_id) then raise exception 'Not your playdate'; end if;
  if pd.status <> 'active' or now() > pd.started_at + interval '65 seconds' then raise exception 'Playdate is over'; end if;
  case p_activity
    when 'yarn' then gain := 10; cooldown := 4;
    when 'groom' then gain := 8; cooldown := 3;
    when 'nap' then gain := 15; cooldown := 10;
    when 'treats' then gain := 6; cooldown := 5;
    else raise exception 'Unknown activity';
  end case;
  k := auth.uid()::text || ':' || p_activity;
  last_at := (pd.last_act ->> k)::double precision;
  if last_at is not null and extract(epoch from now()) - last_at < cooldown then
    return pd.bond;
  end if;
  update public.playdates
  set bond = least(100, bond + gain),
      last_act = last_act || jsonb_build_object(k, extract(epoch from now()))
  where id = p_id
  returning bond into gain;
  return gain;
end $$;

create function public.rarity_bonus(r int) returns int
language sql immutable as $$ select (array[0, 5, 10, 15])[coalesce(r, 0) + 1]; $$;

-- Either player can end it. The first call rolls the egg; later calls return the same result.
create function public.finish_playdate(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  pd public.playdates;
  pts int; total int; roll double precision; luck double precision; tier smallint;
begin
  select * into pd from public.playdates where id = p_id for update;
  if pd is null or auth.uid() not in (pd.host_id, pd.guest_id) then raise exception 'Not your playdate'; end if;
  if pd.status = 'done' then return jsonb_build_object('result', pd.result, 'chance', pd.chance); end if;
  if pd.status <> 'active' then raise exception 'Playdate never started'; end if;

  select points into pts from public.friendships where user_id = pd.host_id and friend_id = pd.guest_id;
  total := 10 + public.rarity_bonus(pd.host_rarity) + public.rarity_bonus(pd.guest_rarity)
           + case when pd.bond >= 80 then 12 when pd.bond >= 50 then 6 else 0 end
           + least(coalesce(pts, 0) / 30, 10);
  total := least(total, 60);

  roll := random() * 100;
  if roll < total then
    luck := (total - 10) / 200.0;
    roll := random() - luck;
    tier := case when roll < 0.03 then 3 when roll < 0.13 then 2 when roll < 0.40 then 1 else 0 end;
    insert into public.egg_grants (user_id, rarity, source)
    values (pd.host_id, tier, 'Playdate'), (pd.guest_id, tier, 'Playdate');
  end if;

  update public.playdates set status = 'done', result = tier, chance = total where id = p_id;
  update public.friendships set points = points + 5
  where (user_id = pd.host_id and friend_id = pd.guest_id) or (user_id = pd.guest_id and friend_id = pd.host_id);
  return jsonb_build_object('result', tier, 'chance', total);
end $$;

create function public.claim_eggs()
returns setof public.egg_grants
language sql security definer set search_path = '' as $$
  update public.egg_grants set claimed = true
  where user_id = auth.uid() and not claimed
  returning *;
$$;

-- ---------------------------------------------------------------------------
-- Realtime: playdate and guestbook changes, and private lounge channels
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.playdates, public.guestbook;

-- Lounge channels are named "lounge:<owner uuid>". Only the owner and their friends may join or send.
create function public.can_use_lounge_topic(topic text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare owner uuid;
begin
  if topic not like 'lounge:%' then return false; end if;
  owner := nullif(split_part(topic, ':', 2), '')::uuid;
  return owner = auth.uid() or public.are_friends(owner, auth.uid());
exception when invalid_text_representation then
  return false;
end $$;

create policy "friends join lounges" on realtime.messages
  for select to authenticated using (public.can_use_lounge_topic((select realtime.topic())));
create policy "friends talk in lounges" on realtime.messages
  for insert to authenticated with check (public.can_use_lounge_topic((select realtime.topic())));
