-- ============================================================================
-- INMOGUATE PRO V13.1 - ESQUEMA POSTGRESQL CON AUTH REAL (SUPABASE AUTH + RLS)
-- Aislamiento real por tenant: solo miembros autenticados leen/escriben su tenant.
-- La anon key es pública por diseño; con este RLS es segura aunque se filtre.
-- ============================================================================
-- INSTRUCCIONES:
-- 1. Entra a https://supabase.com y abre tu proyecto.
-- 2. Ve a "SQL Editor" -> "New Query".
-- 3. Pega todo este archivo y haz clic en "Run".
-- 4. En Authentication -> Users, crea un usuario (email + password) por cada
--    persona que usará la app (dueño, oficina, cobrador).
-- 5. Vincula cada usuario a su tenant (ver EJEMPLO al final de este archivo).
-- 6. En la app: pestaña Nube Supabase -> pega URL + Anon Key -> Iniciar sesión.
-- ============================================================================

-- 1) TABLAS BASE (igual que v1: el negocio vive en payload jsonb por tenant)
create table if not exists public.inmoguate_tenants (
  tenant_id text primary key,
  business_name text not null,
  plan_name text not null default 'Licencia Fundador 10 Años Gratis (2026-2036)',
  valid_until date not null default '2036-10-18',
  users jsonb not null default '[]'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.inmoguate_users (
  user_id text primary key,
  tenant_id text not null references public.inmoguate_tenants(tenant_id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('admin', 'office', 'collector')),
  phone text,
  pin_code text not null default '1234',
  created_at timestamptz not null default now()
);

-- 2) MEMBRESÍAS: qué usuario de Supabase Auth pertenece a qué tenant.
--    Esta tabla es la que hace real el aislamiento multi-tenant.
create table if not exists public.inmoguate_members (
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id text not null references public.inmoguate_tenants(tenant_id) on delete cascade,
  role text not null check (role in ('admin', 'office', 'collector')),
  created_at timestamptz not null default now(),
  primary key (user_id, tenant_id)
);

-- 3) HELPERS (security definer para evitar recursión en las policies)
create or replace function public.is_tenant_member(p_tenant text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.inmoguate_members m
    where m.tenant_id = p_tenant and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_tenant_admin(p_tenant text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.inmoguate_members m
    where m.tenant_id = p_tenant and m.user_id = auth.uid() and m.role = 'admin'
  );
$$;

-- 4) RLS REAL: sin sesión válida, auth.uid() es NULL y todo se deniega.
alter table public.inmoguate_tenants enable row level security;
alter table public.inmoguate_users enable row level security;
alter table public.inmoguate_members enable row level security;

-- Limpiar policies permisivas de v1 si existen
drop policy if exists "Acceso multi-tenant inmoguate_tenants" on public.inmoguate_tenants;
drop policy if exists "Acceso multi-usuario inmoguate_users" on public.inmoguate_users;
drop policy if exists "Permitir lectura y escritura por tenant_id" on public.inmoguate_tenants;

-- Tenants: solo miembros de ese tenant (lectura y escritura)
drop policy if exists "tenant_isolation" on public.inmoguate_tenants;
create policy "tenant_isolation"
  on public.inmoguate_tenants
  for all
  using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

-- Users (operadores locales): mismo aislamiento que su tenant
drop policy if exists "tenant_user_isolation" on public.inmoguate_users;
create policy "tenant_user_isolation"
  on public.inmoguate_users
  for all
  using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

-- Members: cada usuario ve sus propias membresías
drop policy if exists "own_memberships_read" on public.inmoguate_members;
create policy "own_memberships_read"
  on public.inmoguate_members
  for select
  using (user_id = auth.uid());

-- Members: solo admins del tenant gestionan membresías de su tenant
drop policy if exists "admin_manage_memberships" on public.inmoguate_members;
create policy "admin_manage_memberships"
  on public.inmoguate_members
  for all
  using (public.is_tenant_admin(tenant_id))
  with check (public.is_tenant_admin(tenant_id));

-- 5) SEEDS: tenants sin PINs por defecto.
--    Los PINs de operador se crean en la app al primer uso (desbloqueo local
--    del dispositivo, NO credencial del servidor).
insert into public.inmoguate_tenants (tenant_id, business_name, plan_name, valid_until, users)
values
  ('friend_founder', 'Inmobiliaria & Lotes Mi Amigo (Socio Fundador)', 'Licencia Fundador 10 Años Gratis (2026-2036)', '2036-10-18', '[]'::jsonb),
  ('client_pro_1', 'Lotificadora Los Altos S.A.', 'Plan Pro Multi-Proyecto (Q 650/mes)', '2027-10-18', '[]'::jsonb),
  ('client_pro_2', 'Desarrollos del Sur GT', 'Plan Pro Multi-Proyecto (Q 650/mes)', '2027-10-18', '[]'::jsonb),
  ('default', 'Cartera Master · Christian Toledo', 'Licencia Master Desarrollador (Ilimitada)', '2099-12-31', '[]'::jsonb)
on conflict (tenant_id) do nothing;

-- ============================================================================
-- EJEMPLO: vincular un usuario de Auth a un tenant (reemplaza los valores)
-- 1. Crea el usuario en Authentication -> Users y copia su UUID.
-- 2. Corre:
--
-- insert into public.inmoguate_members (user_id, tenant_id, role)
-- values ('PEGAR-UUID-DEL-USUARIO', 'client_pro_1', 'admin')
-- on conflict do nothing;
--
-- Roles: 'admin' (gestiona usuarios del tenant), 'office', 'collector'.
-- ============================================================================
