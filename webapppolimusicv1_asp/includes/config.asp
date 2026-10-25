<%
' =============================================================================
'  PoliMusic · includes/config.asp
'  Configuración central, constantes de entorno y utilidades compartidas.
'  Classic ASP / VBScript  ·  ADODB
' -----------------------------------------------------------------------------
'  IMPORTANTE: este archivo se incluye desde TODAS las páginas mediante la
'  directiva #include de ASP. No debe emitir ni un solo carácter de salida HTML.
'  (No escribas la directiva de forma literal en un comentario: el motor SSI de
'  IIS la procesa como texto plano y rompería la compilación con un error 500.)
' =============================================================================

Response.Buffer = True

' -----------------------------------------------------------------------------
'  1. Identidad de la aplicación
' -----------------------------------------------------------------------------
Const APP_NAME      = "PoliMusic"
Const APP_TAGLINE   = "Tu música, tu catálogo."

' -----------------------------------------------------------------------------
'  2. Conexión a SQL Server  (ajustar al entorno de despliegue)
' -----------------------------------------------------------------------------
Const DB_SERVER     = "localhost"          ' ej. "localhost\SQLEXPRESS" | "192.168.1.10,1433"
Const DB_NAME       = "BDD_PoliMusic"
Const DB_USER       = "usr_polimusic"
Const DB_PASSWORD   = "Politecnica1"
Const DB_PROVIDER   = "MSOLEDBSQL"         ' Recomendado (SQL Server 2012+).
                                           ' Alternativa legacy: "SQLOLEDB"

' -----------------------------------------------------------------------------
'  3. Rutas de recursos multimedia
'     La carpeta física vive en la raíz del sitio; las rutas de la BDD usan
'     el formato virtual "~/songFiles/xxx.mp3" y se traducen con
'     VirtualToWebPath().
' -----------------------------------------------------------------------------
Const ASSETS_FOLDER     = "SongFilesAndImages_resources"
Const DEFAULT_COVER     = "SongFilesAndImages_resources/PlaylistImages/default.jpg"
Const DEFAULT_USER_IMG  = "SongFilesAndImages_resources/UserImages/default.jpg"
Const PLAYLIST_COVERS   = 5                ' playlist1.png ... playlist5.png

' -----------------------------------------------------------------------------
'  4. Seguridad y sesión
' -----------------------------------------------------------------------------
Const SESSION_TIMEOUT_MIN = 30             ' minutos de inactividad
Const MAX_LOGIN_ATTEMPTS  = 5              ' intentos fallidos antes del bloqueo
Const LOGIN_LOCK_SECONDS  = 60             ' duración del bloqueo temporal
Const DEBUG_MODE          = True           ' ← False en producción (oculta detalles)

' -----------------------------------------------------------------------------
'  5. Utilidades de saneamiento y formato
' -----------------------------------------------------------------------------

' Codifica texto para insertarlo en HTML o en un atributo.
' Server.HTMLEncode ya convierte  &  <  >  "  en entidades seguras.
Function H(ByVal value)
    If IsNull(value) Then
        H = ""
    ElseIf IsEmpty(value) Then
        H = ""
    Else
        H = Server.HTMLEncode(CStr(value))
    End If
End Function

' Devuelve un entero seguro: si el valor no es numérico usa el valor por defecto.
Function SafeInt(ByVal value, ByVal fallback)
    Dim dbl
    SafeInt = fallback
    If IsNull(value) Or IsEmpty(value) Then Exit Function
    If Not IsNumeric(value) Then Exit Function
    dbl = CDbl(value)
    If dbl < -2147483648 Or dbl > 2147483647 Then Exit Function
    SafeInt = CLng(dbl)
End Function

' Texto recortado y sin nulos.
Function TrimStr(ByVal value)
    If IsNull(value) Or IsEmpty(value) Then
        TrimStr = ""
    Else
        TrimStr = Trim(CStr(value))
    End If
End Function

' Valor de un campo del formulario POST, ya recortado.
Function PostStr(ByVal fieldName)
    PostStr = TrimStr(Request.Form(fieldName))
End Function

' ¿La petición actual es un POST?
Function IsPost()
    IsPost = (UCase(TrimStr(Request.ServerVariables("REQUEST_METHOD"))) = "POST")
End Function

