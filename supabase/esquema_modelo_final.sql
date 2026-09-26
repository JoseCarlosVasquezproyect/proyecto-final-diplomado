-- =========================================================
-- ESQUEMA FINAL DE BASE DE DATOS
-- Proyecto: Gestión de Personal y Turnos Hospitalarios
-- =========================================================
--
-- Este archivo documenta la estructura final del sistema.
-- Debe usarse como referencia para Flutter / Codex.
--
-- ENTIDADES PRINCIPALES:
-- 1. administradores
-- 2. especialidades
-- 3. personal
-- 4. turnos
-- 5. asignaciones_turno
-- 6. auditoria
--
-- Supabase Auth:
-- auth.users se utiliza para autenticación y NO se considera
-- una entidad de negocio del modelo.
--
-- =========================================================


-- =========================================================
-- RELACIONES GENERALES
-- =========================================================
--
-- auth.users.id
--      ├── administradores.user_id
--      └── personal.user_id
--
-- especialidades.id
--      └── personal.especialidad_id
--
-- personal.id
--      └── asignaciones_turno.personal_id
--
-- turnos.id
--      └── asignaciones_turno.turno_id
--
-- administradores.id
--      ├── especialidades.created_by
--      ├── especialidades.updated_by
--      ├── personal.created_by
--      ├── personal.updated_by
--      ├── turnos.created_by
--      ├── turnos.updated_by
--      ├── asignaciones_turno.created_by
--      ├── asignaciones_turno.updated_by
--      ├── asignaciones_turno.asistencia_marcada_por
--      └── auditoria.admin_id
--
-- =========================================================


-- =========================================================
-- 1. ADMINISTRADORES
-- =========================================================

