-- SURE60: Run this entire file ONCE in a fresh Supabase project's SQL Editor.
-- Never put service_role keys or passwords into frontend environment variables.
begin;
create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null check (length(full_name) between 2 and 100),
  username text not null unique check (username ~ '^[a-z0-9][a-z0-9_-]{2,39}$'),
  phone text not null default '',
  role text not null default 'student' check (role in ('student','admin')),
  verified boolean not null default false,
  created_at timestamptz not null default now()
);
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
create function public.is_verified() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and (verified or role = 'admin'));
$$;
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name, username, phone)
  values(new.id, left(coalesce(nullif(new.raw_user_meta_data->>'full_name',''),'New student'),100),
    lower(coalesce(nullif(new.raw_user_meta_data->>'username',''),'user_' || substr(new.id::text,1,12))),
    left(coalesce(new.raw_user_meta_data->>'phone',''),20));
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create table public.site_settings (id integer primary key default 1 check(id=1), data jsonb not null default '{}');
insert into public.site_settings(data) values ('{"brand":"Sure60","tagline":"Your ambition. Our mission.","address":"Karnal Campus, Karnal, Haryana","phone":"","email":"","announcement":"A new chapter of your success starts here. Explore our learning programmes.","logo_url":"","instagram":"","youtube":"","facebook":"","telegram":"","whatsapp":"","map_url":""}');
create table public.hero_slides (
 id uuid primary key default gen_random_uuid(), eyebrow text not null, title text not null,
 description text not null, image_url text not null default '', button_text text not null default 'Explore programmes',
 target text not null default 'batches' check(target in ('batches','tests','register')), sort_order integer not null default 0, active boolean not null default true
);
insert into public.hero_slides(eyebrow,title,description,sort_order) values
 ('LEARN WITH PURPOSE. ACHIEVE WITH CONFIDENCE.','Big dreams.\nThe right direction.','Expert-led classes, focused practice and a community that believes in you. Take your next big step with Sure60.',0),
 ('PRACTICE TODAY. PERFORM TOMORROW.','Every question.\nOne step closer.','Build confidence with timed practice tests, instant results and an all-student leaderboard. Make every attempt count.',1),
 ('YOUR CLASSROOM, WHEREVER YOU ARE.','Your pace.\nYour possibility.','Revisit your favourite lessons, find subject-wise study notes and keep your preparation moving forward.',2);
create table public.batches (
 id uuid primary key default gen_random_uuid(), name text not null, category text not null default 'Foundation',
 description text not null default '', subjects text not null default '', duration text not null default '',
 image_url text not null default '', accent text not null default 'purple' check(accent in ('purple','orange','green','blue')),
 active boolean not null default true, created_at timestamptz not null default now()
);
insert into public.batches(name,category,description,subjects,duration,accent) values
 ('NEET Achievers','NEET','A focused path to your medical dream. Learn concepts deeply and practise with purpose.','Physics · Chemistry · Biology','Class 11 & 12','green'),
 ('JEE Trailblazers','JEE','Build strong fundamentals. Develop the problem-solving confidence to go further.','Physics · Chemistry · Mathematics','Class 11 & 12','purple'),
 ('Foundation Plus','Foundation','Big achievements begin with strong foundations. Get a head start on your goals.','Science · Mathematics · Aptitude','Class 9 & 10','orange');
