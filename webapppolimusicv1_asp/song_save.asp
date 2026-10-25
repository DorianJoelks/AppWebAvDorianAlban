<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/db.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · song_save.asp
'  Alta (INSERT) y edición (UPDATE) de canciones. Solo rol "admin".
' -----------------------------------------------------------------------------
'  Operaciones realizadas dentro de una transacción:
'     · INSERT / UPDATE sobre TBL_SONG
'     · Sincronización de TBL_TRACKLIST (relación con el álbum)
'     · Sincronización de TBL_PLAYER    (relación con el artista)
'  Cualquier error hace ROLLBACK y devuelve al catálogo con un mensaje.
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    Session.CodePage  = 65001

    RequireLogin()
    RequireAdmin()
    NoCache()

    Dim conn, connError
    Dim action, songId, songName, songPath, plays, albumId, artistId
    Dim sqlText, rsNew, newId, existsCount
    Dim dbError, okFlag

    ' -------------------------------------------------------------------------
    '  1. Solo se acepta POST
    ' -------------------------------------------------------------------------
    If Not IsPost() Then
        Response.Redirect "songs.asp"
        Response.End
    End If

    ValidateCsrf()

    ' -------------------------------------------------------------------------
    '  2. Lectura y saneamiento de campos
    ' -------------------------------------------------------------------------
    action   = LCase(PostStr("action"))
    songId   = SafeInt(Request.Form("id"), 0)
    songName = PostStr("song_name")
    songPath = PostStr("song_path")
    plays    = SafeInt(Request.Form("plays"), 0)
    albumId  = SafeInt(Request.Form("album_id"), 0)
    artistId = SafeInt(Request.Form("artist_id"), 0)

    If action <> "update" Then action = "create"

    ' --- Validaciones de negocio (el cliente también valida, pero se repiten) --
    If Len(songName) = 0 Then
        SetFlash "El título de la canción es obligatorio.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If
    If Len(songName) > 50 Then
        SetFlash "El título no puede superar los 50 caracteres (límite de TBL_SONG.SONG_NAME).", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If
    If Len(songPath) = 0 Then
        SetFlash "La ruta del archivo de audio es obligatoria.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If
    If Len(songPath) > 255 Then
        SetFlash "La ruta del archivo no puede superar los 255 caracteres.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If
    If plays < 0 Then plays = 0
    If plays > 9999999 Then plays = 9999999
    If action = "update" And songId <= 0 Then
        SetFlash "No se indicó una canción válida para editar.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If

    ' -------------------------------------------------------------------------
    '  3. Conexión
    ' -------------------------------------------------------------------------
    Set conn = TryOpenConnection(connError)
    If conn Is Nothing Then
        SetFlash "No se pudo conectar con la base de datos.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If

    ' Verificar que la canción exista antes de actualizar
    If action = "update" Then
        existsCount = SafeInt(QueryValue(conn, _
            "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.TBL_SONG WHERE ID_SONG = ?;", _
            Array(songId), 0), 0)
        If existsCount = 0 Then
            CloseConn conn
            SetFlash "La canción que intentas editar ya no existe.", "error"
            Response.Redirect "songs.asp"
            Response.End
        End If
    End If

    ' Verificar integridad referencial de álbum / artista seleccionados
    If albumId > 0 Then
        If SafeInt(QueryValue(conn, "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.TBL_ALBUM WHERE ID_ALBUM = ?;", Array(albumId), 0), 0) = 0 Then
            albumId = 0
        End If
    End If
    If artistId > 0 Then
        If SafeInt(QueryValue(conn, "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.TBL_ARTIST WHERE ID_ARTIST = ?;", Array(artistId), 0), 0) = 0 Then
            artistId = 0
        End If
    End If

    ' -------------------------------------------------------------------------
    '  4. Transacción
    ' -------------------------------------------------------------------------
    okFlag  = False
    dbError = ""

    On Error Resume Next
    conn.BeginTrans

    If action = "create" Then
        ' --- INSERT -----------------------------------------------------------
        sqlText = "SET NOCOUNT ON; " & _
                  "INSERT INTO dbo.TBL_SONG (SONG_NAME, SONG_PATH, PLAYS) VALUES (?, ?, ?); " & _
                  "SELECT CAST(SCOPE_IDENTITY() AS int) AS NEW_ID;"
        Set rsNew = OpenRecordset(conn, sqlText, Array(songName, songPath, plays))
        newId = 0
        If Err.Number = 0 Then
            If Not rsNew.EOF Then newId = SafeInt(rsNew("NEW_ID"), 0)
            CloseRs rsNew
        End If
        songId = newId
    Else
        ' --- UPDATE -----------------------------------------------------------
        sqlText = "SET NOCOUNT ON; " & _
                  "UPDATE dbo.TBL_SONG SET SONG_NAME = ?, SONG_PATH = ?, PLAYS = ? WHERE ID_SONG = ?;"
        ExecNonQuery conn, sqlText, Array(songName, songPath, plays, songId)
    End If

    If Err.Number = 0 And songId > 0 Then

        ' --- Relación con ÁLBUM (TBL_TRACKLIST) ------------------------------
        ' El formulario gestiona un álbum principal por pista: se limpian los
        ' vínculos previos y se inserta el seleccionado (si lo hay).
        ExecNonQuery conn, "SET NOCOUNT ON; DELETE FROM dbo.TBL_TRACKLIST WHERE ID_SONG = ?;", Array(songId)
        If Err.Number = 0 And albumId > 0 Then
            ExecNonQuery conn, "SET NOCOUNT ON; INSERT INTO dbo.TBL_TRACKLIST (ID_ALBUM, ID_SONG) VALUES (?, ?);", Array(albumId, songId)
        End If

        ' --- Relación con ARTISTA (TBL_PLAYER) ------------------------------
        If Err.Number = 0 Then
            ExecNonQuery conn, "SET NOCOUNT ON; DELETE FROM dbo.TBL_PLAYER WHERE ID_SONG = ?;", Array(songId)
            If Err.Number = 0 And artistId > 0 Then
                ExecNonQuery conn, "SET NOCOUNT ON; INSERT INTO dbo.TBL_PLAYER (ID_SONG, ID_ARTIST) VALUES (?, ?);", Array(songId, artistId)
            End If
        End If
    End If

    If Err.Number <> 0 Then
        dbError = Err.Description
        Err.Clear
        conn.RollbackTrans
    Else
        conn.CommitTrans
        okFlag = True
    End If
    On Error GoTo 0

    CloseConn conn

    ' -------------------------------------------------------------------------
    '  5. Resultado
    ' -------------------------------------------------------------------------
    If okFlag Then
        If action = "create" Then
            SetFlash "Canción «" & songName & "» añadida al catálogo.", "success"
        Else
            SetFlash "Canción «" & songName & "» actualizada correctamente.", "success"
        End If
    Else
        If DEBUG_MODE Then
            SetFlash "No se pudo guardar la canción. Detalle: " & dbError, "error"
        Else
            SetFlash "No se pudo guardar la canción. Inténtalo de nuevo.", "error"
        End If
    End If

    Response.Redirect "songs.asp"
    Response.End
%>