' Formatea una duración en segundos como m:ss (o h:mm:ss si supera la hora).
Function FormatDuration(ByVal totalSeconds)
    Dim s, m, hh
    s = SafeInt(totalSeconds, 0)
    If s < 0 Then s = 0
    hh = s \ 3600
    m = (s Mod 3600) \ 60
    s = s Mod 60
    If hh > 0 Then
        FormatDuration = hh & ":" & Right("0" & m, 2) & ":" & Right("0" & s, 2)
    Else
        FormatDuration = m & ":" & Right("0" & s, 2)
    End If
End Function

' Separador de miles con punto (convención es-EC).
Function FormatCount(ByVal value)
    Dim n, s, i, outStr, digitCount
    n = SafeInt(value, 0)
    If n < 0 Then n = 0
    s = CStr(n)
    outStr = ""
    digitCount = 0
    For i = Len(s) To 1 Step -1
        outStr = Mid(s, i, 1) & outStr
        digitCount = digitCount + 1
        If (digitCount Mod 3 = 0) And (i > 1) Then outStr = "." & outStr
    Next
    FormatCount = outStr
End Function

' -----------------------------------------------------------------------------
'  6. Traducción de rutas virtuales de la BDD  →  rutas web reales
'     "~/songFiles/bensound-adventure.mp3"
'        →  "SongFilesAndImages_resources/SongFiles/bensound-adventure.mp3"
'     El esquema usa nombres de carpeta inconsistentes y con mayúsculas
'     mezcladas, por eso se normaliza contra una tabla de equivalencias.
' -----------------------------------------------------------------------------
Function VirtualToWebPath(ByVal virtualPath)
    Dim p, folderOriginal, folder, fileName, slashPos

    p = TrimStr(virtualPath)
    VirtualToWebPath = ""
    If Len(p) = 0 Then Exit Function

    ' Normalizar separadores y quitar el prefijo de raíz virtual
    p = Replace(p, "\", "/")
    If Left(p, 2) = "~/" Then p = Mid(p, 3)
    If Left(p, 1) = "/"  Then p = Mid(p, 2)
    If Len(p) = 0 Then Exit Function

    slashPos = InStrRev(p, "/")
    If slashPos > 0 Then
        folderOriginal = Mid(p, 1, slashPos - 1)
        fileName       = Mid(p, slashPos + 1)
    Else
        folderOriginal = ""
        fileName       = p
    End If

    ' Mapa de carpetas: clave en minúsculas → carpeta física real
    Select Case LCase(folderOriginal)
        Case "songfiles", "songs"          : folder = "SongFiles"
        Case "playlistimages", "playlists" : folder = "PlaylistImages"
        Case "userimages", "users"         : folder = "UserImages"
        Case "albumimages", "albums"       : folder = "AlbumImages"
        Case "artistimages", "artists"     : folder = "ArtistImages"
        Case ""                            : folder = ""
        Case Else                          : folder = folderOriginal
    End Select

    If Len(folder) > 0 Then
        VirtualToWebPath = ASSETS_FOLDER & "/" & folder & "/" & fileName
    Else
        VirtualToWebPath = ASSETS_FOLDER & "/" & fileName
    End If
End Function

' Comprueba que un archivo exista realmente en disco (evita imágenes rotas).
Function WebAssetExists(ByVal webPath)
    Dim fso, physical

    WebAssetExists = False
    If Len(TrimStr(webPath)) = 0 Then Exit Function

    On Error Resume Next
    Set fso = Server.CreateObject("Scripting.FileSystemObject")
    physical = Server.MapPath(webPath)
    If Err.Number = 0 Then
        If fso.FileExists(physical) Then WebAssetExists = True
    End If
    Err.Clear
    Set fso = Nothing
    On Error GoTo 0
End Function

' Devuelve la ruta si el archivo existe; en caso contrario, el fallback.
Function ResolveAsset(ByVal webPath, ByVal fallbackPath)
    If WebAssetExists(webPath) Then
        ResolveAsset = webPath
    Else
        ResolveAsset = fallbackPath
    End If
End Function

' Carátula de una canción:
'   1) imagen del álbum si el archivo existe,
'   2) si no, una carátula estable derivada del ID (playlist1..5),
'   3) si no, la imagen por defecto.
Function CoverForSong(ByVal idSong, ByVal albumImagePath)
    Dim candidate, idx

    candidate = VirtualToWebPath(albumImagePath)
    If Len(candidate) > 0 Then
        If WebAssetExists(candidate) Then
            CoverForSong = candidate
            Exit Function
        End If
    End If

    idx = ((SafeInt(idSong, 1) - 1) Mod PLAYLIST_COVERS) + 1
    candidate = ASSETS_FOLDER & "/PlaylistImages/playlist" & idx & ".png"
    If WebAssetExists(candidate) Then
        CoverForSong = candidate
    Else
        CoverForSong = DEFAULT_COVER
    End If
End Function

' Avatar del usuario con fallback.
Function AvatarForUser(ByVal photoPath)
    Dim candidate
    candidate = VirtualToWebPath(photoPath)
    AvatarForUser = ResolveAsset(candidate, DEFAULT_USER_IMG)
End Function

' Iniciales para el avatar de respaldo (máx. 2 caracteres).
Function InitialsOf(ByVal fullName)
    Dim parts, outStr
    outStr = ""
    parts = Split(TrimStr(fullName), " ")
    If UBound(parts) >= 0 Then outStr = Left(parts(0), 1)
    If UBound(parts) >= 1 Then outStr = outStr & Left(parts(UBound(parts)), 1)
    InitialsOf = UCase(outStr)
End Function

' -----------------------------------------------------------------------------
'  7. Género musical
'     El esquema de referencia (BDD_PoliMusic.sql) NO define un campo de género
'     en TBL_SONG, por lo que se deriva del álbum al que pertenece la pista.
'     Si en el futuro se agrega TBL_SONG.GENRE, basta con reemplazar esta
'     función por la lectura directa del campo.
' -----------------------------------------------------------------------------
Function GenreFromAlbum(ByVal albumTitle)
    Dim t
    t = LCase(TrimStr(albumTitle))

    Select Case True
        Case Len(t) = 0               : GenreFromAlbum = "—"
        Case InStr(t, "rock") > 0     : GenreFromAlbum = "Rock"
        Case InStr(t, "relax") > 0    : GenreFromAlbum = "Chill"
        Case InStr(t, "retro") > 0    : GenreFromAlbum = "Retro"
        Case InStr(t, "classic") > 0  : GenreFromAlbum = "Clásica"
        Case InStr(t, "country") > 0  : GenreFromAlbum = "Country"
        Case Else                     : GenreFromAlbum = "Contemporánea"
    End Select
End Function

' -----------------------------------------------------------------------------
'  8. Inventario de archivos .mp3 disponibles (para el formulario de alta)
' -----------------------------------------------------------------------------
Function ListSongFiles()
    Dim fso, folder, f, arr(), n

    n = 0
    ReDim arr(0)

    On Error Resume Next
    Set fso = Server.CreateObject("Scripting.FileSystemObject")
    Set folder = fso.GetFolder(Server.MapPath(ASSETS_FOLDER & "/SongFiles"))
    If Err.Number = 0 Then
        For Each f In folder.Files
            If LCase(fso.GetExtensionName(f.Name)) = "mp3" Then
                ReDim Preserve arr(n)
                arr(n) = f.Name
                n = n + 1
            End If
        Next
    End If
    Err.Clear
    Set folder = Nothing
    Set fso = Nothing
    On Error GoTo 0

    If n = 0 Then
        ListSongFiles = Array()
    Else
        ReDim Preserve arr(n - 1)
        ListSongFiles = arr
    End If
End Function

' -----------------------------------------------------------------------------
'  9. Página de error controlada (nunca expone trazas al usuario final)
' -----------------------------------------------------------------------------
Sub RenderFatal(ByVal title, ByVal detail)
    Response.Clear
    Response.Write "<!DOCTYPE html>" & vbCrLf
    Response.Write "<html lang=""es""><head><meta charset=""utf-8"">" & vbCrLf
    Response.Write "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">" & vbCrLf
    Response.Write "<title>" & H(APP_NAME) & " · Error</title>" & vbCrLf
    Response.Write "<link rel=""stylesheet"" href=""styles.css""></head>" & vbCrLf
    Response.Write "<body class=""page-fatal"">" & vbCrLf
    Response.Write "<main class=""fatal-card"">" & vbCrLf
    Response.Write "<span class=""fatal-badge"">Error del servidor</span>" & vbCrLf
    Response.Write "<h1>" & H(title) & "</h1>" & vbCrLf
    Response.Write "<p class=""fatal-text"">La aplicación no pudo completar la operación solicitada.</p>" & vbCrLf
    If DEBUG_MODE Then
        Response.Write "<pre class=""fatal-detail"">" & H(detail) & "</pre>" & vbCrLf
    Else
        Response.Write "<p class=""fatal-text"">Contacta al administrador del sistema.</p>" & vbCrLf
    End If
    Response.Write "<a class=""btn btn-wine"" href=""login.asp"">Volver al inicio</a>" & vbCrLf
    Response.Write "</main></body></html>"
    Response.End
End Sub
%>
