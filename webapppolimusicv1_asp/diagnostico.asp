<%@ LANGUAGE="VBSCRIPT" CODEPAGE="65001" %>
<%
' =============================================================================
'  PoliMusic · diagnostico.asp
'  -----------------------------------------------------------------------------
'  Página AUTÓNOMA (no usa #include ni la capa de datos del proyecto) para
'  verificar el despliegue en IIS cuando una página .asp devuelve 500.
'
'  Uso:   http://localhost:84/diagnostico.asp
'  Bórrala cuando termines de desplegar.
' =============================================================================
Response.CodePage = 65001
Response.CharSet  = "utf-8"
Response.Buffer   = True

Dim fso, basePath, includesOk, f, faltantes
Dim prov, cTest, provOk, conn, cs, rs, total, dbOk
Dim folderSongs, countMp3

Set fso = Server.CreateObject("Scripting.FileSystemObject")

' Server.MapPath("./") NO devuelve barra final: se normaliza para poder
' concatenar nombres de archivo sin generar rutas como "..._aspincludes".
basePath = Server.MapPath("./")
If Right(basePath, 1) <> "\" Then basePath = basePath & "\"

' Escribe una fila de la tabla de resultados.
Sub Row(ByVal kind, ByVal label, ByVal detail)
    Response.Write "<tr><td><span class=""tag " & kind & """>" & label & "</span></td><td>" & detail & "</td></tr>" & vbCrLf
End Sub
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>PoliMusic · Diagnóstico de despliegue</title>
    <style>
        body { margin: 0; padding: 32px; background: #0A0A0A; color: #fff;
               font-family: "Segoe UI", system-ui, Arial, sans-serif; }
        h1 { font-size: 1.5rem; margin: 0 0 4px; letter-spacing: -.02em; }
        p.sub { color: #B3B3B3; margin: 0 0 24px; font-size: .875rem; }
        table { width: 100%; border-collapse: collapse; background: #121212;
                border: 1px solid #2A2A2A; border-radius: 10px; overflow: hidden; }
        th, td { padding: 11px 14px; text-align: left; font-size: .875rem;
                 border-bottom: 1px solid #232323; vertical-align: top; }
        th { background: rgba(128, 0, 32, .25); color: #E8B4C6; font-size: .7rem;
             text-transform: uppercase; letter-spacing: .08em; }
        tr:last-child td { border-bottom: 0; }
        .tag { display: inline-block; padding: 2px 9px; border-radius: 999px;
               font-size: .7rem; font-weight: 800; letter-spacing: .05em; }
        .ok    { background: rgba(74, 222, 128, .14);  color: #86EFAC; }
        .error { background: rgba(248, 113, 113, .14); color: #FCA5A5; }
        .aviso { background: rgba(201, 162, 39, .14);  color: #E0C060; }
        .ayuda { background: rgba(255, 255, 255, .08); color: #B3B3B3; }
        code { background: rgba(255, 255, 255, .08); padding: 1px 5px; border-radius: 4px;
               font-family: Consolas, monospace; font-size: .85em; color: #E8B4C6; }
        .foot { margin-top: 20px; color: #5C5C5C; font-size: .75rem; }
    </style>
</head>
<body>
    <h1>Diagnóstico de despliegue · PoliMusic</h1>
    <p class="sub">Ruta física: <code><%= Server.HTMLEncode(basePath) %></code> · Borra este archivo tras verificar.</p>

    <table>
        <thead>
            <tr><th style="width:110px">Estado</th><th>Comprobación</th></tr>
        </thead>
        <tbody>
<%
' --- 1. Entorno ASP ---------------------------------------------------------
Row "ok", "OK", "ASP en ejecución. Motor VBScript " & ScriptEngineMajorVersion & "." & ScriptEngineMinorVersion & "." & ScriptEngineBuildVersion

' --- 2. Estado de sesión ----------------------------------------------------
On Error Resume Next
Session("diag") = "1"
If Err.Number = 0 Then
    Row "ok", "OK", "Objeto Session disponible."
Else
    Row "error", "ERROR", "Session no disponible (" & Server.HTMLEncode(Err.Description) & "). Habilita el estado de sesión del sitio."
    Err.Clear
End If
On Error GoTo 0

' --- 3. Carpeta includes ----------------------------------------------------
If fso.FolderExists(basePath & "includes") Then
    faltantes = ""
    If Not fso.FileExists(basePath & "includes\config.asp") Then faltantes = faltantes & "config.asp "
    If Not fso.FileExists(basePath & "includes\db.asp") Then faltantes = faltantes & "db.asp "
    If Not fso.FileExists(basePath & "includes\auth.asp") Then faltantes = faltantes & "auth.asp "

    If faltantes = "" Then
        Row "ok", "OK", "Carpeta <code>\includes</code> completa."
    Else
        Row "error", "ERROR", "Faltan archivos en <code>\includes</code>: <code>" & faltantes & "</code>"
    End If
Else
    Row "error", "ERROR", "NO existe <code>" & Server.HTMLEncode(basePath) & "includes</code>. " & _
        "Todas las páginas .asp fallarán con 500 al no resolver el <code>#include</code>."
End If

' --- 4. Documento predeterminado -------------------------------------------
If fso.FileExists(basePath & "index.asp") Then
    Row "ok", "OK", "<code>index.asp</code> presente."
Else
    Row "error", "ERROR", "Falta <code>index.asp</code> en la raíz."
End If

If fso.FileExists(basePath & "web.config") Then
    Row "ok", "OK", "<code>web.config</code> presente: registra <code>index.asp</code> como documento predeterminado."
ElseIf fso.FileExists(basePath & "Default.asp") Then
    Row "aviso", "AVISO", "Sin <code>web.config</code>, pero <code>Default.asp</code> existe: la raíz funcionará igual."
Else
    Row "error", "ERROR", "Sin <code>web.config</code> ni <code>Default.asp</code>: <code>http://localhost:84/</code> devolverá 403.14."
End If

' --- 5. Recursos multimedia -------------------------------------------------
If fso.FolderExists(basePath & "SongFilesAndImages_resources") Then
    Row "ok", "OK", "Carpeta de recursos multimedia presente."
Else
    Row "error", "ERROR", "Falta <code>SongFilesAndImages_resources</code>."
End If

If fso.FolderExists(basePath & "SongFilesAndImages_resources\SongFiles") Then
    countMp3 = 0
    Set folderSongs = fso.GetFolder(basePath & "SongFilesAndImages_resources\SongFiles")
    For Each f In folderSongs.Files
        If LCase(fso.GetExtensionName(f.Name)) = "mp3" Then countMp3 = countMp3 + 1
    Next
    If countMp3 > 0 Then
        Row "ok", "OK", countMp3 & " archivo(s) .mp3 en <code>SongFiles</code>."
    Else
        Row "aviso", "AVISO", "No hay ningún .mp3 en <code>SongFiles</code>: el reproductor no tendrá audio."
    End If
End If

' --- 6. Proveedores OLE DB --------------------------------------------------
provOk = ""
For Each prov In Array("MSOLEDBSQL", "SQLOLEDB", "SQLNCLI11")
    On Error Resume Next
    Set cTest = Server.CreateObject("ADODB.Connection")
    cTest.Provider = prov
    If Err.Number = 0 Then
        If provOk = "" Then provOk = prov
        Row "ok", "OK", "Proveedor OLE DB disponible: <code>" & prov & "</code>"
    Else
        Row "aviso", "AVISO", "Proveedor no disponible: <code>" & prov & "</code>"
        Err.Clear
    End If
    Set cTest = Nothing
    On Error GoTo 0
Next

' --- 7. Conexión a la base de datos ----------------------------------------
dbOk = False
cs = "Provider=MSOLEDBSQL;Server=localhost;Database=BDD_PoliMusic;" & _
     "UID=usr_polimusic;PWD=Politecnica1;TrustServerCertificate=Yes;"

On Error Resume Next
Set conn = Server.CreateObject("ADODB.Connection")
conn.ConnectionTimeout = 8
conn.Open cs

If Err.Number <> 0 Then
    Row "error", "ERROR", "Fallo al conectar con <code>BDD_PoliMusic</code> en <code>localhost</code>: " & Server.HTMLEncode(Err.Description)
    Err.Clear
Else
    Set rs = conn.Execute("SELECT COUNT(*) AS TOTAL FROM dbo.TBL_SONG")
    total = rs("TOTAL")
    rs.Close
    Set rs = Nothing
    dbOk = True
    Row "ok", "OK", "Conexión correcta. <code>TBL_SONG</code> contiene " & total & " canciones."
End If
On Error GoTo 0

If Not dbOk Then
    Row "ayuda", "AYUDA", "Revisa en este orden: (1) instancia correcta " & _
        "(<code>localhost</code> vs <code>localhost\SQLEXPRESS</code>), " & _
        "(2) autenticación mixta de SQL Server habilitada, " & _
        "(3) script <code>BDD_PoliMusic.sql</code> ejecutado, " & _
        "(4) si el pool es de 32 bits, driver <code>MSOLEDBSQL</code> de 32 bits instalado."
End If

Set conn = Nothing
Set fso = Nothing
%>
        </tbody>
    </table>

    <p class="foot">
        Si esta página se muestra correctamente pero <code>login.asp</code> devuelve 500,
        el fallo está en los <code>#include</code> o en el código ASP, no en IIS.
    </p>
</body>
</html>
