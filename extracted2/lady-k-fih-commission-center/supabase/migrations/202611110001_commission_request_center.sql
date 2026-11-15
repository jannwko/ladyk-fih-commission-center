-- Independent schema for Lady K ★ Fih Commission Request Center.
-- Does not alter portfolio tables or policies.
create extension if not exists pgcrypto with schema extensions;
create schema if not exists commission_private;

create table if not exists public.commission_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.commission_tos_versions (
  version text primary key,
  source_url text not null,
  exact_content text not null,
  content_sha256 text not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
create table if not exists public.commission_requests (
  id uuid primary key default gen_random_uuid(),
  request_number bigint generated always as identity unique,
  status text not null default 'New' check (status in ('New','Under review','Awaiting client','Accepted','Declined','Completed','Archived')),
  name text not null,
  email text not null,
  discord text not null,
  project text not null,
  form_data jsonb not null,
  terms_version text not null references public.commission_tos_versions(version),
  terms_content text not null,
  terms_accepted boolean not null check (terms_accepted = true),
  terms_accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.commission_quotes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.commission_requests(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'USD' check (currency = 'USD'),
  scope text not null,
  delivery text,
  notes text,
  expires_at date,
  token_hash text not null unique,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create table if not exists public.commission_email_logs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.commission_requests(id) on delete set null,
  quote_id uuid references public.commission_quotes(id) on delete set null,
  kind text not null,
  recipient text not null,
  status text not null check (status in ('sent','failed')),
  provider_id text,
  error text,
  created_at timestamptz not null default now()
);
create table if not exists public.commission_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
insert into public.commission_settings(key,value) values
 ('notification_recipient',''),('resend_from','') on conflict(key) do nothing;

create or replace function commission_private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.commission_admins a where a.user_id = auth.uid());
$$;
revoke all on function commission_private.is_admin() from public;
grant usage on schema commission_private to authenticated;
grant execute on function commission_private.is_admin() to authenticated;

alter table public.commission_admins enable row level security;
alter table public.commission_tos_versions enable row level security;
alter table public.commission_requests enable row level security;
alter table public.commission_quotes enable row level security;
alter table public.commission_email_logs enable row level security;
alter table public.commission_settings enable row level security;
create policy "Admins can read admin membership" on public.commission_admins for select to authenticated using (commission_private.is_admin());
create policy "Admins manage ToS versions" on public.commission_tos_versions for select to authenticated using (commission_private.is_admin());
create policy "Admins read requests" on public.commission_requests for select to authenticated using (commission_private.is_admin());
create policy "Admins update requests" on public.commission_requests for update to authenticated using (commission_private.is_admin()) with check (commission_private.is_admin());
create policy "Admins read quotations" on public.commission_quotes for select to authenticated using (commission_private.is_admin());
create policy "Admins read email logs" on public.commission_email_logs for select to authenticated using (commission_private.is_admin());
create policy "Admins read settings" on public.commission_settings for select to authenticated using (commission_private.is_admin());
create policy "Admins update settings" on public.commission_settings for update to authenticated using (commission_private.is_admin()) with check (commission_private.is_admin());
revoke all on public.commission_requests,public.commission_quotes,public.commission_email_logs,public.commission_tos_versions,public.commission_settings,public.commission_admins from anon, public;
grant select,update on public.commission_requests to authenticated;
grant select on public.commission_quotes,public.commission_email_logs,public.commission_tos_versions,public.commission_admins to authenticated;
grant select,update on public.commission_settings to authenticated;

create or replace function public.commission_touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists commission_requests_updated_at on public.commission_requests;
create trigger commission_requests_updated_at before update on public.commission_requests for each row execute function public.commission_touch_updated_at();

-- Accepted terms text/version is immutable; historical client acceptance must never be rewritten.
create or replace function public.commission_protect_acceptance()
returns trigger language plpgsql as $$ begin
 if new.terms_version is distinct from old.terms_version or new.terms_content is distinct from old.terms_content or new.terms_accepted_at is distinct from old.terms_accepted_at or new.email is distinct from old.email or new.discord is distinct from old.discord then
   raise exception 'Terms acceptance records and identity fields are immutable';
 end if; return new; end; $$;
drop trigger if exists commission_acceptance_immutable on public.commission_requests;
create trigger commission_acceptance_immutable before update on public.commission_requests for each row execute function public.commission_protect_acceptance();
create or replace function public.commission_protect_tos()
returns trigger language plpgsql as $$ begin raise exception 'Terms versions are immutable'; end; $$;
drop trigger if exists commission_tos_immutable on public.commission_tos_versions;
create trigger commission_tos_immutable before update or delete on public.commission_tos_versions for each row execute function public.commission_protect_tos();

-- Private bucket for client reference images. Public clients cannot list or download objects.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('commission-references','commission-references',false,5242880,array['image/png','image/jpeg','image/gif','image/webp'])
on conflict (id) do nothing;
create policy "Admins can view private commission references" on storage.objects for select to authenticated
using (bucket_id='commission-references' and commission_private.is_admin());
