<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/db.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · songs.asp
'  Vista principal: catálogo de canciones + reproductor persistente.
' -----------------------------------------------------------------------------
'  Modelo de datos utilizado (BDD_PoliMusic.sql):
'     TBL_SONG        → pista (SONG_NAME, SONG_PATH, PLAYS)
'     TBL_TRACKLIST   → relación Álbum ↔ Canción
'     TBL_ALBUM       → título, año e imagen del álbum
'     TBL_PLAYER      → relación Canción ↔ Artista
'     TBL_ARTIST      → nombre y apellido del artista
'     TBL_PLAYLIST    → playlists del usuario (barra lateral)
'     TBL_CATALOG     → etiquetas de los dominios USER TYPE / PLAYLIST TYPE
'
'  Control de roles:
'     Session("UserRole") = "admin"  → ve y usa el CRUD completo
'     Session("UserRole") = "normal" → el HTML del CRUD NO se renderiza
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    Session.CodePage  = 65001

    ' -------------------------------------------------------------------------
    '  1. Control de acceso
    ' -------------------------------------------------------------------------
    RequireLogin()
    NoCache()

    Dim conn, connError
    Dim sqlSongs, sqlPlaylists, sqlAlbums, sqlArtists
    Dim rsSongs, rsPlaylists, rsAlbums, rsArtists
    Dim isAdminUser, flashMsg, flashType
    Dim totalSongs, totalPlays
    Dim rowIndex, songId, songTitle, songPath, songPlays
    Dim albumId, albumTitle, albumImage, releaseYear
    Dim artistId, artistName, artistLastName, artistFull
    Dim coverWeb, audioWeb, isAvailable, genreLabel
    Dim userName, userRole, userPhoto, userInitials, roleLabel
    Dim files, f, heroCover, emptyCover
    Dim userId, availableAttr, playBtnExtra

    isAdminUser = IsAdmin()
    userId      = SafeInt(Session("UserId"), 0)

    userName     = TrimStr(Session("UserName"))
    userRole     = LCase(TrimStr(Session("UserRole")))
    userPhoto    = AvatarForUser(Session("UserPhoto"))
    userInitials = InitialsOf(userName)
    If userRole = "admin" Then roleLabel = "Administrador" Else roleLabel = "Usuario"

    ' Mensajes flash provenientes de un CRUD (song_save.asp / song_delete.asp)
    flashType = TakeFlashType()
    flashMsg  = TakeFlash()

    ' -------------------------------------------------------------------------
    '  2. Conexión
    ' -------------------------------------------------------------------------
    Set conn = TryOpenConnection(connError)
    If conn Is Nothing Then
        RenderFatal "Base de datos no disponible", connError
    End If

    ' -------------------------------------------------------------------------
    '  3. Consultas
    ' -------------------------------------------------------------------------

    ' Catálogo: una fila por canción con su álbum y artista principal.
    ' OUTER APPLY evita duplicar filas cuando una pista pertenece a varios
    ' álbumes o tiene varios artistas (relaciones N:M del esquema).
    sqlSongs = "SET NOCOUNT ON; " & _
               "SELECT s.ID_SONG, s.SONG_NAME, s.SONG_PATH, ISNULL(s.PLAYS, 0) AS PLAYS, " & _
               "       al.ID_ALBUM, al.TITLE_ALBUM, al.ALBUM_IMAGE_PATH, al.RELEASE_YEAR, " & _
               "       ar.ID_ARTIST, ar.ARTIST_NAME, ar.ARTIST_LASTNAME, ar.ARTIST_IMAGE " & _
               "FROM dbo.TBL_SONG AS s " & _
               "OUTER APPLY ( " & _
               "    SELECT TOP (1) a.ID_ALBUM, a.TITLE_ALBUM, a.ALBUM_IMAGE_PATH, a.RELEASE_YEAR " & _
               "    FROM dbo.TBL_TRACKLIST AS t " & _
               "    INNER JOIN dbo.TBL_ALBUM AS a ON a.ID_ALBUM = t.ID_ALBUM " & _
               "    WHERE t.ID_SONG = s.ID_SONG " & _
               "    ORDER BY a.ID_ALBUM " & _
               ") AS al " & _
               "OUTER APPLY ( " & _
               "    SELECT TOP (1) r.ID_ARTIST, r.ARTIST_NAME, r.ARTIST_LASTNAME, r.ARTIST_IMAGE " & _
               "    FROM dbo.TBL_PLAYER AS p " & _
               "    INNER JOIN dbo.TBL_ARTIST AS r ON r.ID_ARTIST = p.ID_ARTIST " & _
               "    WHERE p.ID_SONG = s.ID_SONG " & _
               "    ORDER BY r.ID_ARTIST " & _
               ") AS ar " & _
               "ORDER BY s.ID_SONG;"

    ' Playlists visibles: las propias del usuario + todas las públicas (TYPE = 0)
    sqlPlaylists = "SET NOCOUNT ON; " & _
                   "SELECT TOP (8) p.ID_PLAYLIST, p.TITLE, p.PHOTO, p.TYPE, " & _
                   "       ISNULL(c.VALUE, 'Pública') AS TYPE_NAME " & _
                   "FROM dbo.TBL_PLAYLIST AS p " & _
                   "LEFT JOIN dbo.TBL_CATALOG AS c " & _
                   "       ON c.COD_CATALOG_PARENT = '2' " & _
                   "      AND c.COD_CATALOG = CAST(p.TYPE AS varchar(8)) " & _
                   "WHERE p.ID_USER = ? OR p.TYPE = 0 " & _
                   "ORDER BY p.CREATION_DATE DESC;"

    ' Catálogos para los desplegables del formulario de administración
    sqlAlbums  = "SET NOCOUNT ON; SELECT ID_ALBUM, TITLE_ALBUM, RELEASE_YEAR " & _
                 "FROM dbo.TBL_ALBUM ORDER BY TITLE_ALBUM;"
    sqlArtists = "SET NOCOUNT ON; SELECT ID_ARTIST, ARTIST_NAME, ARTIST_LASTNAME " & _
                 "FROM dbo.TBL_ARTIST ORDER BY ARTIST_NAME;"

    On Error Resume Next
    Set rsSongs = OpenRecordset(conn, sqlSongs, Empty)
    If Err.Number <> 0 Then
        connError = Err.Description
        Err.Clear
        On Error GoTo 0
        CloseConn conn
        RenderFatal "Error al leer el catálogo", connError
    End If
    On Error GoTo 0

    Set rsPlaylists = OpenRecordset(conn, sqlPlaylists, Array(userId))

    If isAdminUser Then
        Set rsAlbums  = OpenRecordset(conn, sqlAlbums, Empty)
        Set rsArtists = OpenRecordset(conn, sqlArtists, Empty)
    End If

    ' Totales del catálogo (se muestran en el encabezado antes de la tabla)
    totalSongs = SafeInt(QueryValue(conn, "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.TBL_SONG;", Empty, 0), 0)
    totalPlays = SafeInt(QueryValue(conn, "SET NOCOUNT ON; SELECT ISNULL(SUM(PLAYS), 0) FROM dbo.TBL_SONG;", Empty, 0), 0)

    ' Inventario real de .mp3 en disco (para el datalist del formulario)
    files = ListSongFiles()

    ' Portada del encabezado tipo "playlist"
    heroCover = ASSETS_FOLDER & "/PlaylistImages/playlist3.png"
    heroCover = ResolveAsset(heroCover, DEFAULT_COVER)
    emptyCover = DEFAULT_COVER
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="PoliMusic · Catálogo de canciones y reproductor web.">
    <title><%= H(APP_NAME) %> · Song List</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body class="page-songs" data-role="<%= H(userRole) %>">

