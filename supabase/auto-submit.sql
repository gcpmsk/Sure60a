-- Run AFTER schema.sql, using the SQL Editor's postgres role.
-- Finalizes expired attempts even when every student has closed the browser.
-- Saved answers are graded at the original deadline, not at the cron run time.
-- Online tests submit immediately; this job finalizes offline attempts within
-- approximately one minute (subject to your database/cron availability).

create extension if not exists pg_cron with schema pg_catalog;

create or replace function private.finalize_expired_attempts()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  aid uuid;
  total integer := 0;
begin
  for aid in
    select id from public.attempts
    where submitted_at is null and deadline <= now()
    order by id
    limit 1000
  loop
    perform private.finish_attempt(aid);
    total := total + 1;
  end loop;
  return total;
end;
$$;
revoke all on function private.finalize_expired_attempts() from public, anon, authenticated;

create index if not exists attempts_expiry_idx
  on public.attempts(deadline) where submitted_at is null;
create index if not exists classes_batch_idx on public.classes(batch_id);
create index if not exists attempts_student_idx on public.attempts(student_id);

-- The named schedule is updated, rather than duplicated, when run again.
select cron.schedule(
  'sure60-expired-tests',
  '* * * * *',
  'select private.finalize_expired_attempts();'
);

select jobid, jobname, schedule, active
from cron.job where jobname = 'sure60-expired-tests';
