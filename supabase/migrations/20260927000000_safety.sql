-- Player safety: block, report and suspend.
-- Blocking removes the friendship, so everything that needs friends (lounge visits,
-- guestbook, playdates) stops working between the two players straight away.

-- ---------------------------------------------------------------------------
-- Suspension (set by the developer from the dashboard after reviewing reports)
-- ---------------------------------------------------------------------------

alter table public.profiles add column suspended boolean not null default false;

-- ---------------------------------------------------------------------------
-- Blocks
-- ---------------------------------------------------------------------------

create table public.blocks (
  blocker_id uuid not null references public.profiles on delete cascade,
  blocked_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;
create policy "read own blocks" on public.blocks
  for select to authenticated using (blocker_id = (select auth.uid()));
revoke insert, update, delete on public.blocks from anon, authenticated;

create function public.is_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  );
$$;

create function public.is_suspended(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select suspended from public.profiles where id = p), false);
$$;

-- Friends only count if neither player blocked the other and neither is suspended.
create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.friendships where user_id = a and friend_id = b)
     and not public.is_blocked(a, b)
     and not public.is_suspended(a)
     and not public.is_suspended(b);
$$;

create function public.block_player(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_player = auth.uid() then raise exception 'You cannot block yourself'; end if;
  insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), p_player)
  on conflict do nothing;
  delete from public.friendships
  where (user_id = auth.uid() and friend_id = p_player) or (user_id = p_player and friend_id = auth.uid());
  update public.playdates set status = 'declined'
  where status in ('invited', 'active')
    and ((host_id = auth.uid() and guest_id = p_player) or (host_id = p_player and guest_id = auth.uid()));
end $$;

-- Unblocking doesn't restore the friendship; they can add each other again.
create function public.unblock_player(p_player uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.blocks where blocker_id = auth.uid() and blocked_id = p_player;
$$;

create function public.list_blocked()
returns table (id uuid, display_name text, blocked_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, b.created_at
  from public.blocks b join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Reports (only the developer reads these, from the dashboard)
-- ---------------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles on delete cascade,
  reported_id uuid not null references public.profiles on delete cascade,
  reason text not null check (reason in ('name', 'mean', 'cheating', 'other')),
  context text not null check (context in ('friends', 'lounge', 'guestbook', 'playdate', 'invite')),
  reported_name text,
  status text not null default 'open' check (status in ('open', 'actioned', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

create function public.report_player(p_player uuid, p_reason text, p_context text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_player = auth.uid() then raise exception 'You cannot report yourself'; end if;
  if (select count(*) from public.reports
      where reporter_id = auth.uid() and created_at > now() - interval '1 day') >= 20 then
    raise exception 'Too many reports today';
  end if;
  insert into public.reports (reporter_id, reported_id, reason, context, reported_name)
  values (auth.uid(), p_player, p_reason, p_context,
          (select display_name from public.profiles where id = p_player));
end $$;

-- ---------------------------------------------------------------------------
-- Respect blocks and suspensions everywhere else
-- ---------------------------------------------------------------------------

create or replace function public.add_friend_by_code(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare target uuid;
begin
  select id into target from public.profiles where friend_code = upper(trim(p_code)) and not suspended;
  if target is null then raise exception 'No player has that friend code'; end if;
  if target = auth.uid() then raise exception 'That is your own code'; end if;
  if public.is_blocked(auth.uid(), target) then raise exception 'No player has that friend code'; end if;
  perform public.make_friends(auth.uid(), target);
  return target;
end $$;

create or replace function public.link_game_center_friends(p_ids text[]) returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0; r record;
begin
  for r in select id from public.profiles
           where gc_player_id = any (p_ids[1:500]) and id <> auth.uid() and not suspended loop
    if not public.is_blocked(auth.uid(), r.id) then
      perform public.make_friends(auth.uid(), r.id);
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

create or replace function public.list_friends()
returns table (id uuid, display_name text, friend_code text, lounge jsonb, showcase jsonb,
               online_at timestamptz, points int)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.friend_code, p.lounge, p.showcase, p.online_at, f.points
  from public.friendships f join public.profiles p on p.id = f.friend_id
  where f.user_id = auth.uid() and not p.suspended and not public.is_blocked(auth.uid(), p.id)
  order by p.online_at desc;
$$;

drop function public.my_guestbook();
create function public.my_guestbook()
returns table (id uuid, visitor_id uuid, visitor_name text, visitor_showcase jsonb, sticker smallint,
               phrase smallint, gift text, thanked boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select g.id, g.visitor_id, p.display_name, p.showcase, g.sticker, g.phrase, g.gift, g.thanked, g.created_at
  from public.guestbook g join public.profiles p on p.id = g.visitor_id
  where g.owner_id = auth.uid() and not p.suspended and not public.is_blocked(auth.uid(), g.visitor_id)
  order by g.created_at desc limit 50;
$$;

-- Accepting an invite also needs the pair to still be friends (not blocked since).
create or replace function public.accept_playdate(p_id uuid, p_cat jsonb, p_rarity int) returns void
language plpgsql security definer set search_path = '' as $$
declare host uuid;
begin
  select host_id into host from public.playdates where id = p_id and guest_id = auth.uid();
  if host is null or not public.are_friends(auth.uid(), host) then raise exception 'That invite has expired'; end if;
  if public.playdates_today(auth.uid()) >= 3 then raise exception 'No playdates left today'; end if;
  update public.playdates
  set status = 'active', guest_cat = p_cat, guest_rarity = least(greatest(p_rarity, 0), 3), started_at = now()
  where id = p_id and guest_id = auth.uid() and status = 'invited'
    and created_at > now() - interval '15 minutes';
  if not found then raise exception 'That invite has expired'; end if;
end $$;
