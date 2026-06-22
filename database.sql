--
-- PostgreSQL database dump
--

\restrict e2Q4pWOUihFNXFbYofb5R4zlaH7GiPhMtgc39QN8LKTz0ZOuAvT6nU5rCgbXLwz

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: calcular_tarifa(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calcular_tarifa(p_id_registro integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_fecha_ent TIMESTAMP;
    v_tipo VARCHAR;
    v_horas INT;
    v_total NUMERIC;
BEGIN
    SELECT fecha_entrada, v.tipo_vehiculo INTO v_fecha_ent, v_tipo
    FROM registros_parqueo r
    JOIN vehiculos v ON r.placa = v.placa
    WHERE r.id_registro = p_id_registro;

   
    v_horas := CEIL(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_fecha_ent)) / 3600);
    
  
    IF v_tipo = 'Carro' THEN
        v_total := v_horas * 3000;
    ELSE
        v_total := v_horas * 1500;
    END IF;
    
    RETURN v_total;
END;
$$;


ALTER FUNCTION public.calcular_tarifa(p_id_registro integer) OWNER TO postgres;

--
-- Name: fn_tr_actualizar_estado(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_tr_actualizar_estado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.fecha_salida IS NOT NULL THEN
        NEW.estado := 'Finalizado';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_tr_actualizar_estado() OWNER TO postgres;

--
-- Name: fn_tr_auditoria_usuarios(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_tr_auditoria_usuarios() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO auditoria_usuarios(id_usuario, username, accion)
    VALUES (NEW.id_usuario, NEW.username, 'REGISTRO');
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_tr_auditoria_usuarios() OWNER TO postgres;

--
-- Name: fn_tr_placa_mayusculas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_tr_placa_mayusculas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.placa := UPPER(NEW.placa);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_tr_placa_mayusculas() OWNER TO postgres;

--
-- Name: fn_tr_prevenir_borrado(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_tr_prevenir_borrado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'No est  permitido eliminar registros hist¢ricos del parqueadero por auditor¡a';
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.fn_tr_prevenir_borrado() OWNER TO postgres;

--
-- Name: fn_tr_validar_vehiculo(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_tr_validar_vehiculo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM registros_parqueo WHERE placa = NEW.placa AND estado = 'Activo') THEN
        RAISE EXCEPTION 'El veh¡culo con placa % ya se encuentra dentro del parqueadero', NEW.placa;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_tr_validar_vehiculo() OWNER TO postgres;

--
-- Name: obtener_vehiculos_dentro(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.obtener_vehiculos_dentro() RETURNS TABLE(id_res integer, v_placa character varying, v_tipo character varying, f_entrada timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT r.id_registro, r.placa, v.tipo_vehiculo, r.fecha_entrada
    FROM registros_parqueo r
    JOIN vehiculos v ON r.placa = v.placa
    WHERE r.estado = 'Activo';
END;
$$;


ALTER FUNCTION public.obtener_vehiculos_dentro() OWNER TO postgres;

--
-- Name: registrar_entrada(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_entrada(p_placa character varying, p_tipo character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    
    INSERT INTO vehiculos (placa, tipo_vehiculo)
    VALUES (p_placa, p_tipo)
    ON CONFLICT (placa) DO NOTHING;

   
    INSERT INTO registros_parqueo (placa, fecha_entrada, estado)
    VALUES (p_placa, CURRENT_TIMESTAMP, 'Activo');
END;
$$;


ALTER FUNCTION public.registrar_entrada(p_placa character varying, p_tipo character varying) OWNER TO postgres;

--
-- Name: registrar_salida(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_salida(p_placa character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_reg INT;
    v_cobro NUMERIC;
BEGIN
    
    SELECT id_registro INTO v_id_reg 
    FROM registros_parqueo 
    WHERE placa = p_placa AND estado = 'Activo'
    LIMIT 1;

    IF v_id_reg IS NOT NULL THEN
        
        v_cobro := calcular_tarifa(v_id_reg);
        
        
        UPDATE registros_parqueo 
        SET fecha_salida = CURRENT_TIMESTAMP,
            valor_pagado = v_cobro
        WHERE id_registro = v_id_reg;
    END IF;
END;
$$;


ALTER FUNCTION public.registrar_salida(p_placa character varying) OWNER TO postgres;

--
-- Name: reporte_ingresos_diarios(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reporte_ingresos_diarios(p_fecha date) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_recaudo NUMERIC;
BEGIN
    SELECT COALESCE(SUM(valor_pagado), 0.00) INTO v_recaudo
    FROM registros_parqueo
    WHERE fecha_salida::DATE = p_fecha;
    
    RETURN v_recaudo;
END;
$$;


ALTER FUNCTION public.reporte_ingresos_diarios(p_fecha date) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria_usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auditoria_usuarios (
    id_auditoria integer NOT NULL,
    id_usuario integer,
    username character varying(50),
    accion character varying(20),
    fecha_accion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.auditoria_usuarios OWNER TO postgres;

--
-- Name: auditoria_usuarios_id_auditoria_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auditoria_usuarios_id_auditoria_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auditoria_usuarios_id_auditoria_seq OWNER TO postgres;

--
-- Name: auditoria_usuarios_id_auditoria_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auditoria_usuarios_id_auditoria_seq OWNED BY public.auditoria_usuarios.id_auditoria;


--
-- Name: registros_parqueo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.registros_parqueo (
    id_registro integer NOT NULL,
    placa character varying(10),
    fecha_entrada timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_salida timestamp without time zone,
    valor_pagado numeric(10,2) DEFAULT 0.00,
    estado character varying(10) DEFAULT 'Activo'::character varying,
    CONSTRAINT registros_parqueo_estado_check CHECK (((estado)::text = ANY ((ARRAY['Activo'::character varying, 'Finalizado'::character varying])::text[])))
);


ALTER TABLE public.registros_parqueo OWNER TO postgres;

--
-- Name: registros_parqueo_id_registro_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.registros_parqueo_id_registro_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.registros_parqueo_id_registro_seq OWNER TO postgres;

--
-- Name: registros_parqueo_id_registro_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.registros_parqueo_id_registro_seq OWNED BY public.registros_parqueo.id_registro;


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    rol character varying(20) NOT NULL,
    CONSTRAINT usuarios_rol_check CHECK (((rol)::text = ANY ((ARRAY['Administrador'::character varying, 'Operador'::character varying])::text[])))
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_id_usuario_seq OWNER TO postgres;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;


--
-- Name: vehiculos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehiculos (
    placa character varying(10) NOT NULL,
    tipo_vehiculo character varying(20) NOT NULL,
    propietario character varying(100),
    CONSTRAINT vehiculos_tipo_vehiculo_check CHECK (((tipo_vehiculo)::text = ANY ((ARRAY['Carro'::character varying, 'Moto'::character varying])::text[])))
);


ALTER TABLE public.vehiculos OWNER TO postgres;

--
-- Name: auditoria_usuarios id_auditoria; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria_usuarios ALTER COLUMN id_auditoria SET DEFAULT nextval('public.auditoria_usuarios_id_auditoria_seq'::regclass);


--
-- Name: registros_parqueo id_registro; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_parqueo ALTER COLUMN id_registro SET DEFAULT nextval('public.registros_parqueo_id_registro_seq'::regclass);


--
-- Name: usuarios id_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Data for Name: auditoria_usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auditoria_usuarios (id_auditoria, id_usuario, username, accion, fecha_accion) FROM stdin;
1	1	jaider solano	REGISTRO	2026-06-21 18:49:19.529418
2	2	junior 12	REGISTRO	2026-06-21 19:08:10.552396
\.


--
-- Data for Name: registros_parqueo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.registros_parqueo (id_registro, placa, fecha_entrada, fecha_salida, valor_pagado, estado) FROM stdin;
1	IFC69E	2026-06-21 19:07:00.1327	2026-06-21 19:07:08.30796	1500.00	Finalizado
5	POM897	2026-06-21 19:50:44.25539	2026-06-21 19:51:09.231147	3000.00	Finalizado
2	IFC69E	2026-06-21 19:07:20.066803	2026-06-21 19:52:17.163939	1500.00	Finalizado
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id_usuario, username, password_hash, rol) FROM stdin;
1	jaider solano	5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5	Operador
2	junior 12	5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5	Administrador
\.


--
-- Data for Name: vehiculos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vehiculos (placa, tipo_vehiculo, propietario) FROM stdin;
IFC69E	Moto	\N
POM897	Carro	\N
\.


--
-- Name: auditoria_usuarios_id_auditoria_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auditoria_usuarios_id_auditoria_seq', 2, true);


--
-- Name: registros_parqueo_id_registro_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.registros_parqueo_id_registro_seq', 5, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 3, true);


--
-- Name: auditoria_usuarios auditoria_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria_usuarios
    ADD CONSTRAINT auditoria_usuarios_pkey PRIMARY KEY (id_auditoria);


--
-- Name: registros_parqueo registros_parqueo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_parqueo
    ADD CONSTRAINT registros_parqueo_pkey PRIMARY KEY (id_registro);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: usuarios usuarios_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_username_key UNIQUE (username);


--
-- Name: vehiculos vehiculos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehiculos
    ADD CONSTRAINT vehiculos_pkey PRIMARY KEY (placa);


--
-- Name: registros_parqueo tg_actualizar_estado_salida; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_actualizar_estado_salida BEFORE UPDATE ON public.registros_parqueo FOR EACH ROW EXECUTE FUNCTION public.fn_tr_actualizar_estado();


--
-- Name: usuarios tg_auditoria_usuarios; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_auditoria_usuarios AFTER INSERT ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_tr_auditoria_usuarios();


--
-- Name: vehiculos tg_formatear_placa_mayusculas; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_formatear_placa_mayusculas BEFORE INSERT OR UPDATE ON public.vehiculos FOR EACH ROW EXECUTE FUNCTION public.fn_tr_placa_mayusculas();


--
-- Name: registros_parqueo tg_prevenir_eliminacion_registros; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_prevenir_eliminacion_registros BEFORE DELETE ON public.registros_parqueo FOR EACH ROW EXECUTE FUNCTION public.fn_tr_prevenir_borrado();


--
-- Name: registros_parqueo tg_validar_vehiculo_dentro; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tg_validar_vehiculo_dentro BEFORE INSERT ON public.registros_parqueo FOR EACH ROW EXECUTE FUNCTION public.fn_tr_validar_vehiculo();


--
-- Name: registros_parqueo registros_parqueo_placa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.registros_parqueo
    ADD CONSTRAINT registros_parqueo_placa_fkey FOREIGN KEY (placa) REFERENCES public.vehiculos(placa);


--
-- PostgreSQL database dump complete
--

\unrestrict e2Q4pWOUihFNXFbYofb5R4zlaH7GiPhMtgc39QN8LKTz0ZOuAvT6nU5rCgbXLwz

