# 🇬🇹 InmoGuate Pro V13.1 — Paquete Oficial de Producción

Incluye:
- `index.html`: Aplicación completa en modo profesional (Multi-Empresa + Multi-Usuario + Licencia de 10 Años Gratis 2026–2036). **V13.1: la nube exige login con Supabase Auth (JWT); el PIN queda como desbloqueo local del dispositivo.**
- `supabase_schema.sql`: Script SQL v2 — tablas `inmoguate_tenants`, `inmoguate_users` y `inmoguate_members`, con RLS real por membresía (`auth.uid()`). Sin este schema, la app no sincroniza.
- `supabase_migrate_v1_to_v2.sql`: Migración para proyectos donde ya se corrió el schema v1 (elimina el RLS permisivo `using(true)`).
- `.github/workflows/deploy.yml`: Publicación automática en GitHub Pages.
- `netlify.toml` y `vercel.json`: Configuración lista para arrastrar y soltar en Netlify Drop o Vercel.
- `deploy_github.sh`: Script de 1 comando para publicar desde tu terminal.

## ☁️ Configurar la nube (Supabase) — obligatorio para sincronizar

1. Crea un proyecto gratis en [supabase.com](https://supabase.com).
2. En **SQL Editor → New Query**, pega todo `supabase_schema.sql` y corre **Run**.
   (Si ya habías corrido el schema v1, corre después `supabase_migrate_v1_to_v2.sql`.)
3. En **Authentication → Users**, crea un usuario (email + contraseña) por cada persona
   que usará la app (dueño, oficina, cobrador).
4. Vincula cada usuario a su empresa (reemplaza los valores):
   ```sql
   insert into public.inmoguate_members (user_id, tenant_id, role)
   values ('PEGAR-UUID-DEL-USUARIO', 'client_pro_1', 'admin')
   on conflict do nothing;
   ```
   Roles: `admin` (gestiona usuarios de su empresa), `office`, `collector`.
5. En la app, pestaña **Nube Supabase**: pega la Project URL + Anon Key e **inicia sesión**
   con el email y contraseña del paso 3.

**Modelo de seguridad:** la anon key es pública por diseño — con el RLS v2 es segura
aunque se filtre, porque cada request va firmada con el JWT del usuario y el servidor
solo permite ver la(s) empresa(s) asignada(s) a ese usuario. Sin sesión, no hay
lectura ni escritura. El PIN de operador es solo desbloqueo rápido del dispositivo.
