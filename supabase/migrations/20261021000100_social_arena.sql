-- Friend requests, invite links, suggested players, and arena defenders that earn coins.
-- As before, clients only read their own rows; everything else goes through the
-- security-definer functions below.

-- ---------------------------------------------------------------------------
-- Arena: a defender cat per player, match history, and coins waiting to be claimed
-- ---------------------------------------------------------------------------

create table public.arena_defenders (
  user_id uuid primary key references public.profiles on delete cascade,
  cat jsonb not null,
  level int not null check (level between 1 and 999),
  wins int not null default 0,
  losses int not null default 0,
  coins_earned int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.arena_defenders enable row level security;
create policy "read own defender" on public.arena_defenders
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.arena_defenders from anon, authenticated;

create table public.arena_matches (
  id uuid primary key default gen_random_uuid(),
  attacker uuid not null references public.profiles on delete cascade,
  defender uuid not null references public.profiles on delete cascade,
  defender_won boolean not null,
  payout int not null default 0,
  created_at timestamptz not null default now(),
  check (attacker <> defender)
);
create index arena_matches_attacker on public.arena_matches (attacker, created_at desc);
create index arena_matches_defender on public.arena_matches (defender, created_at desc);
alter table public.arena_matches enable row level security;
revoke all on public.arena_matches from anon, authenticated;

create table public.coin_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  amount int not null check (amount between 1 and 1000),
  source text not null,
  claimed boolean not null default false,
  created_at timestamptz not null default now()
);
create index coin_grants_unclaimed on public.coin_grants (user_id) where not claimed;
alter table public.coin_grants enable row level security;
create policy "read own coin grants" on public.coin_grants
  for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete on public.coin_grants from anon, authenticated;

-- Puts one of your cats in the arena (replacing the last one).
create function public.set_defender(p_cat jsonb, p_level int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if jsonb_typeof(p_cat) <> 'object' or octet_length(p_cat::text) > 20000 then
    raise exception 'That cat can''t defend';
  end if;
  insert into public.arena_defenders (user_id, cat, level)
  values (auth.uid(), p_cat, least(greatest(p_level, 1), 999))
  on conflict (user_id) do update
    set cat = excluded.cat, level = excluded.level, updated_at = now();
end $$;

create function public.clear_defender() returns void
language sql security definer set search_path = '' as $$
  delete from public.arena_defenders where user_id = auth.uid();
$$;

-- Up to three defenders near your level that you haven't fought in the last hour.
create function public.arena_opponents(p_level int)
returns table (user_id uuid, display_name text, cat jsonb, level int, wins int, losses int)
language sql stable security definer set search_path = '' as $$
  select d.user_id, p.display_name, d.cat, d.level, d.wins, d.losses
  from public.arena_defenders d join public.profiles p on p.id = d.user_id
  where d.user_id <> auth.uid()
    and not p.suspended
    and not public.is_blocked(auth.uid(), d.user_id)
    and d.updated_at > now() - interval '30 days'
    and not exists (select 1 from public.arena_matches m
                    where m.attacker = auth.uid() and m.defender = d.user_id
                      and m.created_at > now() - interval '1 hour')
  order by greatest(abs(d.level - p_level) - 3, 0), random()
  limit 3;
$$;

-- Records a fight against a player's defender (the battle itself runs on the attacker's phone).
-- When the defender wins, its owner earns 10 coins: at most once per attacker per day,
-- and at most 150 coins a day in total. Returns the coins paid to the defender.
create function public.report_arena_result(p_defender uuid, p_defender_won boolean) returns int
language plpgsql security definer set search_path = '' as $$
declare pay int := 0;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_defender = auth.uid() then raise exception 'You can''t fight your own defender'; end if;
  if not exists (select 1 from public.arena_defenders where user_id = p_defender) then
    raise exception 'That defender has left the arena';
  end if;
  if public.is_blocked(auth.uid(), p_defender) then raise exception 'That defender has left the arena'; end if;
  if (select count(*) from public.arena_matches
      where attacker = auth.uid() and created_at > now() - interval '1 day') >= 30 then
    raise exception 'You''ve fought enough players for today';
  end if;

  if p_defender_won
     and not exists (select 1 from public.arena_matches
                     where attacker = auth.uid() and defender = p_defender and payout > 0
                       and created_at > now() - interval '1 day')
     and coalesce((select sum(payout) from public.arena_matches
                   where defender = p_defender and created_at > now() - interval '1 day'), 0) < 150 then
    pay := 10;
  end if;

  insert into public.arena_matches (attacker, defender, defender_won, payout)
  values (auth.uid(), p_defender, p_defender_won, pay);
  update public.arena_defenders
  set wins = wins + case when p_defender_won then 1 else 0 end,
      losses = losses + case when p_defender_won then 0 else 1 end,
      coins_earned = coins_earned + pay
  where user_id = p_defender;
  if pay > 0 then
    insert into public.coin_grants (user_id, amount, source) values (p_defender, pay, 'arena');
  end if;
  return pay;
