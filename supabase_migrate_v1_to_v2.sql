-- ============================================================================
-- MIGRACIÓN v1 -> v2: de RLS permisivo (using(true)) a AUTH REAL por membresía
-- Para proyectos donde ya se ejecutó el schema v1 de InmoGuate Pro V13.
-- 1. Pega este archivo en el SQL Editor DESPUÉS de haber corrido el schema v2
--    (o córrelo solo: incluye todo lo necesario).
-- 2. Crea los usuarios en Authentication -> Users y vincúlalos (ver EJEMPLO
--    al final del schema v2).
-- NOTA: los PINs por defecto (1234/2222/3333) de los seeds v1 quedan solo como
-- desbloqueo local del dispositivo; la nube ahora exige sesión de Supabase Auth.
-- ============================================================================

-- Tabla de membresías (si el schema v2 ya corrió, no hace nada)
create table if not exists public.inmoguate_members (
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id text not null references public.inmoguate_tenants(tenant_id) on delete cascade,
  role text not null check (role in ('admin', 'office', 'collector')),
  created_at timestamptz not null default now(),
  primary key (user_id, tenant_id)
);

create or replace function public.is_tenant_member(p_tenant text)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.inmoguate_members m
    where m.tenant_id = p_tenant and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_tenant_admin(p_tenant text)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.inmoguate_members m
    where m.tenant_id = p_tenant and m.user_id = auth.uid() and m.role = 'admin'
  );
$$;

alter table public.inmoguate_tenants enable row level security;
alter table public.inmoguate_users enable row level security;
alter table public.inmoguate_members enable row level security;

-- Eliminar policies permisivas v1
drop policy if exists "Acceso multi-tenant inmoguate_tenants" on public.inmoguate_tenants;
drop policy if exists "Acceso multi-usuario inmoguate_users" on public.inmoguate_users;
drop policy if exists "Permitir lectura y escritura por tenant_id" on public.inmoguate_tenants;

-- Policies reales v2
drop policy if exists "tenant_isolation" on public.inmoguate_tenants;
create policy "tenant_isolation"
  on public.inmoguate_tenants for all
  using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

drop policy if exists "tenant_user_isolation" on public.inmoguate_users;
create policy "tenant_user_isolation"
  on public.inmoguate_users for all
  using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

drop policy if exists "own_memberships_read" on public.inmoguate_members;
create policy "own_memberships_read"
  on public.inmoguate_members for select
  using (user_id = auth.uid());

drop policy if exists "admin_manage_memberships" on public.inmoguate_members;
create policy "admin_manage_memberships"
  on public.inmoguate_members for all
  using (public.is_tenant_admin(tenant_id))
  with check (public.is_tenant_admin(tenant_id));