<!-- =========================================================================
     ESTRUCTURA: sidebar + contenido + reproductor fijo
     ========================================================================= -->
<div class="app-shell">

    <!-- ===================== BARRA LATERAL ============================== -->
    <aside class="sidebar" id="sidebar" aria-label="Navegación principal">

        <a class="sidebar__brand" href="songs.asp">
            <span class="brand-mark" aria-hidden="true">
                <svg viewBox="0 0 32 32" width="26" height="26" fill="none">
                    <circle cx="16" cy="16" r="15" stroke="currentColor" stroke-width="2"/>
                    <path d="M13 21.5V10.8l8-1.6v9.4" stroke="currentColor" stroke-width="2"
                          stroke-linecap="round" stroke-linejoin="round"/>
                    <circle cx="11" cy="21.6" r="2.4" fill="currentColor"/>
                    <circle cx="19" cy="18.9" r="2.4" fill="currentColor"/>
                </svg>
            </span>
            <span class="brand-name">Poli<span>Music</span></span>
        </a>

        <nav class="sidebar__nav">
            <a class="nav-item is-active" href="songs.asp">
                <svg viewBox="0 0 24 24" width="22" height="22" fill="none" aria-hidden="true">
                    <path d="M3 10.2 12 3l9 7.2V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-9.8Z"
                          stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
                </svg>
                <span>Inicio</span>
            </a>
            <a class="nav-item" href="#catalogo" data-focus-search>
                <svg viewBox="0 0 24 24" width="22" height="22" fill="none" aria-hidden="true">
                    <circle cx="11" cy="11" r="7" stroke="currentColor" stroke-width="1.8"/>
                    <path d="m16.5 16.5 4 4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                </svg>
                <span>Buscar</span>
            </a>
            <a class="nav-item" href="#catalogo">
                <svg viewBox="0 0 24 24" width="22" height="22" fill="none" aria-hidden="true">
                    <path d="M4 4h4v16H4zM10 4h4v16h-4zM17 6l3 14" stroke="currentColor"
                          stroke-width="1.8" stroke-linejoin="round"/>
                </svg>
                <span>Tu biblioteca</span>
            </a>
        </nav>

        <div class="sidebar__section">
            <h2 class="sidebar__heading">Tus playlists</h2>
            <ul class="playlist-list">
                <%
                    If Not rsPlaylists.EOF Then
                        Do While Not rsPlaylists.EOF
                            coverWeb = ResolveAsset(VirtualToWebPath(rsPlaylists("PHOTO")), DEFAULT_COVER)
                %>
                <li class="playlist-item">
                    <img class="playlist-item__cover" src="<%= H(coverWeb) %>" alt="" loading="lazy" width="40" height="40">
                    <span class="playlist-item__body">
                        <span class="playlist-item__title"><%= H(rsPlaylists("TITLE")) %></span>
                        <span class="playlist-item__meta"><%= H(rsPlaylists("TYPE_NAME")) %> · Playlist</span>
                    </span>
                </li>
                <%
                            rsPlaylists.MoveNext
                        Loop
                    Else
                %>
                <li class="playlist-item playlist-item--empty">
                    <span class="playlist-item__meta">Todavía no hay playlists.</span>
                </li>
                <%
                    End If
                %>
            </ul>
        </div>

        <div class="sidebar__user">
            <span class="avatar avatar--sm">
                <img src="<%= H(userPhoto) %>" alt="" width="36" height="36">
            </span>
            <span class="sidebar__user-body">
                <span class="sidebar__user-name"><%= H(userName) %></span>
                <span class="sidebar__user-role"><%= H(roleLabel) %></span>
            </span>
        </div>
    </aside>

    <!-- ===================== CONTENIDO PRINCIPAL ======================== -->
    <main class="main" id="catalogo">

        <!-- ---------- Barra superior ---------- -->
        <header class="topbar">
            <button class="icon-btn sidebar-toggle" id="sidebarToggle"
                    aria-label="Mostrar u ocultar el menú" aria-expanded="false" aria-controls="sidebar">
                <svg viewBox="0 0 24 24" width="22" height="22" fill="none" aria-hidden="true">
                    <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                </svg>
            </button>

            <div class="search">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                    <circle cx="11" cy="11" r="7" stroke="currentColor" stroke-width="1.8"/>
                    <path d="m16.5 16.5 4 4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                </svg>
                <input  type="search"
                        id="searchInput"
                        class="search__input"
                        placeholder="¿Qué quieres escuchar?"
                        aria-label="Buscar canciones por título, artista o álbum"
                        autocomplete="off">
            </div>

            <div class="topbar__right">
                <p class="welcome">Bienvenido, <strong><%= H(Session("UserName")) %></strong></p>

                <span class="role-chip role-chip--<%= H(userRole) %>">
                    <span class="role-chip__dot" aria-hidden="true"></span><%= H(roleLabel) %>
                </span>

                <a class="btn btn-ghost btn-sm" href="logout.asp" title="Cerrar la sesión actual"
                   aria-label="Cerrar sesión">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
                        <path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3" stroke="currentColor"
                              stroke-width="1.8" stroke-linecap="round"/>
                        <path d="M10 8l-4 4 4 4M6 12h9" stroke="currentColor"
                              stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <span class="btn-label">Cerrar sesión</span>
                </a>            </div>
        </header>

        <!-- ---------- Encabezado tipo playlist ---------- -->
        <section class="hero">
            <div class="hero__cover">
                <img src="<%= H(heroCover) %>" alt="Portada del catálogo PoliMusic" width="232" height="232">
            </div>
            <div class="hero__info">
                <p class="hero__eyebrow">Playlist · Catálogo</p>
                <h1 class="hero__title">Song List</h1>
                <p class="hero__meta">
                    <span class="hero__owner"><%= H(userName) %></span>
                    <span class="dot" aria-hidden="true">·</span>
                    <span><%= FormatCount(totalSongs) %> canciones</span>
                    <span class="dot" aria-hidden="true">·</span>
                    <span><%= FormatCount(totalPlays) %> reproducciones</span>
                </p>
                <div class="hero__actions">
                    <button type="button" class="btn-play-xl" data-play-all aria-label="Reproducir todo el catálogo">
                        <svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor" aria-hidden="true">
                            <path d="M8 5.2v13.6L19 12z"/>
                        </svg>
                    </button>
                    <button type="button" class="btn btn-ghost btn-sm" data-shuffle-all>
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
                            <path d="M17 3.5 20 6l-3 2.5M17 15.5 20 18l-3 2.5M4 6h3.5c2.5 0 3.5 2 4.5 4s2 4 4.5 4H20M4 18h3.5c2.5 0 3.5-2 4.5-4"
                                  stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        Aleatorio
                    </button>

                    <% If isAdminUser Then %>
                    <!-- ============ SOLO ADMIN: alta de canciones ============ -->
                    <button type="button" class="btn btn-wine btn-sm" data-open-modal="song" data-mode="create">
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
                            <path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                        </svg>
                        Añadir canción
                    </button>
                    <% End If %>
                </div>
            </div>
        </section>

        <!-- ---------- Aviso flash ---------- -->
        <% If flashMsg <> "" Then %>
        <div class="alert alert-<%= H(flashType) %> alert--floating" role="status" id="flashAlert">
            <span><%= H(flashMsg) %></span>
            <button type="button" class="alert__close" aria-label="Cerrar aviso"
                    onclick="this.parentNode.remove();">&times;</button>
        </div>
        <% End If %>

        <!-- ---------- Tabla / lista de canciones ---------- -->
        <section class="catalog" aria-labelledby="catalogTitle">
            <h2 class="sr-only" id="catalogTitle">Listado de canciones</h2>

            <table class="track-table" id="trackTable">
                <thead>
                    <tr>
                        <th class="col-index" scope="col">#</th>
                        <th class="col-title" scope="col">Título</th>
                        <th class="col-artist" scope="col">Artista / Álbum</th>
                        <th class="col-genre" scope="col">Género / Duración</th>
                        <th class="col-plays" scope="col">Reproducciones</th>
                        <th class="col-actions" scope="col">
                            <% If isAdminUser Then %>Acciones<% End If %>
                        </th>
                    </tr>
                </thead>
                <tbody id="trackBody">
                <%
                    rowIndex = 0

                    Do While Not rsSongs.EOF

                        rowIndex = rowIndex + 1

                        songId    = SafeInt(rsSongs("ID_SONG"), 0)
                        songTitle = TrimStr(rsSongs("SONG_NAME"))
                        songPath  = TrimStr(rsSongs("SONG_PATH"))
                        songPlays = SafeInt(rsSongs("PLAYS"), 0)

                        albumId     = SafeInt(rsSongs("ID_ALBUM"), 0)
                        albumTitle  = TrimStr(rsSongs("TITLE_ALBUM"))
                        albumImage  = TrimStr(rsSongs("ALBUM_IMAGE_PATH"))
                        releaseYear = TrimStr(rsSongs("RELEASE_YEAR"))

                        artistId       = SafeInt(rsSongs("ID_ARTIST"), 0)
                        artistName     = TrimStr(rsSongs("ARTIST_NAME"))
                        artistLastName = TrimStr(rsSongs("ARTIST_LASTNAME"))
                        artistFull     = Trim(artistName & " " & artistLastName)
                        If artistFull = "" Then artistFull = "Artista desconocido"

                        ' Carátula: álbum → carátula derivada → imagen por defecto
                        coverWeb = CoverForSong(songId, albumImage)

                        ' Ruta web real del .mp3 y comprobación de existencia
                        audioWeb    = VirtualToWebPath(songPath)
                        isAvailable = WebAssetExists(audioWeb)

                        ' VBScript no dispone de IIf(): se resuelven los atributos aquí
                        If isAvailable Then
                            availableAttr = "1"
                            playBtnExtra  = ""
                        Else
                            availableAttr = "0"
                            playBtnExtra  = "disabled title=""Archivo de audio no disponible"""
                        End If

                        genreLabel = GenreFromAlbum(albumTitle)
                %>
                    <tr class="track-row"
                        data-id="<%= songId %>"
                        data-title="<%= H(songTitle) %>"
                        data-artist="<%= H(artistFull) %>"
                        data-album="<%= H(albumTitle) %>"
                        data-cover="<%= H(coverWeb) %>"
                        data-src="<%= H(audioWeb) %>"
                        data-plays="<%= songPlays %>"
                        data-available="<%= availableAttr %>"
                        data-album-id="<%= albumId %>"
                        data-artist-id="<%= artistId %>"
                        data-path="<%= H(songPath) %>">

                        <!-- 1. # + carátula -->
                        <td class="col-index">
                            <div class="cell-index">
                                <span class="row-index"><%= rowIndex %></span>
                                <span class="eq" aria-hidden="true">
                                    <i></i><i></i><i></i>
                                </span>
                                <img class="row-cover" src="<%= H(coverWeb) %>"
                                     alt="Carátula de <%= H(songTitle) %>"
                                     width="44" height="44" loading="lazy">
                            </div>
                        </td>

                        <!-- 2. Título -->
                        <td class="col-title">
                            <div class="cell-title">
                                <span class="track-title"><%= H(songTitle) %></span>
                                <span class="track-sub">
                                    <% If Not isAvailable Then %>
                                        <span class="badge badge--warn" title="El archivo no existe en SongFilesAndImages_resources/SongFiles">Sin archivo</span>
                                    <% End If %>
                                    <% If releaseYear <> "" Then %><%= H(releaseYear) %><% End If %>
                                </span>
                            </div>
                        </td>

                        <!-- 3. Artista / Álbum -->
                        <td class="col-artist">
                            <div class="cell-stack">
                                <span class="track-artist"><%= H(artistFull) %></span>
                                <span class="track-album"><%= H(albumTitle) %><% If albumTitle = "" Then %>—<% End If %></span>
                            </div>
                        </td>

                        <!-- 4. Género / Duración -->
                        <td class="col-genre">
                            <div class="cell-stack">
                                <span class="genre-chip"><%= H(genreLabel) %></span>
                                <span class="track-duration" data-duration-cell>--:--</span>
                            </div>
                        </td>

                        <!-- 5. Reproducciones -->
                        <td class="col-plays">
                            <span class="plays" data-plays-cell><%= FormatCount(songPlays) %></span>
                        </td>

                        <!-- 6. Acciones -->
                        <td class="col-actions">
                            <div class="row-actions">
                                <button type="button"
                                        class="icon-btn icon-btn--play"
                                        data-play="<%= songId %>"
                                        aria-label="Reproducir <%= H(songTitle) %>"
                                        <%= playBtnExtra %>>
                                    <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" aria-hidden="true">
                                        <path d="M8 5.2v13.6L19 12z"/>
                                    </svg>
                                </button>

                                <% If isAdminUser Then %>
                                <!-- ======= SOLO ADMIN: editar / eliminar ======= -->
                                <button type="button"
                                        class="icon-btn"
                                        data-open-modal="song"
                                        data-mode="edit"
                                        aria-label="Editar <%= H(songTitle) %>"
                                        title="Editar">
                                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
                                        <path d="M4 20h4l10-10a2.8 2.8 0 0 0-4-4L4 16v4Z" stroke="currentColor"
                                              stroke-width="1.7" stroke-linejoin="round"/>
                                        <path d="M13.5 6.5 17.5 10.5" stroke="currentColor" stroke-width="1.7"/>
                                    </svg>
                                </button>
                                <button type="button"
                                        class="icon-btn icon-btn--danger"
                                        data-open-modal="delete"
                                        aria-label="Eliminar <%= H(songTitle) %>"
                                        title="Eliminar">
                                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true">
                                        <path d="M5 7h14M9.5 7V5h5v2M7 7l1 12h8l1-12" stroke="currentColor"
                                              stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
                                    </svg>
                                </button>
                                <% End If %>
                            </div>
                        </td>
                    </tr>
                <%
                        rsSongs.MoveNext
                    Loop

                    If rowIndex = 0 Then
                %>
                    <tr class="track-row track-row--empty">
                        <td colspan="6">
                            <div class="empty-state">
                                <img src="<%= H(emptyCover) %>" alt="" width="72" height="72">
                                <p class="empty-state__title">El catálogo está vacío</p>
                                <p class="empty-state__text">
                                    <% If isAdminUser Then %>
                                        Añade tu primera canción con el botón «Añadir canción».
                                    <% Else %>
                                        Pide a un administrador que agregue canciones al catálogo.
                                    <% End If %>
                                </p>
                            </div>
                        </td>
                    </tr>
                <%
                    End If
                %>
                </tbody>
            </table>

            <p class="catalog__empty-search" id="emptySearch" hidden>
                No se encontraron canciones que coincidan con tu búsqueda.
            </p>
        </section>

        <footer class="main__foot">
            <span><%= H(APP_NAME) %> · <%= H(APP_TAGLINE) %></span>
            <span>Catálogo servido desde <code>BDD_PoliMusic</code></span>
        </footer>
    </main>
