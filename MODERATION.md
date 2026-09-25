# Moderation guide

Players can **report** and **block** each other from the Friends list, a friend's lounge, the guestbook and playdate invites. Blocking is instant and needs nothing from you. Reports land in the `reports` table for you to review.

## Reviewing reports

Supabase dashboard → **SQL Editor** (project `club-kitten`):

```sql
-- Open reports, newest first, with how often each player has been reported
select r.created_at, r.reason, r.context, r.reported_name, r.reported_id,
       count(*) over (partition by r.reported_id) as times_reported
from reports r
where r.status = 'open'
order by r.created_at desc;
```

Reasons: `name` (inappropriate name), `mean` (mean or bullying), `cheating`, `other`.

## Taking action

```sql
-- Suspend a player: they disappear from everyone's friends, can't be added,
-- can't visit, sign guestbooks or send playdate invites.
update profiles set suspended = true where id = '<reported_id>';

-- Reset an inappropriate name (names come from Game Center; this hides it in the game)
update profiles set display_name = 'Player' where id = '<reported_id>';

-- Mark the reports handled
update reports set status = 'actioned' where reported_id = '<reported_id>' and status = 'open';
-- or: set status = 'dismissed'

-- Lift a suspension
update profiles set suspended = false where id = '<player_id>';
```

## Deleting a player's data (privacy requests)

```sql
-- Removes the account and everything linked to it (profile, save, friends, guestbook, playdates, reports)
delete from auth.users where id = '<player_id>';
```

Apple expects you to act on reports of objectionable content within 24 hours.
