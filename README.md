# Parqueadero La Cero 🚗🏍️

## Descripción del Sistema
El sistema de gestión de inventario para el Parqueadero La Cero es una aplicación web robusta construida con Python 3.12+ y el micro-framework Flask bajo una arquitectura limpia y desacoplada que delega por completo la persistencia y la lógica de negocio sensible a un motor relacional PostgreSQL v18.

---

## Control de Acceso y Gestión de Roles
La plataforma implementa un control de acceso inteligente basado en dos perfiles estrictos:

- **Perfil Operador:** Dispone de una interfaz dinámica orientada exclusivamente al patio para registrar los ingresos vehiculares en tiempo real y procesar las salidas.
- **Perfil Administrador:** Accede a un panel financiero protegido que oculta de forma automática los formularios operativos y despliega mediante funciones analíticas el recuudo total del día.

---

## Lógica de Negocio en Base de Datos
Toda la lógica crítica se ejecuta internamente mediante programación procedimental PL/pgSQL directamente en el servidor de base de datos para garantizar un rendimiento óptimo e incorruptible, incluyendo:

- El cálculo automatizado de tarifas por hora fraccionada ($3.000 para carros y $1.500 para motos).
- Las restricciones de duplicidad en patio.
- La auditoría automática de usuarios mediante disparadores (triggers).

---

## Guía de Despliegue Local
Para desplegar el proyecto localmente, el evaluador debe seguir estas instrucciones:

- **Clonación y dependencias:** Clonar este repositorio, activar un entorno virtual de Python e instalar las dependencias requeridas mediante el comando pip install -r requirements.txt en su terminal activa.
- **Inicialización de la base de datos:** Crear primero un esquema en blanco llamado exactamente parqueadero_la_cero en su cliente de Postgres para luego importar de forma automática toda la estructura de tablas, secuencias, funciones, triggers y datos semilla ejecutando en su terminal el comando psql -U postgres -d parqueadero_la_cero -f database.sql (introduciendo la clave correspondiente cuando sea solicitada).
- **Lanzamiento:** Finalmente, el servidor de desarrollo se pone en marcha ejecutando el script principal a través del comando python app.py, lo que permite el acceso inmediato a la plataforma interactiva desde cualquier navegador web en la dirección local http://127.0.0.1:5000.