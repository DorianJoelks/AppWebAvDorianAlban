<%
' =============================================================================
'  PoliMusic · includes/auth.asp
'  Guardias de sesión, control de roles y protección CSRF.
' -----------------------------------------------------------------------------
'  Roles soportados (columna TBL_USER.USER_TYPE + TBL_CATALOG):
'     0  →  "normal"   (solo lectura / reproducción)
'     1  →  "admin"    (CRUD completo sobre el catálogo)
' =============================================================================

' -----------------------------------------------------------------------------
'  Exige sesión activa. Si no hay usuario, redirige a login.asp.
' -----------------------------------------------------------------------------
Sub RequireLogin()
    If TrimStr(Session("UserName")) = "" Then
        Response.Redirect "login.asp"
        Response.End
    End If
End Sub

' -----------------------------------------------------------------------------
'  ¿El usuario de la sesión es administrador?
' -----------------------------------------------------------------------------
Function IsAdmin()
    IsAdmin = (LCase(TrimStr(Session("UserRole"))) = "admin")
End Function

' -----------------------------------------------------------------------------
'  Exige rol admin. Se usa en las páginas de escritura (save / delete):
'  la comprobación en el servidor es la única que realmente protege los datos;
'  ocultar botones en el HTML es solo una mejora de experiencia de usuario.
' -----------------------------------------------------------------------------
Sub RequireAdmin()
    If Not IsAdmin() Then
        Response.Status = "403 Forbidden"
        Response.Write "<!DOCTYPE html><html lang=""es""><head><meta charset=""utf-8"">"
        Response.Write "<title>Acceso denegado</title>"
        Response.Write "<link rel=""stylesheet"" href=""styles.css""></head>"
        Response.Write "<body class=""page-fatal""><main class=""fatal-card"">"
        Response.Write "<span class=""fatal-badge"">403</span>"
        Response.Write "<h1>Acceso denegado</h1>"
        Response.Write "<p class=""fatal-text"">Tu rol no permite modificar el catálogo de canciones.</p>"
        Response.Write "<a class=""btn btn-wine"" href=""songs.asp"">Volver al catálogo</a>"
        Response.Write "</main></body></html>"
        Response.End
    End If
End Sub

' -----------------------------------------------------------------------------
'  Token CSRF por sesión (se incrusta en cada formulario de escritura)
' -----------------------------------------------------------------------------
Function NewToken()
    Dim i, s, chars
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
    s = ""
    Randomize
    For i = 1 To 32
        s = s & Mid(chars, Int(Rnd() * Len(chars)) + 1, 1)
    Next
    NewToken = s
End Function

Function CsrfToken()
    If TrimStr(Session("CsrfToken")) = "" Then
        Session("CsrfToken") = NewToken()
    End If
    CsrfToken = Session("CsrfToken")
End Function

' Valida el token recibido en el POST. Corta la ejecución si no coincide.
Sub ValidateCsrf()
    Dim sent, expected

    sent     = TrimStr(Request.Form("csrf"))
    expected = TrimStr(Session("CsrfToken"))

    If Len(expected) = 0 Or Len(sent) = 0 Then
        RejectCsrf
    End If
    If StrComp(sent, expected, vbBinaryCompare) <> 0 Then
        RejectCsrf
    End If
End Sub

Sub RejectCsrf()
    Response.Status = "400 Bad Request"
    Response.Write "<!DOCTYPE html><html lang=""es""><head><meta charset=""utf-8"">"
    Response.Write "<title>Sesión inválida</title>"
    Response.Write "<link rel=""stylesheet"" href=""styles.css""></head>"
    Response.Write "<body class=""page-fatal""><main class=""fatal-card"">"
    Response.Write "<span class=""fatal-badge"">400</span>"
    Response.Write "<h1>Formulario caducado</h1>"
    Response.Write "<p class=""fatal-text"">El token de seguridad no es válido. Recarga la página e inténtalo de nuevo.</p>"
    Response.Write "<a class=""btn btn-wine"" href=""songs.asp"">Volver al catálogo</a>"
    Response.Write "</main></body></html>"
    Response.End
End Sub

' -----------------------------------------------------------------------------
'  Mensajes flash (sobreviven a un redirect y se consumen una sola vez)
' -----------------------------------------------------------------------------
Sub SetFlash(ByVal message, ByVal kind)
    Session("FlashMessage") = message
    Session("FlashType")    = kind       ' "success" | "error" | "info"
End Sub

Function TakeFlash()
    TakeFlash = TrimStr(Session("FlashMessage"))
    Session("FlashMessage") = ""
End Function

Function TakeFlashType()
    Dim t
    t = LCase(TrimStr(Session("FlashType")))
    If t <> "success" And t <> "error" And t <> "info" Then t = "info"
    TakeFlashType = t
    Session("FlashType") = ""
End Function

' -----------------------------------------------------------------------------
'  Cabeceras para evitar el cacheo de páginas autenticadas
' -----------------------------------------------------------------------------
Sub NoCache()
    Response.Expires = -1
    Response.ExpiresAbsolute = #Jan 1, 1980#
    Response.AddHeader "Cache-Control", "no-store, no-cache, must-revalidate, private"
    Response.AddHeader "Pragma", "no-cache"
End Sub
%>
