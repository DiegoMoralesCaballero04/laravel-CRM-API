$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Ok($msg) { Write-Host "OK   $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL $msg" -ForegroundColor Red; $script:fallos++ }

function DetectarCompose {
  try { & docker compose version *> $null; return "compose" } catch {}
  try { & docker-compose version *> $null; return "docker-compose" } catch {}
  throw "No encuentro docker compose ni docker-compose. ¿Docker Desktop está arrancado?"
}

$script:composeFlavor = DetectarCompose

function Dc {
  $dcArgs = $args

  $argsArr = New-Object System.Collections.Generic.List[string]
  foreach ($a in $dcArgs) {
    if ($null -eq $a) { continue }
    if (($a -is [System.Array]) -and -not ($a -is [string])) {
      foreach ($x in $a) {
        if ($null -eq $x) { continue }
        $s = $x.ToString().Trim()
        if ($s -ne "") { [void]$argsArr.Add($s) }
      }
    } else {
      $s = $a.ToString().Trim()
      if ($s -ne "") { [void]$argsArr.Add($s) }
    }
  }

  if ($argsArr.Count -eq 0) { throw "Dc() llamado sin argumentos." }

  $tmpDir = $env:TEMP
  if ([string]::IsNullOrWhiteSpace($tmpDir)) { $tmpDir = [System.IO.Path]::GetTempPath() }

  $tmpOut = Join-Path $tmpDir ("dc_out_{0}.txt" -f ([guid]::NewGuid().ToString("N")))
  $tmpErr = Join-Path $tmpDir ("dc_err_{0}.txt" -f ([guid]::NewGuid().ToString("N")))

  try {
    if ($script:composeFlavor -eq "compose") {
      $dockerArgs = New-Object System.Collections.Generic.List[string]
      [void]$dockerArgs.Add("compose")
      foreach ($x in $argsArr) { [void]$dockerArgs.Add($x) }

      $p = Start-Process -FilePath "docker" -ArgumentList $dockerArgs.ToArray() -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    } else {
      $p = Start-Process -FilePath "docker-compose" -ArgumentList $argsArr.ToArray() -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    }

    $out = ""
    $err = ""

    if (Test-Path $tmpOut) {
      $rawOut = Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue
      if ($null -ne $rawOut) { $out = $rawOut.Trim() }
    }

    if (Test-Path $tmpErr) {
      $rawErr = Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue
      if ($null -ne $rawErr) { $err = $rawErr.Trim() }
    }

    if ($p.ExitCode -ne 0) {
      if ($err -ne "") { throw $err }
      if ($out -ne "") { throw $out }
      throw "docker devolvió código $($p.ExitCode)"
    }

    $combined = New-Object System.Collections.Generic.List[string]
    if ($out -ne "") { [void]$combined.Add($out) }
    if ($err -ne "") { [void]$combined.Add($err) }
    return ($combined -join "`n")
  }
  finally {
    if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tmpErr) { Remove-Item $tmpErr -Force -ErrorAction SilentlyContinue }
  }
}

function EsperarMysql([int]$segundosMax = 120) {
  $inicio = Get-Date
  while ($true) {
    try {
      Dc exec -T db mysqladmin ping -h 127.0.0.1 -uroot -proot --silent | Out-Null
      return
    } catch {
      if (((Get-Date) - $inicio).TotalSeconds -ge $segundosMax) { throw "MySQL no está listo tras $segundosMax segundos" }
      Start-Sleep -Seconds 2
    }
  }
}

function ObtenerTokenAdmin([int]$reintentos = 10, [int]$sleepSeg = 2) {
  for ($i = 1; $i -le $reintentos; $i++) {
    $raw = Dc exec -T app php artisan token:emit admin@demo.com
    $tokenLine = $null
    $lines = $raw -split "`r?`n"
    foreach ($ln in $lines) {
      $t = $ln.Trim()
      if ($t -match '^\d+\|[A-Za-z0-9]+') { $tokenLine = $t }
    }
    if ($tokenLine) { return $tokenLine }
    Start-Sleep -Seconds $sleepSeg
  }
  throw "No pude obtener un token válido tras $reintentos intentos."
}

