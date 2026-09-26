-- =========================================================
-- MODELO FINAL DE BASE DE DATOS
-- Proyecto: Gestión de Personal y Turnos Hospitalarios
-- Fecha: 2026-09-26
-- =========================================================

-- =========================================================
-- 1. PERSONAL: vinculación con Auth y especialidades
-- =========================================================

ALTER TABLE public.personal
ADD COLUMN IF NOT EXISTS user_id uuid;

ALTER TABLE public.personal
ADD COLUMN IF NOT EXISTS especialidad_id uuid;

ALTER TABLE public.personal
DROP CONSTRAINT IF EXISTS personal_user_id_fkey;

ALTER TABLE public.personal
ADD CONSTRAINT personal_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES auth.users(id)
ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_personal_user_id
ON public.personal(user_id)
WHERE user_id IS NOT NULL;

ALTER TABLE public.personal
DROP CONSTRAINT IF EXISTS personal_especialidad_id_fkey;

ALTER TABLE public.personal
ADD CONSTRAINT personal_especialidad_id_fkey
FOREIGN KEY (especialidad_id)
REFERENCES public.especialidades(id)
ON DELETE SET NULL;


-- =========================================================
-- 2. ASIGNACIONES: control de asistencia
-- =========================================================

ALTER TABLE public.asignaciones_turno
ADD COLUMN IF NOT EXISTS estado_asistencia text
NOT NULL DEFAULT 'pendiente';

ALTER TABLE public.asignaciones_turno
ADD COLUMN IF NOT EXISTS asistencia_marcada_por uuid;

ALTER TABLE public.asignaciones_turno
ADD COLUMN IF NOT EXISTS asistencia_marcada_at timestamptz;

ALTER TABLE public.asignaciones_turno
DROP CONSTRAINT IF EXISTS asignaciones_turno_estado_asistencia_check;

ALTER TABLE public.asignaciones_turno
ADD CONSTRAINT asignaciones_turno_estado_asistencia_check
CHECK (
    estado_asistencia IN (
        'pendiente',
        'cumplido',
        'falta'
    )
);

ALTER TABLE public.asignaciones_turno
DROP CONSTRAINT IF EXISTS asignaciones_turno_asistencia_marcada_por_fkey;

ALTER TABLE public.asignaciones_turno
ADD CONSTRAINT asignaciones_turno_asistencia_marcada_por_fkey
FOREIGN KEY (asistencia_marcada_por)
REFERENCES public.administradores(id)
ON DELETE SET NULL;


-- =========================================================
-- 3. EVITAR DUPLICADOS
-- =========================================================

-- La base ya tenía esta restricción.
-- Se conserva conceptualmente:
-- UNIQUE (turno_id, personal_id)


-- =========================================================
-- 4. VALIDAR SOLAPAMIENTO DE TURNOS
-- =========================================================

CREATE OR REPLACE FUNCTION public.validar_solapamiento_turno()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    nuevo_inicio timestamp;
    nuevo_fin timestamp;
    existe_conflicto boolean;
BEGIN

    SELECT
        t.fecha + t.hora_inicio,
        CASE
            WHEN t.hora_fin <= t.hora_inicio
                THEN (t.fecha + 1) + t.hora_fin
            ELSE
                t.fecha + t.hora_fin
        END
    INTO nuevo_inicio, nuevo_fin
    FROM public.turnos t
    WHERE t.id = NEW.turno_id;

    SELECT EXISTS (
        SELECT 1
        FROM public.asignaciones_turno a
        JOIN public.turnos t
            ON t.id = a.turno_id
        WHERE a.personal_id = NEW.personal_id
          AND a.id IS DISTINCT FROM NEW.id
          AND t.estado <> 'cancelado'
          AND (t.fecha + t.hora_inicio) < nuevo_fin
          AND (
              CASE
                  WHEN t.hora_fin <= t.hora_inicio
                      THEN (t.fecha + 1) + t.hora_fin
                  ELSE
                      t.fecha + t.hora_fin
              END
          ) > nuevo_inicio
    )
    INTO existe_conflicto;

    IF existe_conflicto THEN
        RAISE EXCEPTION
        'El personal ya posee otro turno que se solapa con el horario seleccionado.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_solapamiento_turno
