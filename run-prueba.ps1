$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

function Ok($msg) { Write-Host "OK   $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL $msg" -ForegroundColor Red; $script:fallos++ }

function DetectarCompose {
    try { & docker compose version *> $null; return "compose" } catch {}
    try { & docker-compose version *> $null; return "docker-compose" } catch {}
    throw "No encuentro docker compose ni docker-compose. ¿Docker Desktop está arrancado?"
}

$script:composeFlavor = DetectarCompose

function Dc {
    param([Parameter(Mandatory = $true)][object[]]$dcArgs)

    $flat = New-Object System.Collections.Generic.List[string]
    foreach ($a in $dcArgs) {
        if ($null -eq $a) { continue }
        if ($a -is [System.Array] -and -not ($a -is [string])) {
            foreach ($x in $a) {
                if ($null -eq $x) { continue }
                $s = $x.ToString().Trim()
                if ($s -ne "") { $flat.Add($s) | Out-Null }
            }
        } else {
            $s = $a.ToString().Trim()
            if ($s -ne "") { $flat.Add($s) | Out-Null }
        }
    }

    if ($flat.Count -eq 0) { throw "Dc() llamado sin argumentos." }

    $argsList = New-Object System.Collections.Generic.List[string]
    if ($script:composeFlavor -eq "compose") { $argsList.Add("compose") | Out-Null }
    foreach ($x in $flat) { $argsList.Add($x) | Out-Null }

    $tmpDir = $env:TEMP
    if ([string]::IsNullOrWhiteSpace($tmpDir)) { $tmpDir = [System.IO.Path]::GetTempPath() }

    $tmpOut = Join-Path $tmpDir ("dc_out_{0}.txt" -f ([guid]::NewGuid().ToString("N")))
    $tmpErr = Join-Path $tmpDir ("dc_err_{0}.txt" -f ([guid]::NewGuid().ToString("N")))

    try {
        $p = Start-Process -FilePath "docker" -ArgumentList $argsList.ToArray() -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr

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
            if ($err) { throw $err }
            if ($out) { throw $out }
            throw "docker devolvió código $($p.ExitCode)"
        }

        $combined = @()
        if ($out) { $combined += $out }
        if ($err) { $combined += $err }
        return ($combined -join "`n")
    } finally {
        if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tmpErr) { Remove-Item $tmpErr -Force -ErrorAction SilentlyContinue }
    }
}

function EsperarMysql([int]$segundosMax = 120) {
    $inicio = Get-Date
    while ($true) {
        try {
            Dc @("exec","-T","db","mysqladmin","ping","-h","127.0.0.1","-uroot","-proot","--silent") | Out-Null
            return
        } catch {
            if (((Get-Date) - $inicio).TotalSeconds -ge $segundosMax) { throw "MySQL no está listo tras $segundosMax segundos" }
            Start-Sleep -Seconds 2
        }
    }
}

function ObtenerTokenAdmin([int]$reintentos = 10, [int]$sleepSeg = 2) {
    for ($i = 1; $i -le $reintentos; $i++) {
        $raw = Dc @("exec","-T","app","php","artisan","token:emit","admin@demo.com")
        $tokenLine = ($raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+\|[A-Za-z0-9]+' } | Select-Object -Last 1)
        if ($tokenLine) { return $tokenLine }
        Start-Sleep -Seconds $sleepSeg
    }
    throw "No pude obtener un token válido tras $reintentos intentos."
}

function GetJson($url, $headers) {
    $u = [Uri]::new($url)
    Invoke-RestMethod -Uri $u -Headers $headers -Method Get -TimeoutSec 60
}

function BuildUrl([string]$baseUrl, [hashtable]$query) {
    Add-Type -AssemblyName System.Web | Out-Null
    $ub = [System.UriBuilder]::new($baseUrl)
    $q = [System.Web.HttpUtility]::ParseQueryString($ub.Query)
    foreach ($k in $query.Keys) {
        $v = $query[$k]
        if ($null -ne $v -and "$v".Trim() -ne "") {
            $q[$k] = "$v"
        }
    }
    $ub.Query = $q.ToString()
    return $ub.Uri.AbsoluteUri
}

function DebeFallar($bloque, $nombre) {
    try { & $bloque | Out-Null; Fail "$nombre (debería fallar)" } catch { Ok $nombre }
}

function DebePasar($bloque, $nombre) {
    try { & $bloque | Out-Null; Ok $nombre } catch { Fail "$nombre -> $($_.Exception.Message)" }
}

$script:fallos = 0

Write-Host "== Usando docker $script:composeFlavor ==" -ForegroundColor Cyan
Write-Host "== Levantando contenedores ==" -ForegroundColor Cyan
Dc @("up","-d","--build") | Out-Null

Write-Host "== Esperando MySQL ==" -ForegroundColor Cyan
EsperarMysql 120

Write-Host "== Preparando aplicacion ==" -ForegroundColor Cyan
Dc @("exec","-T","app","php","artisan","optimize:clear") | Out-Null
Dc @("exec","-T","app","php","artisan","migrate:fresh") | Out-Null
Dc @("exec","-T","app","php","artisan","db:seed") | Out-Null

Write-Host "== Obteniendo token admin ==" -ForegroundColor Cyan
$tokenAdmin = ObtenerTokenAdmin
Ok "Token obtenido correctamente"

$headersAdmin = @{ Authorization = "Bearer $tokenAdmin"; Accept = "application/json" }
$urlBase = "http://localhost:18080/api/properties/available-for-operations"

Write-Host "== Pruebas ==" -ForegroundColor Cyan

DebeFallar { Invoke-RestMethod -Uri ([Uri]::new($urlBase)) -Headers @{ Accept="application/json" } -Method Get -TimeoutSec 30 } "401 sin token"

DebePasar {
    $r = GetJson $urlBase $headersAdmin
    if ($null -eq $r.data) { throw "No existe 'data'" }
} "200 con token"

DebePasar {
    $u = BuildUrl $urlBase @{ per_page = 2; page = 1 }
    $r = GetJson $u $headersAdmin
    if ($null -eq $r.data) { throw "No existe 'data'" }
} "Paginacion"

DebePasar {
    $u = BuildUrl $urlBase @{ search = "prop" }
    $r = GetJson $u $headersAdmin
    if ($null -eq $r.data) { throw "No existe 'data'" }
} "Filtro search"

DebePasar {
    $u = BuildUrl $urlBase @{ operation_type = "sale"; min_price = 1 }
    $r = GetJson $u $headersAdmin
    if ($null -eq $r.data) { throw "No existe 'data'" }
} "Filtro sale + min_price"

DebePasar {
    $u = BuildUrl $urlBase @{ operation_type = "rent"; min_price = 1 }
    $r = GetJson $u $headersAdmin
    if ($null -eq $r.data) { throw "No existe 'data'" }
} "Filtro rent + min_price"

DebePasar {
    $u = BuildUrl $urlBase @{ min_surface_m2 = 1 }
    $r = GetJson $u $headersAdmin
    if ($null -eq $r.data) { throw "No existe 'data'" }
} "Filtro min_surface_m2"

Write-Host "== Resumen ==" -ForegroundColor Cyan
if ($script:fallos -eq 0) { Ok "Todas las pruebas han pasado"; exit 0 }
Fail "Han fallado $script:fallos prueba(s)"; exit 1