function Trunc([string]$s, [int]$max = 2000) {
  if ($null -eq $s) { return "" }
  if ($s.Length -le $max) { return $s }
  return ($s.Substring(0, $max) + "`n...(truncado)...")
}

function ToPrettyJson($obj) {
  try { return ($obj | ConvertTo-Json -Depth 20) } catch { return "$obj" }
}

function MaskAuth($v) {
  if ($null -eq $v) { return $null }
  $s = "$v"
  if ($s -match '^Bearer\s+(.+)$') {
    $tok = $Matches[1]
    if ($tok.Length -le 16) { return "Bearer $tok" }
    return ("Bearer " + $tok.Substring(0,8) + "..." + $tok.Substring($tok.Length-6))
  }
  return $s
}

function PrintHttp([string]$title, [string]$method, [string]$url, [hashtable]$headers, [int]$statusCode, [string]$body) {
  Write-Host ""
  Write-Host ("--- {0} ---" -f $title) -ForegroundColor DarkCyan
  Write-Host ("REQUEST  {0} {1}" -f $method.ToUpper(), $url) -ForegroundColor Gray
  if ($headers) {
    $h2 = @{}
    foreach ($k in $headers.Keys) {
      if ($k -match '^(Authorization|Accept|Content-Type)$') {
        if ($k -eq "Authorization") { $h2[$k] = (MaskAuth $headers[$k]) } else { $h2[$k] = $headers[$k] }
      }
    }
    if ($h2.Count -gt 0) {
      Write-Host ("HEADERS  " + (ToPrettyJson $h2)) -ForegroundColor Gray
    }
  }
  Write-Host ("RESPONSE {0}" -f $statusCode) -ForegroundColor Gray
  if ($body -and $body.Trim() -ne "") { Write-Host (Trunc $body 2000) -ForegroundColor DarkGray } else { Write-Host "(sin body)" -ForegroundColor DarkGray }
  Write-Host "----------------" -ForegroundColor DarkCyan
}

function HttpGetWithDetails([string]$url, [hashtable]$headers) {
  $result = New-Object PSObject -Property @{ StatusCode = 0; Body = ""; Json = $null }
  try {
    $json = Invoke-RestMethod -Uri ([Uri]::new($url)) -Headers $headers -Method Get -TimeoutSec 60
    $result.StatusCode = 200
    $result.Json = $json
    $result.Body = ToPrettyJson $json
    return $result
  } catch {
    $resp = $_.Exception.Response
    if ($resp -ne $null) {
      try { $result.StatusCode = [int]$resp.StatusCode } catch { $result.StatusCode = 0 }
      try {
        $stream = $resp.GetResponseStream()
        if ($stream -ne $null) {
          $reader = New-Object System.IO.StreamReader($stream)
          $text = $reader.ReadToEnd()
          $reader.Close()
          if ($null -ne $text) { $result.Body = $text.Trim() } else { $result.Body = "" }
        }
      } catch {
        if ($null -eq $result.Body) { $result.Body = "" }
      }
      throw $result
    } else {
      $result.StatusCode = 0
      $result.Body = $_.Exception.Message
      throw $result
    }
  }
}

function BuildUrl([string]$baseUrl, [hashtable]$query) {
  Add-Type -AssemblyName System.Web | Out-Null
  $ub = New-Object System.UriBuilder($baseUrl)
  $q = [System.Web.HttpUtility]::ParseQueryString($ub.Query)
  foreach ($k in $query.Keys) {
    $v = $query[$k]
    if ($null -ne $v -and "$v".Trim() -ne "") { $q[$k] = "$v" }
  }
  $ub.Query = $q.ToString()
  return $ub.Uri.AbsoluteUri
}

function DebeFallarHttp([string]$nombre, [string]$url, [hashtable]$headers) {
  try {
    $res = HttpGetWithDetails $url $headers
    PrintHttp $nombre "GET" $url $headers $res.StatusCode $res.Body
    Fail "$nombre (debería fallar y no falló)"
  } catch {
    $err = $_
    $res = $null

    if ($err -and $err.TargetObject -and ($err.TargetObject.PSObject.Properties.Match("StatusCode").Count -gt 0)) {
      $res = $err.TargetObject
    } elseif ($err -and ($err.PSObject.Properties.Match("StatusCode").Count -gt 0)) {
      $res = $err
    }

    if ($res) {
      PrintHttp $nombre "GET" $url $headers $res.StatusCode $res.Body
      Ok $nombre
    } else {
      Fail "$nombre -> $($err.Exception.Message)"
    }
  }
}

