<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="includes/config.asp" -->
<!--#include file="includes/db.asp" -->
<!--#include file="includes/auth.asp" -->
<%
' =============================================================================
'  PoliMusic · login.asp
'  Autenticación contra TBL_USER (SQL Server vía ADODB).
'  Al validar, guarda Session("UserName") y Session("UserRole") y redirige
'  a songs.asp.
' =============================================================================
    Response.CodePage = 65001
    Response.CharSet  = "utf-8"
    Session.CodePage  = 65001
    NoCache()

    Dim errorMsg, username, password
    Dim conn, connError, rsUser, sqlLogin
    Dim attempts, roleValue, roleStr, photoWeb
    Dim isValid

    ' --- Si ya hay una sesión activa, no tiene sentido mostrar el formulario ---
    If TrimStr(Session("UserName")) <> "" Then
        Response.Redirect "songs.asp"
        Response.End
    End If

    errorMsg = ""
    username = ""
    password = ""

    ' =========================================================================
    '  Procesamiento del POST
    ' =========================================================================
    If IsPost() Then

        username = PostStr("username")
        password = Request.Form("password") & ""

        ' --- Bloqueo temporal tras N intentos fallidos -----------------------
        attempts = SafeInt(Session("LoginAttempts"), 0)
        If attempts >= MAX_LOGIN_ATTEMPTS Then
            If IsDate(Session("LoginLockedAt")) Then
                If DateDiff("s", CDate(Session("LoginLockedAt")), Now()) < LOGIN_LOCK_SECONDS Then
                    errorMsg = "Demasiados intentos fallidos. Espera " & LOGIN_LOCK_SECONDS & " segundos."
                Else
                    Session("LoginAttempts") = 0
                    Session("LoginLockedAt") = ""
                End If
            Else
                Session("LoginAttempts") = 0
            End If
        End If

        If errorMsg = "" Then
            If Len(username) = 0 Or Len(password) = 0 Then
                errorMsg = "Introduce tu usuario y tu contraseña."
            ElseIf Len(username) > 50 Or Len(password) > 50 Then
                errorMsg = "Las credenciales superan la longitud permitida."
            Else
                ' --- Consulta parametrizada -----------------------------------
                ' Acepta contraseñas almacenadas en texto plano Y en SHA1 (hex),
                ' porque el seed de BDD_PoliMusic.sql mezcla ambos formatos.
                sqlLogin = "SET NOCOUNT ON; " & _
                           "SELECT TOP (1) u.ID_USER, u.USERNAME, u.USER_TYPE, u.USER_PHOTO, u.EMAIL, " & _
                           "       ISNULL(c.VALUE, 'USER') AS ROLE_VALUE " & _
                           "FROM dbo.TBL_USER AS u " & _
                           "LEFT JOIN dbo.TBL_CATALOG AS c " & _
                           "       ON c.COD_CATALOG_PARENT = '1' " & _
                           "      AND c.COD_CATALOG = CAST(u.USER_TYPE AS varchar(8)) " & _
                           "WHERE u.USERNAME = ? " & _
                           "  AND ( u.PASSWORD = ? " & _
                           "        OR UPPER(u.PASSWORD) = UPPER(CONVERT(varchar(40), HASHBYTES('SHA1', CONVERT(varchar(50), ?)), 2)) )"

                Set conn = TryOpenConnection(connError)

                If conn Is Nothing Then
                    errorMsg = "No se pudo conectar con la base de datos. Verifica el servicio de SQL Server."
                    If DEBUG_MODE Then errorMsg = errorMsg & " [" & connError & "]"
                Else
                    isValid = False

                    On Error Resume Next
                    Set rsUser = OpenRecordset(conn, sqlLogin, Array(username, password, password))
                    If Err.Number <> 0 Then
                        errorMsg = "Error al ejecutar la consulta de autenticación."
                        If DEBUG_MODE Then errorMsg = errorMsg & " [" & Err.Description & "]"
                        Err.Clear
                    ElseIf Not rsUser.EOF Then
                        isValid = True
                    End If
                    On Error GoTo 0

                    If isValid Then
                        ' --- Mapeo de rol: USER_TYPE 1 = ADMIN -----------------
                        roleValue = SafeInt(rsUser("USER_TYPE"), 0)
                        If roleValue = 1 Or UCase(TrimStr(rsUser("ROLE_VALUE"))) = "ADMIN" Then
                            roleStr = "admin"
                        Else
                            roleStr = "normal"
                        End If

                        photoWeb = AvatarForUser(rsUser("USER_PHOTO"))

                        Session("UserName")    = TrimStr(rsUser("USERNAME"))
                        Session("UserId")      = SafeInt(rsUser("ID_USER"), 0)
                        Session("UserRole")    = roleStr
                        Session("UserPhoto")   = photoWeb
                        Session("UserEmail")   = TrimStr(rsUser("EMAIL"))
                        Session("LoginAttempts") = 0
                        Session("LoginLockedAt") = ""
                        Session("CsrfToken")   = ""          ' se regenera por sesión
                        Session.Timeout        = SESSION_TIMEOUT_MIN

                        CloseRs rsUser
                        CloseConn conn

                        Response.Redirect "songs.asp"
                        Response.End
                    Else
                        ' --- Fallo de credenciales ----------------------------
                        Session("LoginAttempts") = attempts + 1
                        If Session("LoginAttempts") >= MAX_LOGIN_ATTEMPTS Then
                            Session("LoginLockedAt") = Now()
                        End If
                        errorMsg = "Usuario o contraseña incorrectos."
                        password = ""
                    End If

                    CloseRs rsUser
                    CloseConn conn
                End If
            End If
        End If
    End If
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="PoliMusic · Inicia sesión para acceder a tu catálogo musical.">
    <title><%= H(APP_NAME) %> · Iniciar sesión</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body class="page-login">

    <main class="login-wrap">

        <!-- Panel decorativo izquierdo (solo escritorio) -->
        <section class="login-art" aria-hidden="true">
            <div class="login-art__glow"></div>
            <div class="login-art__content">
                <p class="login-art__eyebrow">Catálogo musical</p>
                <h2 class="login-art__title">Tu música.<br>Tu catálogo.</h2>
                <p class="login-art__text">
                    Explora el catálogo de PoliMusic, reproduce las pistas en streaming
                    y administra el repertorio si eres administrador.
                </p>
                <ul class="login-art__list">
                    <li>Reproductor continuo estilo Spotify</li>
                    <li>Catálogo sincronizado con SQL Server</li>
                    <li>Control de acceso por roles</li>
                </ul>
            </div>
        </section>

        <!-- Formulario -->
        <section class="login-panel">
            <header class="login-brand">
                <span class="brand-mark" aria-hidden="true">
                    <svg viewBox="0 0 32 32" width="28" height="28" fill="none">
                        <circle cx="16" cy="16" r="15" stroke="currentColor" stroke-width="2"/>
                        <path d="M13 21.5V10.8l8-1.6v9.4" stroke="currentColor" stroke-width="2"
                              stroke-linecap="round" stroke-linejoin="round"/>
                        <circle cx="11" cy="21.6" r="2.4" fill="currentColor"/>
                        <circle cx="19" cy="18.9" r="2.4" fill="currentColor"/>
                    </svg>
                </span>
                <span class="brand-name">Poli<span>Music</span></span>
            </header>

            <h1 class="login-title">Inicia sesión</h1>
            <p class="login-subtitle">Accede con tus credenciales institucionales.</p>

            <% If errorMsg <> "" Then %>
            <div class="alert alert-error" role="alert">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                    <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>
                    <path d="M12 7.5v5.5M12 16.4v.2" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                </svg>
                <span><%= H(errorMsg) %></span>
            </div>
            <% End If %>

            <form class="login-form" method="post" action="login.asp" autocomplete="on" novalidate>

                <div class="field">
                    <label for="username">Usuario</label>
                    <input  type="text"
                            id="username"
                            name="username"
                            class="input"
                            value="<%= H(username) %>"
                            placeholder="userAdmin"
                            maxlength="50"
                            autocomplete="username"
                            autofocus
                            required>
                </div>

                <div class="field">
                    <label for="password">Contraseña</label>
                    <div class="field-password">
                        <input  type="password"
                                id="password"
                                name="password"
                                class="input"
                                placeholder="••••••••"
                                maxlength="50"
                                autocomplete="current-password"
                                required>
                        <button type="button" class="password-toggle" data-toggle-password
                                aria-label="Mostrar u ocultar la contraseña" aria-pressed="false">
                            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" aria-hidden="true">
                                <path d="M2.5 12S6 5.8 12 5.8 21.5 12 21.5 12 18 18.2 12 18.2 2.5 12 2.5 12Z"
                                      stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
                                <circle cx="12" cy="12" r="2.8" stroke="currentColor" stroke-width="1.8"/>
                            </svg>
                        </button>
                    </div>
                </div>

                <button type="submit" class="btn btn-wine btn-block btn-lg">Entrar</button>
            </form>

            <footer class="login-foot">
                <p class="login-hint">
                    <strong>Credenciales de prueba:</strong>
                    <code>userAdmin / 12345678</code> (admin) ·
                    <code>userNormal / 12345678</code> (normal)
                </p>
                <p class="login-copy">&copy; <%= Year(Date()) %> <%= H(APP_NAME) %> · EPN</p>
            </footer>
        </section>

    </main>

    <script>
        /* Mostrar / ocultar contraseña — mejora de usabilidad del login. */
        (function () {
            var toggle = document.querySelector('[data-toggle-password]');
            var input  = document.getElementById('password');
            if (!toggle || !input) return;
            toggle.addEventListener('click', function () {
                var show = input.type === 'password';
                input.type = show ? 'text' : 'password';
                toggle.setAttribute('aria-pressed', show ? 'true' : 'false');
                input.focus();
            });
        })();
    </script>
</body>
</html>
