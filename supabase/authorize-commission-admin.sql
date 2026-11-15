-- Authorize the existing portfolio administrator for this app only.
-- This does not create a Supabase Auth user and does not enable public registration.
-- If this exact email is not already present in Auth, no row is inserted.
insert into public.commission_admins (user_id)
select id
from auth.users
where lower(email) = lower('jannesilly@gmail.com')
on conflict (user_id) do nothing;