function DebePasarHttp([string]$nombre, [string]$url, [hashtable]$headers, [scriptblock]$assert) {
  try {
    $res = HttpGetWithDetails $url $headers
    PrintHttp $nombre "GET" $url $headers $res.StatusCode $res.Body
    if ($assert) { & $assert $res }
    Ok $nombre
  } catch {
    $err = $_
    $res = $null

    if ($err -and $err.TargetObject -and ($err.TargetObject.PSObject.Properties.Match("StatusCode").Count -gt 0)) {
      $res = $err.TargetObject
    } elseif ($err -and ($err.PSObject.Properties.Match("StatusCode").Count -gt 0)) {
      $res = $err
    }

    if ($res) {
      PrintHttp $nombre "GET" $url $headers $res.StatusCode $res.Body
      Fail "$nombre -> HTTP $($res.StatusCode)"
    } else {
      Fail "$nombre -> $($err.Exception.Message)"
    }
  }
}

$script:fallos = 0

Write-Host "== Usando docker $script:composeFlavor ==" -ForegroundColor Cyan
Write-Host "== Levantando contenedores ==" -ForegroundColor Cyan
Dc up -d --build | Out-Null

Write-Host "== Esperando MySQL ==" -ForegroundColor Cyan
EsperarMysql 120

Write-Host "== Preparando aplicacion ==" -ForegroundColor Cyan
Dc exec -T app php artisan optimize:clear | Out-Null
Dc exec -T app php artisan migrate:fresh | Out-Null
Dc exec -T app php artisan db:seed | Out-Null

Write-Host "== Obteniendo token admin ==" -ForegroundColor Cyan
$tokenAdmin = ObtenerTokenAdmin
Ok "Token obtenido correctamente"

$headersAdmin = @{ Authorization = "Bearer $tokenAdmin"; Accept = "application/json" }
$headersNoAuth = @{ Accept = "application/json" }

$urlBase = "http://localhost:18080/api/properties/available-for-operations"

Write-Host "== Pruebas ==" -ForegroundColor Cyan

DebeFallarHttp "401 sin token" $urlBase $headersNoAuth

DebePasarHttp "200 con token" $urlBase $headersAdmin {
  param($res)
  if ($null -eq $res.Json.data) { throw "No existe 'data'" }
}

$urlPag = BuildUrl $urlBase @{ per_page = 2; page = 1 }
DebePasarHttp "Paginacion" $urlPag $headersAdmin {
  param($res)
  if ($null -eq $res.Json.data) { throw "No existe 'data'" }
}

$urlSearch = BuildUrl $urlBase @{ search = "prop" }
DebePasarHttp "Filtro search" $urlSearch $headersAdmin {
  param($res)
  if ($null -eq $res.Json.data) { throw "No existe 'data'" }
}

$urlSale = BuildUrl $urlBase @{ operation_type = "sale"; min_price = 1 }
DebePasarHttp "Filtro sale + min_price" $urlSale $headersAdmin {
  param($res)
  if ($null -eq $res.Json.data) { throw "No existe 'data'" }
}

$urlRent = BuildUrl $urlBase @{ operation_type = "rent"; min_price = 1 }
DebePasarHttp "Filtro rent + min_price" $urlRent $headersAdmin {
  param($res)
  if ($null -eq $res.Json.data) { throw "No existe 'data'" }
}

$urlSurf = BuildUrl $urlBase @{ min_surface_m2 = 1 }
DebePasarHttp "Filtro min_surface_m2" $urlSurf $headersAdmin {
  param($res)
  if ($null -eq $res.Json.data) { throw "No existe 'data'" }
}

Write-Host "== Resumen ==" -ForegroundColor Cyan
if ($script:fallos -eq 0) { Ok "Todas las pruebas han pasado"; exit 0 }
Fail "Han fallado $script:fallos prueba(s)"; exit 1