ON public.asignaciones_turno;

CREATE TRIGGER trg_validar_solapamiento_turno
BEFORE INSERT OR UPDATE OF turno_id, personal_id
ON public.asignaciones_turno
FOR EACH ROW
EXECUTE FUNCTION public.validar_solapamiento_turno();


-- =========================================================
-- 5. TURNOS NOCTURNOS
-- =========================================================

ALTER TABLE public.turnos
DROP CONSTRAINT IF EXISTS turnos_check;

ALTER TABLE public.turnos
DROP CONSTRAINT IF EXISTS turnos_horas_distintas_check;

ALTER TABLE public.turnos
ADD CONSTRAINT turnos_horas_distintas_check
CHECK (hora_inicio <> hora_fin);


-- =========================================================
-- 6. FUNCIONES DE IDENTIFICACIÓN DE USUARIO
-- =========================================================

CREATE OR REPLACE FUNCTION public.es_administrador()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.administradores
        WHERE user_id = auth.uid()
          AND estado = 'activo'
    );
$$;

CREATE OR REPLACE FUNCTION public.es_personal()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.personal
        WHERE user_id = auth.uid()
          AND estado = 'activo'
    );
$$;

CREATE OR REPLACE FUNCTION public.mi_personal_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id
    FROM public.personal
    WHERE user_id = auth.uid()
      AND estado = 'activo'
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.es_administrador()
TO authenticated;

GRANT EXECUTE ON FUNCTION public.es_personal()
TO authenticated;

GRANT EXECUTE ON FUNCTION public.mi_personal_id()
TO authenticated;


-- =========================================================
-- 7. RLS PERSONAL
-- =========================================================

ALTER TABLE public.personal ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS personal_ver_datos_propios
ON public.personal;

CREATE POLICY personal_ver_datos_propios
ON public.personal
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
);


-- =========================================================
-- 8. RLS ASIGNACIONES
-- =========================================================

ALTER TABLE public.asignaciones_turno ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS asignaciones_personal_select
ON public.asignaciones_turno;

CREATE POLICY asignaciones_personal_select
ON public.asignaciones_turno
FOR SELECT
TO authenticated
USING (
    personal_id = public.mi_personal_id()
);


-- =========================================================
-- 9. RLS TURNOS
-- =========================================================

ALTER TABLE public.turnos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS turnos_personal_select
ON public.turnos;

CREATE POLICY turnos_personal_select
ON public.turnos
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.asignaciones_turno a
        WHERE a.turno_id = turnos.id
          AND a.personal_id = public.mi_personal_id()
    )
);

DROP POLICY IF EXISTS turnos_admin_update
ON public.turnos;

CREATE POLICY turnos_admin_update
ON public.turnos
FOR UPDATE
TO authenticated
USING (
    public.es_administrador()
)
WITH CHECK (
    public.es_administrador()
);


-- =========================================================
-- 10. RLS ESPECIALIDADES
-- =========================================================

ALTER TABLE public.especialidades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS especialidades_personal_select
ON public.especialidades;

CREATE POLICY especialidades_personal_select
ON public.especialidades
FOR SELECT
TO authenticated
USING (
    estado = 'activo'
);


-- =========================================================
-- 11. LIMPIEZA DE TABLAS ANTIGUAS
-- =========================================================

DROP TABLE IF EXISTS public.equipo_emergencia_personal;
DROP TABLE IF EXISTS public.equipos_emergencia;
DROP TABLE IF EXISTS public.emergencias;

DROP TABLE IF EXISTS public.medicos;
DROP TABLE IF EXISTS public.enfermeros;
DROP TABLE IF EXISTS public.pasantes;
DROP TABLE IF EXISTS public.personal_dias_trabajo;

DROP TABLE IF EXISTS public.registros_demo;


-- =========================================================
-- RESULTADO FINAL ESPERADO
-- =========================================================
-- Tablas principales:
-- administradores
-- especialidades
-- personal
-- turnos
-- asignaciones_turno
-- auditoria