end $$;

-- Hands over coins earned while you were away (marks them claimed).
create function public.claim_coins()
returns table (amount int, source text)
language sql security definer set search_path = '' as $$
  update public.coin_grants set claimed = true
  where user_id = auth.uid() and not claimed
  returning amount, source;
$$;

-- ---------------------------------------------------------------------------
-- Friend requests
-- ---------------------------------------------------------------------------

create table public.friend_requests (
  from_id uuid not null references public.profiles on delete cascade,
  to_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id),
  check (from_id <> to_id)
);
create index friend_requests_to on public.friend_requests (to_id);
alter table public.friend_requests enable row level security;
create policy "see own friend requests" on public.friend_requests
  for select to authenticated using ((select auth.uid()) in (from_id, to_id));
revoke insert, update, delete on public.friend_requests from anon, authenticated;

alter publication supabase_realtime add table public.friend_requests;

-- Sends a request, or becomes friends straight away if they already asked you.
-- Returns 'requested' or 'friends'.
create function public.request_friend(p_player uuid) returns text
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_player = auth.uid() then raise exception 'That is you!'; end if;
  if public.is_blocked(auth.uid(), p_player) or public.is_suspended(p_player)
     or not exists (select 1 from public.profiles where id = p_player) then
    raise exception 'That player can''t be added right now';
  end if;
  if exists (select 1 from public.friendships where user_id = auth.uid() and friend_id = p_player) then
    return 'friends';
  end if;
  if exists (select 1 from public.friend_requests where from_id = p_player and to_id = auth.uid()) then
    delete from public.friend_requests where from_id = p_player and to_id = auth.uid();
    perform public.make_friends(auth.uid(), p_player);
    return 'friends';
  end if;
  if (select count(*) from public.friend_requests
      where from_id = auth.uid() and created_at > now() - interval '1 day') >= 30 then
    raise exception 'Too many friend requests today';
  end if;
  insert into public.friend_requests (from_id, to_id) values (auth.uid(), p_player)
  on conflict do nothing;
  return 'requested';
end $$;

create function public.request_friend_by_code(p_code text)
returns table (status text, player_id uuid, display_name text)
language plpgsql security definer set search_path = '' as $$
declare target uuid; name text;
begin
  select p.id, p.display_name into target, name from public.profiles p
  where p.friend_code = upper(trim(p_code)) and not p.suspended;
  if target is null or public.is_blocked(auth.uid(), target) then
    raise exception 'No player has that friend code';
  end if;
  if target = auth.uid() then raise exception 'That is your own code'; end if;
  return query select public.request_friend(target), target, name;
end $$;