create table public.enrollments (
 student_id uuid not null references public.profiles on delete cascade,
 batch_id uuid not null references public.batches on delete cascade,
 primary key(student_id,batch_id)
);
create table public.classes (
 id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.batches on delete cascade,
 subject text not null, title text not null, topic text not null default '', youtube_url text not null,
 pdf_url text not null default '', duration text not null default '', sort_order integer not null default 0,
 created_at timestamptz not null default now()
);
create table public.tests (
 id uuid primary key default gen_random_uuid(), title text not null, subject text not null default 'General',
 description text not null default '', duration_minutes integer not null default 30 check(duration_minutes between 1 and 300),
 marks_correct numeric not null default 4 check(marks_correct > 0 and marks_correct <= 100),
 marks_wrong numeric not null default 1 check(marks_wrong >= 0 and marks_wrong <= 100),
 published boolean not null default false, starts_at timestamptz, ends_at timestamptz,
 created_at timestamptz not null default now(), check(ends_at is null or starts_at is null or ends_at > starts_at)
);
-- This entire table is admin-only. Students never download answer keys.
create table public.questions (
 id uuid primary key default gen_random_uuid(), test_id uuid not null references public.tests on delete cascade,
 position integer not null check(position > 0), question text not null,
 options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options)=4),
 correct integer not null check(correct between 0 and 3), unique(test_id,position)
);
create table public.attempts (
 id uuid primary key default gen_random_uuid(), test_id uuid not null references public.tests,
 student_id uuid not null references public.profiles on delete cascade,
 started_at timestamptz not null default now(), deadline timestamptz not null,
 submitted_at timestamptz, answers jsonb not null default '{}',
 score numeric, right_count integer, wrong_count integer, skipped_count integer,
 unique(test_id,student_id)
);
create table private.papers (
 attempt_id uuid primary key references public.attempts on delete cascade,
 questions jsonb not null, marks_correct numeric not null, marks_wrong numeric not null
);

alter table public.profiles enable row level security;
alter table public.site_settings enable row level security;
alter table public.hero_slides enable row level security;
alter table public.batches enable row level security;
alter table public.enrollments enable row level security;
alter table public.classes enable row level security;
alter table public.tests enable row level security;
alter table public.questions enable row level security;
alter table public.attempts enable row level security;
alter table private.papers enable row level security;
create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());
create policy profiles_admin on public.profiles for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy settings_read on public.site_settings for select to anon,authenticated using(true);
create policy settings_admin on public.site_settings for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy slides_read on public.hero_slides for select to anon,authenticated using(active or public.is_admin());
create policy slides_admin on public.hero_slides for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy batches_read on public.batches for select to anon,authenticated using(active or public.is_admin());
create policy batches_admin on public.batches for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy enrollments_read on public.enrollments for select to authenticated using((student_id=auth.uid() and public.is_verified()) or public.is_admin());
create policy enrollments_admin on public.enrollments for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy classes_read on public.classes for select to authenticated using(public.is_admin() or (public.is_verified() and exists(select 1 from public.enrollments e where e.student_id=auth.uid() and e.batch_id=classes.batch_id)));
create policy classes_admin on public.classes for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy tests_read on public.tests for select to anon,authenticated using(published or public.is_admin());
create policy tests_admin on public.tests for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy questions_admin on public.questions for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy attempts_read on public.attempts for select to authenticated using(public.is_admin() or (student_id=auth.uid() and public.is_verified()));
-- No client INSERT/UPDATE/DELETE policy on attempts. Only RPCs may mutate them.