</div>

<!-- =========================================================================
     REPRODUCTOR PERSISTENTE (estilo bottom player de Spotify)
     ========================================================================= -->
<footer class="player" id="player" aria-label="Reproductor de música">

    <!-- Zona izquierda: pista actual -->
    <div class="player__now">
        <img class="player__cover" id="playerCover" src="<%= H(heroCover) %>"
             alt="" width="56" height="56">
        <div class="player__meta">
            <span class="player__title" id="playerTitle">Selecciona una canción</span>
            <span class="player__artist" id="playerArtist"><%= H(APP_NAME) %></span>
        </div>
        <button type="button" class="icon-btn icon-btn--like" id="btnLike"
                aria-label="Me gusta" aria-pressed="false">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                <path d="M12 20s-7.5-4.6-7.5-9.4A4.1 4.1 0 0 1 12 8a4.1 4.1 0 0 1 7.5 2.6C19.5 15.4 12 20 12 20Z"
                      stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
            </svg>
        </button>
    </div>

    <!-- Zona central: controles + progreso -->
    <div class="player__center">
        <div class="player__controls">
            <button type="button" class="icon-btn" id="btnShuffle" aria-label="Aleatorio" aria-pressed="false">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                    <path d="M17 3.5 20 6l-3 2.5M17 15.5 20 18l-3 2.5M4 6h3.5c2.5 0 3.5 2 4.5 4s2 4 4.5 4H20M4 18h3.5c2.5 0 3.5-2 4.5-4"
                          stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>

            <button type="button" class="icon-btn" id="btnPrev" aria-label="Pista anterior">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">
                    <path d="M18 5.5v13L9 12zM7 5.5h2v13H7z"/>
                </svg>
            </button>

            <button type="button" class="btn-play-main" id="btnPlay" aria-label="Reproducir" aria-pressed="false">
                <svg class="icon-play" viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">
                    <path d="M8 5.2v13.6L19 12z"/>
                </svg>
                <svg class="icon-pause" viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">
                    <path d="M7 5h3.5v14H7zM13.5 5H17v14h-3.5z"/>
                </svg>
            </button>

            <button type="button" class="icon-btn" id="btnNext" aria-label="Pista siguiente">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">
                    <path d="M6 5.5v13L15 12zM15 5.5h2v13h-2z"/>
                </svg>
            </button>

            <button type="button" class="icon-btn" id="btnRepeat" aria-label="Repetir" aria-pressed="false">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                    <path d="M17 3.5 20 6.5l-3 3M20 6.5H8.5A3.5 3.5 0 0 0 5 10v.5M7 20.5 4 17.5l3-3M4 17.5h11.5A3.5 3.5 0 0 0 19 14v-.5"
                          stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>
        </div>

        <div class="player__progress">
            <span class="player__time" id="timeCurrent">0:00</span>
            <input  type="range" class="range" id="seek"
                    min="0" max="1000" step="1" value="0"
                    aria-label="Progreso de la canción">
            <span class="player__time" id="timeTotal">0:00</span>
        </div>
    </div>

    <!-- Zona derecha: volumen -->
    <div class="player__right">
        <button type="button" class="icon-btn" id="btnMute" aria-label="Silenciar" aria-pressed="false">
            <svg class="icon-vol" viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                <path d="M4 9.5h3.5L12 6v12L7.5 14.5H4z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
                <path d="M15.5 9.2a4 4 0 0 1 0 5.6M18 7a7.5 7.5 0 0 1 0 10" stroke="currentColor"
                      stroke-width="1.7" stroke-linecap="round"/>
            </svg>
            <svg class="icon-mute" viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                <path d="M4 9.5h3.5L12 6v12L7.5 14.5H4z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
                <path d="m16 9.5 5 5M21 9.5l-5 5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>
            </svg>
        </button>
        <input  type="range" class="range range--vol" id="volume"
                min="0" max="100" step="1" value="80"
                aria-label="Volumen">
    </div>
