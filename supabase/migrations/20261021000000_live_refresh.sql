-- Keeping friends' lounges and playdate invites fresh while the app is open.

-- One friend's latest profile, fetched when you visit their lounge (same columns as list_friends).
create function public.friend_profile(p_id uuid)
returns table (id uuid, display_name text, friend_code text, lounge jsonb, showcase jsonb,
               online_at timestamptz, points int)
language sql stable security definer set search_path = '' as $$
  select p.id, p.display_name, p.friend_code, p.lounge, p.showcase, p.online_at, f.points
  from public.friendships f join public.profiles p on p.id = f.friend_id
  where f.user_id = auth.uid() and f.friend_id = p_id
    and not p.suspended and not public.is_blocked(auth.uid(), p.id);
$$;

-- Open invites to you, with who sent them, so an invite shows even before the
-- sender appears in your friends list.
create function public.my_invites()
returns table (id uuid, host_id uuid, guest_id uuid, host_cat jsonb, guest_cat jsonb, status text,
               bond int, started_at timestamptz, chance int, result smallint,
               host_name text, host_showcase jsonb)
language sql stable security definer set search_path = '' as $$
  select pd.id, pd.host_id, pd.guest_id, pd.host_cat, pd.guest_cat, pd.status,
         pd.bond, pd.started_at, pd.chance, pd.result, p.display_name, p.showcase
  from public.playdates pd join public.profiles p on p.id = pd.host_id
  where pd.guest_id = auth.uid() and pd.status = 'invited'
    and pd.created_at > now() - interval '15 minutes'
    and not p.suspended and not public.is_blocked(auth.uid(), pd.host_id)
  order by pd.created_at desc;
$$;

revoke execute on function public.friend_profile(uuid) from public, anon;
revoke execute on function public.my_invites() from public, anon;
grant execute on function public.friend_profile(uuid) to authenticated;
grant execute on function public.my_invites() to authenticated;