create function public.save_test(p_test jsonb, p_questions jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare tid uuid; q jsonb; pos integer := 0;
begin
 if not public.is_admin() then raise exception 'Administrator access required'; end if;
 if jsonb_typeof(p_questions) <> 'array' or jsonb_array_length(p_questions) not between 1 and 200 then raise exception 'Add 1 to 200 reviewed questions'; end if;
 tid := coalesce(nullif(p_test->>'id','')::uuid,gen_random_uuid());
 -- Serialize publication and attempts; an in-use test is immutable.
 perform pg_advisory_xact_lock(hashtextextended(tid::text,0));
 if exists(select 1 from public.attempts where test_id=tid) then raise exception 'Students have attempted this test. Create a new test instead.'; end if;
 insert into public.tests(id,title,subject,description,duration_minutes,marks_correct,marks_wrong,published,starts_at,ends_at)
 values(tid,p_test->>'title',p_test->>'subject',coalesce(p_test->>'description',''),(p_test->>'duration_minutes')::int,
 (p_test->>'marks_correct')::numeric,(p_test->>'marks_wrong')::numeric,coalesce((p_test->>'published')::boolean,false),nullif(p_test->>'starts_at','')::timestamptz,nullif(p_test->>'ends_at','')::timestamptz)
 on conflict(id) do update set title=excluded.title,subject=excluded.subject,description=excluded.description,duration_minutes=excluded.duration_minutes,
 marks_correct=excluded.marks_correct,marks_wrong=excluded.marks_wrong,published=excluded.published,starts_at=excluded.starts_at,ends_at=excluded.ends_at;
 delete from public.questions where test_id=tid;
 for q in select value from jsonb_array_elements(p_questions) loop
  pos := pos+1;
  if length(trim(q->>'question'))=0 or q->>'correct' is null or exists(select 1 from jsonb_array_elements_text(q->'options') o where length(trim(o))=0) then raise exception 'Each question needs text, four options and an answer'; end if;
  insert into public.questions(test_id,position,question,options,correct) values(tid,pos,q->>'question',q->'options',(q->>'correct')::int);
 end loop;
 return tid;
end;
$$;

create function private.finish_attempt(aid uuid) returns void language plpgsql security definer set search_path = '' as $$
declare a public.attempts; paper private.papers; q jsonb; answer text; r int:=0; w int:=0; s int:=0;
begin
 select * into a from public.attempts where id=aid for update;
 if not found or a.submitted_at is not null then return; end if;
 select * into paper from private.papers where attempt_id=aid;
 for q in select value from jsonb_array_elements(paper.questions) loop
  answer:=a.answers->>(q->>'id');
  if answer is null then s:=s+1;
  elsif answer::int=(q->>'correct')::int then r:=r+1;
  else w:=w+1; end if;
 end loop;
 update public.attempts set submitted_at=least(now(),deadline),right_count=r,wrong_count=w,skipped_count=s,score=r*paper.marks_correct-w*paper.marks_wrong where id=aid;
end;
$$;
create function public.start_test(p_test_id uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare t public.tests; a public.attempts; qs jsonb;
begin
 if not public.is_verified() then raise exception 'Your account is awaiting administrator approval'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_test_id::text,0));
 select * into a from public.attempts where test_id=p_test_id and student_id=auth.uid();
 if found then
  if a.submitted_at is null and now()>=a.deadline then perform private.finish_attempt(a.id); select * into a from public.attempts where id=a.id; end if;
  return to_jsonb(a)||jsonb_build_object('server_now',now());
 end if;
 select * into t from public.tests where id=p_test_id and published;
 if not found then raise exception 'Test is not available'; end if;
 if t.starts_at is not null and now()<t.starts_at then raise exception 'This test has not started yet'; end if;
 if t.ends_at is not null and now()>=t.ends_at then raise exception 'This test has closed'; end if;
 select jsonb_agg(to_jsonb(q) order by q.position) into qs from public.questions q where test_id=p_test_id;
 if qs is null then raise exception 'No questions have been published'; end if;
 insert into public.attempts(test_id,student_id,deadline) values(p_test_id,auth.uid(),least(now()+make_interval(mins=>t.duration_minutes),coalesce(t.ends_at,'infinity'::timestamptz))) returning * into a;
 insert into private.papers(attempt_id,questions,marks_correct,marks_wrong) values(a.id,qs,t.marks_correct,t.marks_wrong);
 return to_jsonb(a)||jsonb_build_object('server_now',now());