</footer>

<!-- Elemento de audio único: toda la reproducción pasa por aquí -->
<audio id="audio" preload="metadata"></audio>

<!-- Contenedor de notificaciones -->
<div class="toasts" id="toasts" aria-live="polite" aria-atomic="true"></div>

<% If isAdminUser Then %>
<!-- =========================================================================
     MODALES DE ADMINISTRACIÓN (no se generan para el rol "normal")
     ========================================================================= -->

<!-- ---------- Alta / edición de canción ---------- -->
<div class="modal" id="modal-song" hidden>
    <div class="modal__backdrop" data-close-modal></div>
    <div class="modal__dialog" role="dialog" aria-modal="true" aria-labelledby="modalSongTitle">
        <header class="modal__head">
            <h2 class="modal__title" id="modalSongTitle">Añadir canción</h2>
            <button type="button" class="icon-btn" data-close-modal aria-label="Cerrar">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                    <path d="m6 6 12 12M18 6 6 18" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
                </svg>
            </button>
        </header>

        <form class="modal__body" method="post" action="song_save.asp" id="formSong" novalidate>
            <input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>">
            <input type="hidden" name="action" id="songAction" value="create">
            <input type="hidden" name="id" id="songId" value="">

            <div class="field">
                <label for="songName">Título de la canción <span class="req">*</span></label>
                <input type="text" class="input" id="songName" name="song_name"
                       maxlength="50" required placeholder="Ej. Adventure">
            </div>

            <div class="field">
                <label for="songPath">Archivo de audio <span class="req">*</span></label>
                <input type="text" class="input" id="songPath" name="song_path"
                       maxlength="255" required list="songFilesList"
                       placeholder="~/songFiles/bensound-adventure.mp3">
                <datalist id="songFilesList">
                    <% For Each f In files %>
                    <option value="~/songFiles/<%= H(f) %>"></option>
                    <% Next %>
                </datalist>
                <p class="field__hint">
                    Ruta virtual almacenada en <code>TBL_SONG.SONG_PATH</code>.
                    Los archivos disponibles se listan desde <code><%= H(ASSETS_FOLDER) %>/SongFiles</code>.
                </p>
            </div>

            <div class="field-grid">
                <div class="field">
                    <label for="songPlays">Reproducciones</label>
                    <input type="number" class="input" id="songPlays" name="plays"
                           min="0" max="9999999" step="1" value="0">
                </div>

                <div class="field">
                    <label for="songAlbum">Álbum <span class="field__optional">(opcional)</span></label>
                    <select class="input" id="songAlbum" name="album_id">
                        <option value="0">— Sin álbum —</option>
                        <%
                            Do While Not rsAlbums.EOF
                        %>
                        <option value="<%= SafeInt(rsAlbums("ID_ALBUM"), 0) %>">
                            <%= H(rsAlbums("TITLE_ALBUM")) %><% If Not IsNull(rsAlbums("RELEASE_YEAR")) Then %> (<%= H(rsAlbums("RELEASE_YEAR")) %>)<% End If %>
                        </option>
                        <%
                                rsAlbums.MoveNext
                            Loop
                        %>
                    </select>
                </div>
            </div>

            <div class="field">
                <label for="songArtist">Artista <span class="field__optional">(opcional)</span></label>
                <select class="input" id="songArtist" name="artist_id">
                    <option value="0">— Sin artista —</option>
                    <%
                        Do While Not rsArtists.EOF
                    %>
                    <option value="<%= SafeInt(rsArtists("ID_ARTIST"), 0) %>">
                        <%= H(Trim(TrimStr(rsArtists("ARTIST_NAME")) & " " & TrimStr(rsArtists("ARTIST_LASTNAME")))) %>
                    </option>
                    <%
                            rsArtists.MoveNext
                        Loop
                    %>
                </select>
                <p class="field__hint">
                    El álbum se guarda en <code>TBL_TRACKLIST</code> y el artista en
                    <code>TBL_PLAYER</code> (relaciones N:M del modelo ER).
                </p>
            </div>

            <footer class="modal__foot">
                <button type="button" class="btn btn-ghost" data-close-modal>Cancelar</button>
                <button type="submit" class="btn btn-wine" id="songSubmit">Guardar canción</button>
            </footer>
        </form>
    </div>
