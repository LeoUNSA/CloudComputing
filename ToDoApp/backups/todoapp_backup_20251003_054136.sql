--
-- PostgreSQL database dump
--

\restrict tWZ37uCe9hIE3XGuYCrjz23K4vXjqRrd8kmcPYdEwQUCsfeHoIt8tPBd1zbq18Q

-- Dumped from database version 15.14
-- Dumped by pg_dump version 15.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tasks (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    completed boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tasks OWNER TO postgres;

--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tasks_id_seq OWNER TO postgres;

--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tasks (id, title, description, completed, created_at, updated_at) FROM stdin;
1	Bienvenido a tu gestor de tareas	Esta es una tarea de ejemplo. Puedes marcarla como completada o eliminarla.	f	2025-10-03 08:33:32.215538	2025-10-03 08:33:32.215538
2	Explorar la aplicación	Familiarízate con las funciones: crear, completar y eliminar tareas.	f	2025-10-03 08:33:32.215538	2025-10-03 08:33:32.215538
3	Personalizar tu experiencia	Agrega tus propias tareas y organiza tu trabajo diario.	f	2025-10-03 08:33:32.215538	2025-10-03 08:33:32.215538
4	Test	Test	f	2025-10-03 08:44:55.883435	2025-10-03 08:44:55.883435
5	Tarea de prueba de persistencia	Esta tarea debe persistir después de reiniciar el pod	f	2025-10-03 08:46:07.876723	2025-10-03 08:46:07.876723
6	Tarea de carga 1	Generando métricas para Prometheus	f	2025-10-03 08:51:13.270307	2025-10-03 08:51:13.270307
7	Tarea de carga 2	Generando métricas para Prometheus	f	2025-10-03 08:51:13.303164	2025-10-03 08:51:13.303164
8	Tarea de carga 3	Generando métricas para Prometheus	f	2025-10-03 08:51:13.317522	2025-10-03 08:51:13.317522
9	Tarea de carga 4	Generando métricas para Prometheus	f	2025-10-03 08:51:13.345546	2025-10-03 08:51:13.345546
10	Tarea de carga 5	Generando métricas para Prometheus	f	2025-10-03 08:51:13.357211	2025-10-03 08:51:13.357211
11	Tarea de carga 6	Generando métricas para Prometheus	f	2025-10-03 08:51:13.369092	2025-10-03 08:51:13.369092
12	Tarea de carga 7	Generando métricas para Prometheus	f	2025-10-03 08:51:13.380103	2025-10-03 08:51:13.380103
13	Tarea de carga 8	Generando métricas para Prometheus	f	2025-10-03 08:51:13.391457	2025-10-03 08:51:13.391457
14	Tarea de carga 9	Generando métricas para Prometheus	f	2025-10-03 08:51:13.402089	2025-10-03 08:51:13.402089
15	Tarea de carga 10	Generando métricas para Prometheus	f	2025-10-03 08:51:13.413989	2025-10-03 08:51:13.413989
\.


--
-- Name: tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tasks_id_seq', 15, true);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: tasks update_tasks_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- PostgreSQL database dump complete
--

\unrestrict tWZ37uCe9hIE3XGuYCrjz23K4vXjqRrd8kmcPYdEwQUCsfeHoIt8tPBd1zbq18Q

