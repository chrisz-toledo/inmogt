-- ============================================================================
-- INMOGUATE PRO V13 - ESQUEMA POSTGRESQL MULTI-EMPRESA Y MULTI-USUARIO (SUPABASE)
-- Licencia Socio Fundador 10 Años Gratis (2026 - 2036) + Multi-Tenant + RLS
-- ============================================================================
-- INSTRUCCIONES:
-- 1. Entra a https://supabase.com y abre tu proyecto gratuito.
-- 2. Ve a "SQL Editor" -> "New Query".
-- 3. Pega todo este archivo y haz clic en "Run".
-- ============================================================================

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

alter table public.inmoguate_tenants enable row level security;
alter table public.inmoguate_users enable row level security;

drop policy if exists "Acceso multi-tenant inmoguate_tenants" on public.inmoguate_tenants;
create policy "Acceso multi-tenant inmoguate_tenants"
  on public.inmoguate_tenants
  for all
  using (true)
  with check (true);

drop policy if exists "Acceso multi-usuario inmoguate_users" on public.inmoguate_users;
create policy "Acceso multi-usuario inmoguate_users"
  on public.inmoguate_users
  for all
  using (true)
  with check (true);

-- Insertar las 4 cuentas iniciales (Amigo Socio Fundador 10 Años Gratis + 2 Clientes SaaS + Master)
insert into public.inmoguate_tenants (tenant_id, business_name, plan_name, valid_until, users)
values
  ('friend_founder', 'Inmobiliaria & Lotes Mi Amigo (Socio Fundador)', 'Licencia Fundador 10 Años Gratis (2026-2036)', '2036-10-18',
   '[{"id":"u_owner","name":"Socio Titular (Dueño)","role":"admin","pin":"1234"},{"id":"u_office","name":"Andrea Morales (Oficina / Caja)","role":"office","pin":"2222"},{"id":"u_collector","name":"Jorge Méndez (Cobrador de Campo)","role":"collector","pin":"3333"}]'::jsonb),
  ('client_pro_1', 'Lotificadora Los Altos S.A.', 'Plan Pro Multi-Proyecto (Q 650/mes)', '2027-10-18',
   '[{"id":"u_c1_admin","name":"Gerente General · Los Altos","role":"admin","pin":"1234"},{"id":"u_c1_sec","name":"Secretaría de Cobros · Los Altos","role":"office","pin":"2222"},{"id":"u_c1_col","name":"Vendedor de Terrenos · Los Altos","role":"collector","pin":"3333"}]'::jsonb),
  ('client_pro_2', 'Desarrollos del Sur GT', 'Plan Pro Multi-Proyecto (Q 650/mes)', '2027-10-18',
   '[{"id":"u_c2_admin","name":"Director · Desarrollos del Sur","role":"admin","pin":"1234"},{"id":"u_c2_sec","name":"Caja Central · Desarrollos del Sur","role":"office","pin":"2222"},{"id":"u_c2_col","name":"Inspector / Cobrador · Sur GT","role":"collector","pin":"3333"}]'::jsonb),
  ('default', 'Cartera Master · Christian Toledo', 'Licencia Master Desarrollador (Ilimitada)', '2099-12-31',
   '[{"id":"u_master_1","name":"Christian Toledo (SuperAdmin)","role":"admin","pin":"1234"},{"id":"u_master_2","name":"Operador Oficina","role":"office","pin":"2222"},{"id":"u_master_3","name":"Operador Campo","role":"collector","pin":"3333"}]'::jsonb)
on conflict (tenant_id) do nothing;
