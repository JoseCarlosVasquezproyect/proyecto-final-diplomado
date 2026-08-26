-- ============================================================
-- PROYECTO FINAL 360 · ESQUEMA DE AULA
-- Ejecutar en Supabase > SQL Editor.
-- Cada usuario autenticado verá solamente sus propios registros.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.registros_demo (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  titulo text not null check (char_length(titulo) between 3 and 80),
  descripcion text not null default '',
  estado text not null default 'activo' check (estado in ('pendiente','activo','cerrado')),
  created_at timestamptz not null default now()
);

alter table public.registros_demo enable row level security;

drop policy if exists "registros_select_propios" on public.registros_demo;
create policy "registros_select_propios"
on public.registros_demo for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "registros_insert_propios" on public.registros_demo;
create policy "registros_insert_propios"
on public.registros_demo for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "registros_update_propios" on public.registros_demo;
create policy "registros_update_propios"
on public.registros_demo for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "registros_delete_propios" on public.registros_demo;
create policy "registros_delete_propios"
on public.registros_demo for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on table public.registros_demo to authenticated;

-- Verificación rápida del esquema:
select table_name from information_schema.tables
where table_schema = 'public' and table_name = 'registros_demo';
