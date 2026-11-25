# Sobe um servidor HTTP simples para o build web do Flutter (pasta build/web).
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File tool\servir_web.ps1 [-Porta 5173]
param(
    [int]$Porta = 5173
)

$ErrorActionPreference = 'Stop'
$raiz = Join-Path $PSScriptRoot '..\build\web'

if (-not (Test-Path $raiz)) {
    Write-Error "Pasta nao encontrada: $raiz. Rode 'flutter build web' antes."
    exit 1
}

python -m http.server $Porta --bind 127.0.0.1 --directory $raiz
