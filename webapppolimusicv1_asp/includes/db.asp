<%
' =============================================================================
'  PoliMusic · includes/db.asp
'  Capa de acceso a datos sobre ADODB (SQL Server).
' -----------------------------------------------------------------------------
'  Reglas de la capa:
'    · TODAS las consultas con datos de usuario usan parámetros (?), nunca
'      concatenación de cadenas → previene inyección SQL.
'    · Los parámetros se añaden en el MISMO orden en que aparecen los "?".
'    · Las conexiones y recordsets siempre se cierran (CloseConn / CloseRs).
' =============================================================================

' -----------------------------------------------------------------------------
'  Cadena de conexión construida a partir de includes/config.asp
' -----------------------------------------------------------------------------
Function BuildConnectionString()
    BuildConnectionString = "Provider=" & DB_PROVIDER & ";" & _
                            "Server=" & DB_SERVER & ";" & _
                            "Database=" & DB_NAME & ";" & _
                            "UID=" & DB_USER & ";" & _
                            "PWD=" & DB_PASSWORD & ";" & _
                            "TrustServerCertificate=Yes;" & _
                            "Persist Security Info=False;"
End Function

' -----------------------------------------------------------------------------
'  Abre una conexión. Devuelve Nothing si falla y deja el motivo en outError.
'  (Se usa en las páginas para poder mostrar un error amable en lugar de
'   una traza de IIS.)
' -----------------------------------------------------------------------------
Function TryOpenConnection(ByRef outError)
    Dim conn

    outError = ""
    Set TryOpenConnection = Nothing

    On Error Resume Next
    Set conn = Server.CreateObject("ADODB.Connection")
    If Err.Number <> 0 Then
        outError = "No se pudo crear el objeto ADODB.Connection: " & Err.Description
        Err.Clear
        On Error GoTo 0
        Exit Function
    End If

    conn.ConnectionTimeout = 10
    conn.CommandTimeout = 30

    ' CursorLocation = 3 (adUseClient): los recordsets se materializan en el
    ' cliente y la conexión queda libre de inmediato. Sin esto, mantener dos
    ' recordsets abiertos sobre la misma conexión provoca el error
    ' "Connection is busy with results for another command" (MARS desactivado).
    conn.CursorLocation = 3

    conn.Open BuildConnectionString()

    If Err.Number <> 0 Then
        outError = "No se pudo conectar con """ & DB_NAME & """ en """ & DB_SERVER & """. " & _
                   "Detalle: " & Err.Description
        Err.Clear
        Set conn = Nothing
        On Error GoTo 0
        Exit Function
    End If

    On Error GoTo 0
    Set TryOpenConnection = conn
End Function

' -----------------------------------------------------------------------------
'  Añade un parámetro al comando infiriendo el tipo a partir del valor.
'  Tipos ADO: adInteger = 3, adVarWChar = 202, adParamInput = 1
' -----------------------------------------------------------------------------
Sub AddParam(ByRef cmd, ByVal pName, ByVal pValue)
    Const adInteger   = 3
    Const adVarWChar  = 202
    Const adParamInput = 1

    Dim v, vt

    If IsNull(pValue) Or IsEmpty(pValue) Then
        cmd.Parameters.Append cmd.CreateParameter(pName, adVarWChar, adParamInput, 4000, "")
        Exit Sub
    End If

    vt = VarType(pValue)
    If vt = vbInteger Or vt = vbLong Or vt = vbSingle Or vt = vbDouble Or vt = vbCurrency Then
        cmd.Parameters.Append cmd.CreateParameter(pName, adInteger, adParamInput, , CLng(pValue))
    Else
        v = CStr(pValue)
        If Len(v) > 4000 Then v = Left(v, 4000)
        cmd.Parameters.Append cmd.CreateParameter(pName, adVarWChar, adParamInput, 4000, v)
    End If
End Sub

' -----------------------------------------------------------------------------
'  Crea un ADODB.Command listo para ejecutar.
' -----------------------------------------------------------------------------
Function BuildCommand(ByRef conn, ByVal sql, ByVal prmValues)
    Dim cmd, i

    Set cmd = Server.CreateObject("ADODB.Command")
    Set cmd.ActiveConnection = conn
    cmd.CommandType = 1          ' adCmdText
    cmd.CommandTimeout = 30
    cmd.CommandText = sql

    If IsArray(prmValues) Then
        For i = 0 To UBound(prmValues)
            AddParam cmd, "p" & i, prmValues(i)
        Next
    End If

    Set BuildCommand = cmd
End Function

' -----------------------------------------------------------------------------
'  Ejecuta una consulta SELECT y devuelve el Recordset abierto.
'  Uso:  Set rs = OpenRecordset(conn, "SELECT ... WHERE ID = ?", Array(5))
'        Set rs = OpenRecordset(conn, "SELECT ...", Empty)   ' sin parámetros
' -----------------------------------------------------------------------------
Function OpenRecordset(ByRef conn, ByVal sql, ByVal prmValues)
    Dim cmd
    Set cmd = BuildCommand(conn, sql, prmValues)
    Set OpenRecordset = cmd.Execute
End Function

' -----------------------------------------------------------------------------
'  Ejecuta INSERT / UPDATE / DELETE sin devolver filas.
' -----------------------------------------------------------------------------
Sub ExecNonQuery(ByRef conn, ByVal sql, ByVal prmValues)
    Dim cmd
    Set cmd = BuildCommand(conn, sql, prmValues)
    cmd.Execute , , 128          ' 128 = adExecuteNoRecords
    Set cmd = Nothing
End Sub

' -----------------------------------------------------------------------------
'  Devuelve el primer campo de la primera fila (o defaultValue si no hay filas).
' -----------------------------------------------------------------------------
Function QueryValue(ByRef conn, ByVal sql, ByVal prmValues, ByVal defaultValue)
    Dim rs, result

    result = defaultValue
    Set rs = OpenRecordset(conn, sql, prmValues)
    If Not rs Is Nothing Then
        If Not rs.EOF Then
            If Not IsNull(rs(0).Value) Then result = rs(0).Value
        End If
        rs.Close
        Set rs = Nothing
    End If

    QueryValue = result
End Function

' -----------------------------------------------------------------------------
'  Cierre seguro de recordsets y conexiones
' -----------------------------------------------------------------------------
Sub CloseRs(ByRef rs)
    On Error Resume Next
    If IsObject(rs) Then
        If Not (rs Is Nothing) Then
            If rs.State <> 0 Then rs.Close
            Set rs = Nothing
        End If
    End If
    Err.Clear
    On Error GoTo 0
End Sub

Sub CloseConn(ByRef conn)
    On Error Resume Next
    If IsObject(conn) Then
        If Not (conn Is Nothing) Then
            If conn.State <> 0 Then conn.Close
            Set conn = Nothing
        End If
    End If
    Err.Clear
    On Error GoTo 0
End Sub
%>
