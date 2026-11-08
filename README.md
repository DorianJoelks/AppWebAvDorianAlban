# PoliMusic — Clon de Spotify

> **Proyecto Académico — Aplicaciones Web Avanzadas**  
> **Autor:** Dorian Albán  
> **Institución:** Escuela Politécnica Nacional (EPN)

Repositorio general de **PoliMusic**, una aplicación web de música inspirada en Spotify que evoluciona en tres versiones. Cada versión implementa la misma idea (login, catálogo de canciones y reproductor) con una tecnología y una arquitectura distintas. La paleta de colores se mantiene en todas: **vino, negro y blanco**.

---

## Versiones

| Versión | Carpeta | Tecnología | Arquitectura |
| :--- | :--- | :--- | :--- |
| **v1** | [`webapppolimusicv1_asp`](webapppolimusicv1_asp) | Classic ASP / VBScript | Páginas `.asp` con includes |
| **v2** | [`WebAppPoliMusicV2`](WebAppPoliMusicV2) | ASP.NET Web Forms, C# (.NET Framework 2.0) | Un solo proyecto, con carpetas `BLL`, `DAL` y `Entities` |
| **v3** | `WebAppPoliMusicV3` + capas | ASP.NET Web Forms, C# (.NET Framework 4.8) | **N capas**, en proyectos separados |

### v1 — Classic ASP
Aplicación en **Classic ASP / VBScript** con frontend en HTML5 Audio, CSS3 y JavaScript.
- Login con sesiones y roles (administrador y usuario estándar).
- Catálogo de canciones con reproductor persistente y búsqueda en tiempo real.
- CRUD de canciones (solo administrador) y contador de reproducciones.
- Acceso a datos con ADODB directamente desde las páginas.
- Documentación completa, instalación y usuarios de prueba: [README de la v1](webapppolimusicv1_asp/README.md).

### v2 — ASP.NET Web Forms (.NET Framework 2.0)
Migración a **ASP.NET Web Forms con C#**, en un único proyecto web.
- Páginas `Login.aspx`, `SignUp.aspx`, `Default.aspx`, `Song.aspx` y `Logout.aspx`, con code-behind en C#.
- Separación lógica en carpetas dentro del mismo proyecto: `DAL` (ADO.NET con `SqlClient`), `BLL` y `Entities`.
- `Song.aspx` muestra el listado de canciones con un reproductor.
- Como las capas viven dentro del proyecto web, no se pueden reutilizar en otras aplicaciones.

### v3 — ASP.NET Web Forms en N capas (.NET Framework 4.8)
Versión actual, con una **arquitectura N-Layer real** en proyectos independientes.

```plaintext
WebAppPoliMusicV3        Presentación: páginas .aspx, Site.Master, code-behind
        │
BLL.PoliMusicV3          Lógica de negocio (User, Song)
        │
DAL.PoliMusicV3          Acceso a datos con ADO.NET (User, Song)
        │
EntityLayer.PoliMusicV3  Entidades, constantes y utilidades (hash de contraseñas)
```

- Usa la página maestra `Site.Master` con Bootstrap y menú de navegación (Inicio, Canciones, Cerrar sesión).
- Flujo: **Login → Default → Canciones**. Las páginas que usan la maestra exigen sesión iniciada.
- `Song.aspx` lista las canciones desde la base de datos en un **GridView** y permite reproducirlas desde un reproductor fijo, con búsqueda y botón «Siguiente».
- Las capas BLL, DAL y Entity no dependen de la web, por lo que pueden reutilizarse en futuras versiones.
- La presentación solo llama a la BLL, la BLL solo llama a la DAL, y la DAL es la única que habla con la base de datos.

---

## Estructura del repositorio

```plaintext
AppWebAvDorianAlban/
├── SinAppPoliMusic.slnx          # Solución con v2 y v3
├── webapppolimusicv1_asp/        # v1 — Classic ASP
├── WebAppPoliMusicV2/            # v2 — Web Forms, un proyecto
├── WebAppPoliMusicV3/            # v3 — capa de presentación
├── BLL.PoliMusicV3/              # v3 — lógica de negocio
├── DAL.PoliMusicV3/              # v3 — acceso a datos
└── EntityLayer.PoliMusicV3/      # v3 — entidades y utilidades
```

---

## Base de datos

Las tres versiones comparten la misma base de datos SQL Server, **`BDD_PoliMusic`**. El script de creación está en [`webapppolimusicv1_asp/BDD_PoliMusic.sql`](webapppolimusicv1_asp/BDD_PoliMusic.sql). Crea el login `usr_polimusic` y las tablas `TBL_USER`, `TBL_SONG`, `TBL_ALBUM`, `TBL_ARTIST`, `TBL_TRACKLIST`, `TBL_PLAYER`, `TBL_PLAYLIST`, `TBL_PLAYLIST_SONG` y `TBL_CATALOG`.

Las versiones 2 y 3 leen la cadena de conexión `BDD_PoliMusicConnectionString` de su `Web.config`:

```xml
<add name="BDD_PoliMusicConnectionString"
     connectionString="Data Source=localhost,1434;Initial Catalog=BDD_PoliMusic;User ID=usr_polimusic;Password=Politecnica1"
     providerName="System.Data.SqlClient"/>
```

---

## Cómo ejecutar

### v1
Habilitar ASP en IIS y apuntar un sitio a `webapppolimusicv1_asp`. Los pasos detallados están en su [README](webapppolimusicv1_asp/README.md).

### v2 y v3
1. Clonar el repositorio:
   ```bash
   git clone https://github.com/DorianJoelks/AppWebAvDorianAlban.git
   ```
2. Ejecutar el script SQL y ajustar la cadena de conexión si hace falta.
3. Abrir `SinAppPoliMusic.slnx` en **Visual Studio**.
4. Clic derecho sobre el proyecto web que se quiere ejecutar → **Establecer como proyecto de inicio**:
   - `WebAppPoliMusicV3` (puerto 54836), que abre `Login.aspx`.
   - `WebAppPoliMusicV2` (puerto 64948).
5. Pulsar **Run / F5**.

> [!NOTE]
> La solución contiene varias versiones y Visual Studio ejecuta solo el **proyecto de inicio**. Si al pulsar Run se abre una versión anterior, cambia el proyecto de inicio como se indica arriba.

---

## Licencia

Desarrollado con fines académicos para la Escuela Politécnica Nacional (EPN).