CREATE TABLE public.administradores (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id uuid NOT NULL UNIQUE
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    nombre text NOT NULL
        CHECK (
            char_length(trim(nombre)) >= 2
            AND char_length(trim(nombre)) <= 80
        ),

    apellido text NOT NULL
        CHECK (
            char_length(trim(apellido)) >= 2
            AND char_length(trim(apellido)) <= 80
        ),

    estado text NOT NULL DEFAULT 'activo'
        CHECK (
            estado IN (
                'activo',
                'inactivo'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);


-- =========================================================
-- 2. ESPECIALIDADES
-- =========================================================

CREATE TABLE public.especialidades (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    nombre text NOT NULL UNIQUE
        CHECK (
            char_length(trim(nombre)) >= 2
            AND char_length(trim(nombre)) <= 100
        ),

    descripcion text NOT NULL DEFAULT '',

    estado text NOT NULL DEFAULT 'activo'
        CHECK (
            estado IN (
                'activo',
                'inactivo'
            )
        ),

    created_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    updated_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);


-- =========================================================
-- 3. PERSONAL
-- =========================================================

CREATE TABLE public.personal (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    codigo text NOT NULL UNIQUE
        CHECK (
            char_length(trim(codigo)) >= 2
            AND char_length(trim(codigo)) <= 30
        ),

    nombre text NOT NULL
        CHECK (
            char_length(trim(nombre)) >= 2
            AND char_length(trim(nombre)) <= 80
        ),

    apellido text NOT NULL
        CHECK (
            char_length(trim(apellido)) >= 2
            AND char_length(trim(apellido)) <= 80
        ),

    ci text UNIQUE,

    sexo text NOT NULL
        CHECK (
            sexo IN (
                'masculino',
                'femenino',
                'otro'
            )
        ),

    telefono text,

    tipo_personal text NOT NULL
        CHECK (
            tipo_personal IN (
                'medico',
                'enfermero',
                'pasante'
            )
        ),

    estado text NOT NULL DEFAULT 'activo'
        CHECK (
            estado IN (
                'activo',
                'inactivo',
                'suspendido'
            )
        ),

    user_id uuid
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    especialidad_id uuid
        REFERENCES public.especialidades(id)
        ON DELETE SET NULL,

    created_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    updated_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);


-- Una cuenta Auth solo puede corresponder a un registro de personal.
-- Se permite NULL mientras el personal aún no tenga cuenta creada.

CREATE UNIQUE INDEX uq_personal_user_id
ON public.personal(user_id)
WHERE user_id IS NOT NULL;


-- =========================================================
-- 4. TURNOS
-- =========================================================

CREATE TABLE public.turnos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fecha date NOT NULL,

    tipo text NOT NULL
        CHECK (
            tipo IN (
                'manana',
                'tarde',
                'noche',
                'personalizado'
            )
        ),

    hora_inicio time NOT NULL,
    hora_fin time NOT NULL,

    area text NOT NULL,

    estado text NOT NULL DEFAULT 'programado'
        CHECK (
            estado IN (
                'programado',
                'en_curso',
                'finalizado',
                'cancelado'
            )
        ),

    observaciones text NOT NULL DEFAULT '',

    created_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    updated_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT turnos_horas_distintas_check
        CHECK (hora_inicio <> hora_fin)
);

-- IMPORTANTE:
-- Si hora_fin < hora_inicio, el sistema interpreta que el turno
-- termina al día siguiente.
--
-- Ejemplo válido:
-- fecha:       2026-09-26
-- hora_inicio: 19:00
-- hora_fin:    07:00
--
-- El turno finaliza el 2026-09-27 a las 07:00.


-- =========================================================
-- 5. ASIGNACIONES_TURNO
-- =========================================================

CREATE TABLE public.asignaciones_turno (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    turno_id uuid NOT NULL
        REFERENCES public.turnos(id),

    personal_id uuid NOT NULL
        REFERENCES public.personal(id),

    rol_en_turno text NOT NULL
        CHECK (
            rol_en_turno IN (
                'medico',
                'enfermero',
                'pasante'
            )
        ),

    observaciones text NOT NULL DEFAULT '',

    estado_asistencia text NOT NULL DEFAULT 'pendiente'
        CHECK (
            estado_asistencia IN (
                'pendiente',
                'cumplido',
                'falta'
            )
        ),

    asistencia_marcada_por uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    asistencia_marcada_at timestamptz,

    created_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    updated_by uuid
        REFERENCES public.administradores(id)
        ON DELETE SET NULL,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT asignaciones_turno_turno_id_personal_id_key
        UNIQUE (turno_id, personal_id)
);


-- =========================================================
-- 6. AUDITORIA
-- =========================================================

CREATE TABLE public.auditoria (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    admin_id uuid
        REFERENCES public.administradores(id),

    accion text NOT NULL
        CHECK (
            accion IN (
                'INSERT',
                'UPDATE',
                'DELETE'
            )
        ),

    tabla_nombre text NOT NULL,

    registro_id uuid,

    descripcion text NOT NULL DEFAULT '',

    datos_anteriores jsonb,
    datos_nuevos jsonb,

    created_at timestamptz NOT NULL DEFAULT now()
);


-- =========================================================
-- FUNCIONES DE IDENTIFICACIÓN DE USUARIO
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


-- =========================================================
-- REGLA DE NEGOCIO:
-- EVITAR SOLAPAMIENTO DE TURNOS
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

    INTO
        nuevo_inicio,
        nuevo_fin

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


CREATE TRIGGER trg_validar_solapamiento_turno
BEFORE INSERT OR UPDATE OF turno_id, personal_id
ON public.asignaciones_turno
FOR EACH ROW
EXECUTE FUNCTION public.validar_solapamiento_turno();


-- =========================================================
-- RLS - RESUMEN DE AUTORIZACIÓN
-- =========================================================
--
-- ADMINISTRADOR:
--
-- administradores
--   SELECT
--   INSERT
--   UPDATE
--
-- especialidades
--   SELECT
--   INSERT
--   UPDATE
--
-- personal
--   SELECT
--   INSERT
--   UPDATE
--
-- turnos
--   SELECT
--   INSERT
--   UPDATE
--
-- asignaciones_turno
--   SELECT
--   INSERT
--   UPDATE
--
-- auditoria
--   SELECT
--
--
-- PERSONAL:
--
-- personal
--   SELECT solo donde user_id = auth.uid()
--
-- asignaciones_turno
--   SELECT solo donde personal_id = mi_personal_id()
--
-- turnos
--   SELECT solo los turnos asociados a sus asignaciones
--
-- especialidades
--   SELECT solo estado = 'activo'
--
-- administradores
--   sin acceso
--
-- auditoria
--   sin acceso
--
-- =========================================================


-- =========================================================
-- REGLAS IMPORTANTES PARA FLUTTER / CODEX
-- =========================================================
--
-- 1. NO utilizar las tablas antiguas:
--
--    medicos
--    enfermeros
--    pasantes
--    personal_dias_trabajo
--    emergencias
--    equipos_emergencia
--    equipo_emergencia_personal
--    registros_demo
--
-- Esas tablas ya no existen.
--
--
-- 2. Médico, enfermero y pasante NO son roles del sistema.
--
-- Existen únicamente dos perfiles:
--
--    Administrador
--    Personal
--
-- Médico/enfermero/pasante se determina mediante:
--
--    personal.tipo_personal
--
--
-- 3. AUTENTICACIÓN
--
-- Las contraseñas se administran exclusivamente mediante
-- Supabase Auth.
--
-- NUNCA crear una columna password en public.personal.
--
--
-- 4. DESPUÉS DEL LOGIN
--
-- Flutter debe determinar el perfil utilizando:
--
--    es_administrador()
--
-- Si devuelve true:
--
--    → Dashboard Administrador
--
-- De lo contrario:
--
--    es_personal()
--
-- Si devuelve true:
--
--    → Dashboard Personal
--
-- Si ambas devuelven false:
--
--    → usuario autenticado pero sin perfil autorizado.
--
--
-- 5. PANEL PERSONAL
--
-- El Personal solo debe visualizar:
--
--    - sus datos
--    - sus turnos
--
-- No debe crear, editar ni eliminar información administrativa.
--
--
-- 6. PANEL ADMINISTRADOR
--
-- El Administrador puede gestionar:
--
--    - especialidades
--    - personal
--    - turnos
--    - asignaciones
--    - asistencia
--
--
-- 7. ASISTENCIA
--
-- asignaciones_turno.estado_asistencia:
--
--    pendiente
--    cumplido
--    falta
--
-- La asistencia es registrada por el Administrador.
--
--
-- 8. BAJAS
--
-- No borrar físicamente Personal ni Turnos desde Flutter.
--
-- Personal:
--
--    estado = 'inactivo'
--
-- Turnos:
--
--    estado = 'cancelado'
--
-- De esta forma se conserva la trazabilidad.
--
--
-- 9. SOLAPAMIENTO
--
-- Una persona no puede tener dos turnos cuyos intervalos
-- horarios se crucen.
--
-- Esta regla se valida en PostgreSQL mediante:
--
--    validar_solapamiento_turno()
--
--
-- 10. TURNOS NOCTURNOS
--
-- Un turno como:
--
--    19:00 → 07:00
--
-- es válido y termina al día siguiente.
--
-- =========================================================