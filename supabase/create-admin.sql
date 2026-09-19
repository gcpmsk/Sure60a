-- Run AFTER schema.sql and AFTER creating your admin in Authentication > Users.
-- In Supabase Authentication > Users > Add user > Create new user:
-- Email: avinash@sure60.in (or replace with your own real admin email)
-- Password: choose your own unique strong password; enable Auto Confirm User.
-- This script does NOT create a password or an Auth user.
-- Replace the email below if you created a different admin email.

do $$
declare
  admin_email text := 'avinash@sure60.in';
  admin_id uuid;
begin
  select id into admin_id from auth.users where lower(email) = lower(admin_email);
  if admin_id is null then
    raise exception 'Create the Auth user first: %', admin_email;
  end if;
  update public.profiles
  set role = 'admin', verified = true, full_name = 'Avinash'
  where id = admin_id;
  if not found then
    raise exception 'Profile missing. Create the Auth user AFTER running schema.sql.';
  end if;
end;
$$;

-- Confirm one admin was configured. Never share admin credentials with students.
select p.id, u.email as login_username, p.full_name, p.role, p.verified
from public.profiles p join auth.users u on u.id = p.id
where p.role = 'admin';
