<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/db.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · song_delete.asp
'  Baja de una canción. Solo rol "admin".
' -----------------------------------------------------------------------------
'  El esquema declara claves foráneas sobre TBL_TRACKLIST, TBL_PLAYER y
'  TBL_PLAYLIST_SONG, por lo que primero se eliminan las filas dependientes
'  y por último la pista en TBL_SONG. Todo dentro de una transacción.
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    Session.CodePage  = 65001

    RequireLogin()
    RequireAdmin()
    NoCache()

    Dim conn, connError
    Dim songId, songName, deletedRows
    Dim dbError, okFlag

    If Not IsPost() Then
        Response.Redirect "songs.asp"
        Response.End
    End If

    ValidateCsrf()

    songId = SafeInt(Request.Form("id"), 0)

    If songId <= 0 Then
        SetFlash "No se indicó una canción válida para eliminar.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If

    Set conn = TryOpenConnection(connError)
    If conn Is Nothing Then
        SetFlash "No se pudo conectar con la base de datos.", "error"
        Response.Redirect "songs.asp"
        Response.End
    End If

    ' Nombre de la pista para el mensaje de confirmación
    songName = TrimStr(QueryValue(conn, _
        "SET NOCOUNT ON; SELECT SONG_NAME FROM dbo.TBL_SONG WHERE ID_SONG = ?;", _
        Array(songId), ""))

    If Len(songName) = 0 Then
        CloseConn conn
        SetFlash "La canción ya no existe en el catálogo.", "info"
        Response.Redirect "songs.asp"
        Response.End
    End If

    okFlag  = False
    dbError = ""

    On Error Resume Next
    conn.BeginTrans

    ' 1) Vínculos con playlists
    ExecNonQuery conn, "SET NOCOUNT ON; DELETE FROM dbo.TBL_PLAYLIST_SONG WHERE ID_SONG = ?;", Array(songId)

    ' 2) Vínculos con álbumes
    If Err.Number = 0 Then
        ExecNonQuery conn, "SET NOCOUNT ON; DELETE FROM dbo.TBL_TRACKLIST WHERE ID_SONG = ?;", Array(songId)
    End If

    ' 3) Vínculos con artistas
    If Err.Number = 0 Then
        ExecNonQuery conn, "SET NOCOUNT ON; DELETE FROM dbo.TBL_PLAYER WHERE ID_SONG = ?;", Array(songId)
    End If

    ' 4) La pista
    If Err.Number = 0 Then
        ExecNonQuery conn, "SET NOCOUNT ON; DELETE FROM dbo.TBL_SONG WHERE ID_SONG = ?;", Array(songId)
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

    If okFlag Then
        SetFlash "Canción «" & songName & "» eliminada del catálogo.", "success"
    Else
        If DEBUG_MODE Then
            SetFlash "No se pudo eliminar la canción. Detalle: " & dbError, "error"
        Else
            SetFlash "No se pudo eliminar la canción. Inténtalo de nuevo.", "error"
        End If
    End If

    Response.Redirect "songs.asp"
    Response.End
%>
