# PoliMusic v1 — Clon de Spotify

> **Proyecto Académico — Aplicaciones Web Avanzadas**  
> **Autor:** Dorian Albán  
> **Institución:** Escuela Politécnica Nacional (EPN)  

---

## 🎵 Descripción del Proyecto

**PoliMusic v1** es una aplicación web inspirada en la interfaz y experiencia de usuario de **Spotify**, desarrollada utilizando tecnologías clásicas robustas en el servidor (**Classic ASP / VBScript**) y un frontend moderno y responsivo con **HTML5 Audio**, **CSS3** y **JavaScript Vanilla**.

La aplicación permite la exploración de canciones, reproducción de audio en tiempo real, gestión de catálogo musical (CRUD) y control de acceso mediante roles de usuario.

---

## 🚀 Características Principales

- **Interfaz Estilo Spotify Dark:**
  - Tema oscuro característico con paleta vino/granate (`#5B0E2D` / `#800020`) y acentos modernos.
  - Reproductor persistente en la barra inferior con controles de reproducción (Play/Pause, barra de progreso interactiva, control de volumen y tiempo actual/duración).
  - Búsqueda en tiempo real de canciones por título, artista o álbum.
  - Diseño responsivo adaptado para escritorio y dispositivos móviles.

- **Autenticación y Seguridad:**
  - Sistema de inicio de sesión con control de sesiones en ASP.
  - Roles de usuario: **Administrador** (gestión total de canciones) y **Usuario Estándar** (escucha y catálogo).
  - Protección de contraseñas mediante hashing (`SHA1` / `HASHBYTES`) y compatibilidad con seed.
  - Prevención de ataques mediante tokens CSRF y saneamiento de entradas (`HTMLEncode`).

- **Gestión de Canciones (CRUD):**
  - **Crear y Editar:** Formulario modal para registrar o actualizar canciones sincronizando `TBL_SONG`, `TBL_TRACKLIST` y `TBL_PLAYER`.
  - **Eliminar:** Borrado transaccional seguro en cascada para mantener la integridad referencial.
  - **Contador de Reproducciones:** Incremento asíncrono de reproducciones (`PLAYS`) al interactuar con el reproductor.
  - **Manejo de Assets y Fallbacks:** Detección de existencia de archivos físicos con `FileSystemObject` y asignación dinámica de carátulas.

---

## 🛠️ Tecnologías Utilizadas

- **Backend:** Classic ASP (Active Server Pages) con VBScript
- **Capa de Datos:** ADODB (`MSOLEDBSQL` / `SQLOLEDB`)
- **Base de Datos:** Microsoft SQL Server (`BDD_PoliMusic`)
- **Servidor Web:** Internet Information Services (IIS)
- **Frontend:** HTML5, CSS3 moderno (Flexbox, CSS Grid, Variables CSS), JavaScript (Vanilla ES6+)

---

## 🗄️ Modelo de Base de Datos

El script completo de inicialización se encuentra en el archivo [`BDD_PoliMusic.sql`](BDD_PoliMusic.sql).

### Tablas Principales:
- `TBL_USER`: Usuarios del sistema, roles (`USER_TYPE`), credenciales y avatares.
- `TBL_SONG`: Canciones registradas y rutas de archivos de audio.
- `TBL_ALBUM`: Álbumes y carátulas.
- `TBL_ARTIST`: Artistas del catálogo.
- `TBL_TRACKLIST`: Relación entre canciones y álbumes.
- `TBL_PLAYER`: Métricas de reproducción (`PLAYS`).
- `TBL_PLAYLIST` & `TBL_PLAYLIST_SONG`: Listas de reproducción y sus temas asociados.
- `TBL_CATALOG`: Catálogo general de géneros y clasificaciones.

---

## 👥 Cuentas de Acceso de Prueba

| Usuario | Contraseña | Rol | Descripción |
| :--- | :--- | :--- | :--- |
| **`userAdmin`** | `12345678` | Administrador | Permisos para agregar, editar y eliminar canciones |
| **`userNormal`** | `12345678` | Usuario Normal | Permisos de navegación y reproducción de música |
| **`username1`** | `12345678` | Usuario Normal | Usuario de prueba con contraseña cifrada en SHA1 |

---

## ⚙️ Instalación y Configuración

### 1. Clonar el Repositorio
```bash
git clone https://github.com/DorianJoelks/AppWebAvDorianAlban.git
cd AppWebAvDorianAlban
```

### 2. Configurar la Base de Datos (SQL Server)
1. Abrir **SQL Server Management Studio (SSMS)**.
2. Ejecutar el script [`BDD_PoliMusic.sql`](BDD_PoliMusic.sql) que:
   - Crea el usuario/login `usr_polimusic` con clave `Politecnica1`.
   - Crea la base de datos `BDD_PoliMusic`.
   - Genera las tablas e inserta los datos iniciales (seed).

### 3. Configurar Conexión en ASP
Revisar el archivo [`includes/config.asp`](includes/config.asp) y ajustar los parámetros si tu instancia de SQL Server tiene otro nombre:
```vbscript
Const DB_SERVER   = "localhost"          ' o "localhost\SQLEXPRESS"
Const DB_NAME     = "BDD_PoliMusic"
Const DB_USER     = "usr_polimusic"
Const DB_PASSWORD = "Politecnica1"
Const DB_PROVIDER = "MSOLEDBSQL"         ' o "SQLOLEDB"
```

### 4. Configurar el Sitio en IIS
1. Habilitar **ASP** en las características de Windows (*Servicios de Internet Information Server -> World Wide Web Services -> Application Development Features -> ASP*).
2. Crear un sitio o aplicación virtual en IIS apuntando a la carpeta del proyecto.
3. Asegurar que los tipos MIME para `.mp3` estén configurados (ya definidos en [`web.config`](web.config)).
4. Acceder en el navegador a `http://localhost:<puerto>/` o `http://localhost:<puerto>/login.asp`.

---

## 📁 Estructura del Proyecto

```plaintext
webapppolimusicv1_asp/
├── .gitignore
├── README.md
├── BDD_PoliMusic.sql                # Script DDL/DML de la base de datos
├── web.config                       # Configuración IIS (MIME types, documentos default)
├── Default.asp                      # Redirección de entrada
├── index.asp                        # Enrutador principal de sesión
├── login.asp                        # Pantalla de autenticación
├── logout.asp                       # Cierre de sesión y limpieza
├── songs.asp                        # Vista principal del catálogo y reproductor
├── song_save.asp                    # Procesamiento de alta/edición de canciones
├── song_delete.asp                  # Procesamiento de baja de canciones
├── song_play.asp                    # Endpoint para registro de reproducciones
├── diagnostico.asp                  # Página de diagnóstico de conexión y entorno
├── preview.html                     # Vista previa estática del diseño
├── styles.css                       # Hojas de estilo CSS3
├── player.js                        # Lógica del reproductor y frontend JS
├── _syntax.js                       # Utilidades auxiliares
├── includes/
│   ├── config.asp                   # Constantes globales, rutas y helpers
│   ├── db.asp                       # Capa de abstracción y conexión ADODB
│   └── auth.asp                     # Helpers de autenticación, CSRF y control de acceso
└── SongFilesAndImages_resources/    # Recursos multimedia (audios e imágenes)
    ├── PlaylistImages/
    ├── SongFiles/
    └── UserImages/
```

---

## 📄 Licencia

Desarrollado con fines académicos para la Escuela Politécnica Nacional (EPN).