end;
$$;
create function public.get_paper(p_attempt_id uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare a public.attempts; result jsonb;
begin
 if not public.is_verified() then raise exception 'Approval required'; end if;
 select * into a from public.attempts where id=p_attempt_id and student_id=auth.uid();
 if not found then raise exception 'Attempt not found'; end if;
 if a.submitted_at is not null or now()>=a.deadline then raise exception 'Attempt has ended'; end if;
 select jsonb_agg(q - 'correct') into result from private.papers p cross join lateral jsonb_array_elements(p.questions) q where p.attempt_id=a.id;
 return result;
end;
$$;
create function public.save_answer(p_attempt_id uuid,p_question_id uuid,p_option integer) returns void language plpgsql security definer set search_path = '' as $$
declare a public.attempts;
begin
 if not public.is_verified() then raise exception 'Approval required'; end if;
 select * into a from public.attempts where id=p_attempt_id and student_id=auth.uid() for update;
 if not found then raise exception 'Attempt not found'; end if;
 if a.submitted_at is not null or now()>=a.deadline then raise exception 'Time has ended. Submit your test.'; end if;
 if p_option is not null and p_option not between 0 and 3 then raise exception 'Invalid option'; end if;
 if not exists(select 1 from private.papers p cross join lateral jsonb_array_elements(p.questions) q where p.attempt_id=a.id and q->>'id'=p_question_id::text) then raise exception 'Invalid question'; end if;
 update public.attempts set answers=case when p_option is null then answers-p_question_id::text else jsonb_set(answers,array[p_question_id::text],to_jsonb(p_option)) end where id=a.id;
end;
$$;
create function public.submit_test(p_attempt_id uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare a public.attempts;
begin
 if not public.is_verified() then raise exception 'Approval required'; end if;
 if not exists(select 1 from public.attempts where id=p_attempt_id and student_id=auth.uid()) then raise exception 'Attempt not found'; end if;
 perform private.finish_attempt(p_attempt_id);
 select * into a from public.attempts where id=p_attempt_id;
 return to_jsonb(a);
end;
$$;
create function public.leaderboard(p_test_id uuid) returns table(rank bigint,full_name text,username text,score numeric,right_count integer,wrong_count integer,skipped_count integer,student_id uuid)
language plpgsql security definer set search_path = '' as $$
declare aid uuid;
begin
 if not public.is_verified() then raise exception 'Login with an approved account to view rankings'; end if;
 for aid in select a.id from public.attempts a where a.test_id=p_test_id and a.submitted_at is null and a.deadline<=now() order by a.id loop
  perform private.finish_attempt(aid);
 end loop;
 return query select row_number() over(order by a.score desc,a.right_count desc,(a.submitted_at-a.started_at) asc,a.id),p.full_name,p.username,a.score,a.right_count,a.wrong_count,a.skipped_count,a.student_id
 from public.attempts a join public.profiles p on p.id=a.student_id where a.test_id=p_test_id and a.submitted_at is not null and p.role='student' and p.verified
 order by a.score desc,a.right_count desc,(a.submitted_at-a.started_at) asc,a.id;
end;
$$;

-- Explicit grants: no role/password data can be changed by students.
grant usage on schema public to anon,authenticated;
grant select on public.site_settings,public.hero_slides,public.batches,public.tests to anon;
grant select,insert,update,delete on public.site_settings,public.hero_slides,public.batches,public.tests,public.questions,public.enrollments,public.classes to authenticated;
grant select,update on public.profiles to authenticated;
grant select on public.attempts to authenticated;
revoke all on all functions in schema private from public,anon,authenticated;
revoke all on function public.handle_new_user() from public,anon,authenticated;
revoke all on function public.is_admin(),public.is_verified() from public,anon,authenticated;
grant execute on function public.is_admin(),public.is_verified() to anon,authenticated;
revoke all on function public.save_test(jsonb,jsonb),public.start_test(uuid),public.get_paper(uuid),public.save_answer(uuid,uuid,integer),public.submit_test(uuid),public.leaderboard(uuid) from public,anon;
grant execute on function public.save_test(jsonb,jsonb),public.start_test(uuid),public.get_paper(uuid),public.save_answer(uuid,uuid,integer),public.submit_test(uuid),public.leaderboard(uuid) to authenticated;

-- Uploaded source PDFs are private and admin-only. Classes accept your PDF URLs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('admin-pdfs','admin-pdfs',false,10485760,array['application/pdf']) on conflict(id) do nothing;
create policy admin_pdf_all on storage.objects for all to authenticated using(bucket_id='admin-pdfs' and public.is_admin()) with check(bucket_id='admin-pdfs' and public.is_admin());
commit;

-- NEXT: create your admin in Authentication > Users > Add user, then run the
-- separate supabase/create-admin.sql with the email you actually created.
