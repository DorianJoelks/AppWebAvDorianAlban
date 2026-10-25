<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · Default.asp
'  -----------------------------------------------------------------------------
'  Alias de entrada para IIS. "Default.asp" SÍ está en la lista nativa de
'  documentos predeterminados, mientras que "index.asp" no lo está.
'  Se mantiene como redirección para no duplicar la lógica de enrutamiento.
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    NoCache()

    Response.Redirect "index.asp"
    Response.End
%>
