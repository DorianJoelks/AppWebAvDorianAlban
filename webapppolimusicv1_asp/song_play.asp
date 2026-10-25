<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/db.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · song_play.asp
'  Endpoint ligero (JSON) que incrementa el contador TBL_SONG.PLAYS cuando el
'  reproductor inicia una pista. Se invoca desde player.js con fetch().
'
'  Respuesta: { "ok": true, "plays": 12 }   |   { "ok": false, "error": "..." }
' =============================================================================
    Response.CodePage    = 65001
    Response.CharSet     = "utf-8"
    Response.ContentType = "application/json"
    Session.CodePage     = 65001

    Dim conn, connError, songId, newPlays, payload

    ' --- Sesión obligatoria: sin login no se contabiliza nada -----------------
    If TrimStr(Session("UserName")) = "" Then
        Response.Status = "401 Unauthorized"
        Response.Write "{""ok"":false,""error"":""session_expired""}"
        Response.End
    End If

    If Not IsPost() Then
        Response.Status = "405 Method Not Allowed"
        Response.Write "{""ok"":false,""error"":""method_not_allowed""}"
        Response.End
    End If

    songId = SafeInt(Request.Form("id"), 0)
    If songId <= 0 Then
        Response.Status = "400 Bad Request"
        Response.Write "{""ok"":false,""error"":""invalid_id""}"
        Response.End
    End If

    Set conn = TryOpenConnection(connError)
    If conn Is Nothing Then
        Response.Status = "503 Service Unavailable"
        Response.Write "{""ok"":false,""error"":""db_unavailable""}"
        Response.End
    End If

    On Error Resume Next
    ExecNonQuery conn, _
        "SET NOCOUNT ON; UPDATE dbo.TBL_SONG SET PLAYS = ISNULL(PLAYS, 0) + 1 WHERE ID_SONG = ?;", _
        Array(songId)

    If Err.Number <> 0 Then
        Err.Clear
        On Error GoTo 0
        CloseConn conn
        Response.Status = "500 Internal Server Error"
        Response.Write "{""ok"":false,""error"":""update_failed""}"
        Response.End
    End If
    On Error GoTo 0

    newPlays = SafeInt(QueryValue(conn, _
        "SET NOCOUNT ON; SELECT ISNULL(PLAYS, 0) FROM dbo.TBL_SONG WHERE ID_SONG = ?;", _
        Array(songId), 0), 0)

    CloseConn conn

    payload = "{""ok"":true,""id"":" & songId & ",""plays"":" & newPlays & "}"
    Response.Write payload
    Response.End
%>