</div>

<!-- ---------- Confirmación de borrado ---------- -->
<div class="modal" id="modal-delete" hidden>
    <div class="modal__backdrop" data-close-modal></div>
    <div class="modal__dialog modal__dialog--sm" role="alertdialog" aria-modal="true"
         aria-labelledby="modalDeleteTitle">
        <header class="modal__head">
            <h2 class="modal__title" id="modalDeleteTitle">Eliminar canción</h2>
            <button type="button" class="icon-btn" data-close-modal aria-label="Cerrar">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                    <path d="m6 6 12 12M18 6 6 18" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
                </svg>
            </button>
        </header>

        <form class="modal__body" method="post" action="song_delete.asp" id="formDelete">
            <input type="hidden" name="csrf" value="<%= H(CsrfToken()) %>">
            <input type="hidden" name="id" id="deleteId" value="">

            <p class="modal__text">
                Vas a eliminar <strong id="deleteName">esta canción</strong> del catálogo.
                También se quitarán sus vínculos con álbumes, artistas y playlists.
                Esta acción no se puede deshacer.
            </p>

            <footer class="modal__foot">
                <button type="button" class="btn btn-ghost" data-close-modal>Cancelar</button>
                <button type="submit" class="btn btn-danger">Eliminar definitivamente</button>
            </footer>
        </form>
    </div>
</div>
<% End If %>

<script src="player.js" defer></script>
</body>
</html>
<%
' -----------------------------------------------------------------------------
'  Liberación de recursos
' -----------------------------------------------------------------------------
    CloseRs rsSongs
    CloseRs rsPlaylists
    CloseRs rsAlbums
    CloseRs rsArtists
    CloseConn conn
%>
