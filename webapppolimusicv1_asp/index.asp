<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · index.asp
'  Punto de entrada del sitio: enruta según el estado de la sesión.
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    NoCache()

    If TrimStr(Session("UserName")) = "" Then
        Response.Redirect "login.asp"
    Else
        Response.Redirect "songs.asp"
    End If
    Response.End
%>