create function public.respond_friend_request(p_from uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.friend_requests where from_id = p_from and to_id = auth.uid();
  if not found then raise exception 'That request has gone'; end if;
  if p_accept and not public.is_blocked(auth.uid(), p_from) and not public.is_suspended(p_from) then
    perform public.make_friends(auth.uid(), p_from);
  end if;
end $$;

create function public.cancel_friend_request(p_to uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.friend_requests where from_id = auth.uid() and to_id = p_to;
$$;

-- Requests to you and from you, with the other player's name and showcase.
create function public.my_friend_requests()
returns table (player_id uuid, display_name text, showcase jsonb, incoming boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.showcase, (r.to_id = auth.uid()), r.created_at
  from public.friend_requests r
  join public.profiles p on p.id = case when r.to_id = auth.uid() then r.from_id else r.to_id end
  where auth.uid() in (r.from_id, r.to_id)
    and not p.suspended and not public.is_blocked(auth.uid(), p.id)
  order by r.created_at desc;
$$;

-- Opening someone's invite link: they shared it and you tapped it, so you become
-- friends right away. Returns who you're now friends with.
create function public.redeem_invite(p_code text)
returns table (player_id uuid, display_name text)
language plpgsql security definer set search_path = '' as $$
declare target uuid; name text;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select p.id, p.display_name into target, name from public.profiles p
  where p.friend_code = upper(trim(p_code)) and not p.suspended;
  if target is null or public.is_blocked(auth.uid(), target) then
    raise exception 'That invite link doesn''t work any more';
  end if;
  if target = auth.uid() then raise exception 'That is your own invite link'; end if;
  delete from public.friend_requests
  where (from_id = auth.uid() and to_id = target) or (from_id = target and to_id = auth.uid());
  perform public.make_friends(auth.uid(), target);
  return query select target, name;
end $$;

-- ---------------------------------------------------------------------------
-- People you may know: friends of friends, and players you met in the arena
-- ---------------------------------------------------------------------------

create function public.suggested_players(p_limit int default 10)
returns table (player_id uuid, display_name text, star jsonb, mutual_friends int, met_in_arena boolean)
language sql stable security definer set search_path = '' as $$
  with fof as (
    select f2.friend_id as id, count(*)::int as mutual
    from public.friendships f1
    join public.friendships f2 on f2.user_id = f1.friend_id
    where f1.user_id = auth.uid() and f2.friend_id <> auth.uid()
    group by f2.friend_id
  ), met as (
    select case when m.attacker = auth.uid() then m.defender else m.attacker end as id,
           max(m.created_at) as last_met
    from public.arena_matches m
    where auth.uid() in (m.attacker, m.defender) and m.created_at > now() - interval '14 days'
    group by 1
  )
  select p.id, p.display_name, p.showcase -> 0, coalesce(fof.mutual, 0), met.id is not null
  from public.profiles p
  left join fof on fof.id = p.id
  left join met on met.id = p.id
  where (fof.id is not null or met.id is not null)
    and p.id <> auth.uid()
    and not p.suspended
    and not public.is_blocked(auth.uid(), p.id)
    and not exists (select 1 from public.friendships f where f.user_id = auth.uid() and f.friend_id = p.id)
    and not exists (select 1 from public.friend_requests r
                    where (r.from_id = auth.uid() and r.to_id = p.id) or (r.from_id = p.id and r.to_id = auth.uid()))
  order by coalesce(fof.mutual, 0) desc, met.last_met desc nulls last
  limit least(greatest(p_limit, 1), 20);
$$;

-- Nothing here is for signed-out visitors.
revoke execute on function public.set_defender(jsonb, int), public.clear_defender(),
  public.arena_opponents(int), public.report_arena_result(uuid, boolean), public.claim_coins(),
  public.request_friend(uuid), public.request_friend_by_code(text), public.respond_friend_request(uuid, boolean),
  public.cancel_friend_request(uuid), public.my_friend_requests(), public.redeem_invite(text),
  public.suggested_players(int)
  from public, anon;
grant execute on function public.set_defender(jsonb, int), public.clear_defender(),
  public.arena_opponents(int), public.report_arena_result(uuid, boolean), public.claim_coins(),
  public.request_friend(uuid), public.request_friend_by_code(text), public.respond_friend_request(uuid, boolean),
  public.cancel_friend_request(uuid), public.my_friend_requests(), public.redeem_invite(text),
  public.suggested_players(int)
  to authenticated;
