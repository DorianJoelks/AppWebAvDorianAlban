<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · logout.asp
'  Destruye la sesión activa y devuelve al usuario a login.asp.
' -----------------------------------------------------------------------------
'  Se limpian explícitamente las variables de sesión antes de Session.Abandon()
'  porque Abandon() destruye la sesión al finalizar la petición, no de inmediato:
'  sin este paso, un redirect dentro de la misma página aún vería los valores.
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    Session.CodePage  = 65001
    NoCache()

    Session.Contents.RemoveAll()

    Session("UserName") = ""
    Session("UserRole") = ""

    Session.Abandon()

    Response.Redirect "login.asp"
    Response.End
%>
