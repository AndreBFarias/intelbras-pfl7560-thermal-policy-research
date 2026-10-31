# install-firmware-pendrive.ps1 - firmware de resgate no pendrive (bloco 9C).
# E o equivalente, no Windows, do "install.sh --pendrive DIR --com-firmware". Chamado pelo
# install.bat (opcao 5); nao precisa ser aberto a mao.
#
#   -Modo conferir : confere as origens em firmware\ (nada e copiado)
#   -Modo copiar   : copia o usb_update.bin OFICIAL (V1.0.0.9) e o nosso .bin (pasta
#                    firmware-nosso-NAO-GRADUADO\, nao ativo) e confere o md5 depois
#
# Regras (as mesmas do install.sh): so o "Software PFL7560.zip" (modelo COM USB-C) vira
# usb_update.bin, conferido pelo md5 do .bin dentro do zip; NUNCA o "Firmware PFL7560.zip"
# (modelo sem USB-C). Faltou arquivo ou o md5 nao bate = mensagem clara e nada e copiado;
# falha no meio da copia remove o firmware do pendrive. Sai 0 ok, 1 erro.
param(
  [Parameter(Mandatory = $true)][ValidateSet('conferir', 'copiar')][string]$Modo,
  [Parameter(Mandatory = $true)][string]$Dest,
  [string]$Firmware = (Join-Path $PSScriptRoot 'firmware')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipNome = 'Software PFL7560.zip'
$OficialMd5 = '28a2f280eee313a4b115567926b2ba4f'
$NossoBin = 'PFL7560-FIX-escada-NAO-GRADUADO.bin'
$NossoMd5 = 'eae3a83db44f790b64b9a5838a27a977'
$NossoLeiame = 'LEIA-ME-nosso-NAO-GRADUADO.txt'
$NossoPasta = 'firmware-nosso-NAO-GRADUADO'

function Erro($m) { Write-Host "  [ERRO] $m" -ForegroundColor Red; exit 1 }
function Ok($m) { Write-Host "  [OK] $m" -ForegroundColor Green }
function Md5Fluxo($fluxo) {
  $h = [System.Security.Cryptography.MD5]::Create()
  try { return ([BitConverter]::ToString($h.ComputeHash($fluxo)) -replace '-', '').ToLower() } finally { $h.Dispose() }
}
function Md5Arquivo($caminho) { return (Get-FileHash -Algorithm MD5 -LiteralPath $caminho).Hash.ToLower() }

$dest = $Dest.TrimEnd('\') + '\'
$zip = Join-Path $Firmware $ZipNome
$nosso = Join-Path $Firmware $NossoBin
$leiame = Join-Path $Firmware $NossoLeiame

function Entrada($z) {
  $e = @($z.Entries | Where-Object { $_.FullName -match '(^|/)PFL7560\.bin$' })
  if ($e.Count -ne 1) { Erro "'$ZipNome' deveria ter exatamente um PFL7560.bin e tem $($e.Count). Nada foi copiado." }
  return $e[0]
}

if ($Modo -eq 'conferir') {
  Write-Host "  firmware de resgate: conferindo as origens em $Firmware"
  if (-not (Test-Path -LiteralPath $zip)) { Erro "falta '$zip' (o firmware OFICIAL V1.0.0.9 do aparelho com USB-C). NAO use o 'Firmware PFL7560.zip': e do modelo sem USB-C." }
  if (-not (Test-Path -LiteralPath $nosso)) { Erro "falta '$nosso' (o nosso .bin; e 'local only', nao vem no git: copie-o para $Firmware). Nada foi copiado." }
  if (-not (Test-Path -LiteralPath $leiame)) { Erro "falta '$leiame' (o texto que acompanha o nosso .bin no pendrive). Nada foi copiado." }
  $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $e = Entrada $z
    $fluxo = $e.Open()
    try { $m = Md5Fluxo $fluxo } finally { $fluxo.Dispose() }
    if ($m -ne $OficialMd5) { Erro "o .bin dentro de '$ZipNome' tem md5 $m, o esperado e $OficialMd5 (V1.0.0.9 oficial). Nada foi copiado." }
    $precisa = $e.Length + (Get-Item -LiteralPath $nosso).Length + 10MB
  } finally { $z.Dispose() }
  $m = Md5Arquivo $nosso
  if ($m -ne $NossoMd5) { Erro "'$NossoBin' tem md5 $m, o esperado e $NossoMd5. Nada foi copiado." }
  $livre = ([System.IO.DriveInfo]$dest.Substring(0, 1)).AvailableFreeSpace
  if ($livre -lt $precisa) { Erro "pouco espaco em $dest : preciso de $([int]($precisa / 1MB)) MB e ha $([int]($livre / 1MB)) MB livres. Nada foi copiado." }
  Ok "firmware oficial V1.0.0.9 (md5 $OficialMd5) e nosso .bin (md5 $NossoMd5) conferidos"
  exit 0
}

# -Modo copiar
function Limpar {
  foreach ($c in @("$dest" + 'usb_update.bin', "$dest" + 'usb_update.bin.copiando')) { Remove-Item -LiteralPath $c -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath ($dest + $NossoPasta) -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host '  copiando o firmware de resgate (o oficial e grande: leva alguns minutos)'
try {
  $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $e = Entrada $z
    $tmp = $dest + 'usb_update.bin.copiando'
    $saida = [System.IO.File]::Create($tmp)
    try { $entrada = $e.Open(); try { $entrada.CopyTo($saida) } finally { $entrada.Dispose() } } finally { $saida.Dispose() }
  } finally { $z.Dispose() }
  Move-Item -LiteralPath $tmp -Destination ($dest + 'usb_update.bin') -Force
  $pasta = $dest + $NossoPasta
  New-Item -ItemType Directory -Force -Path $pasta | Out-Null
  Copy-Item -LiteralPath $nosso -Destination (Join-Path $pasta $NossoBin) -Force
  Copy-Item -LiteralPath $leiame -Destination (Join-Path $pasta 'LEIA-ME.txt') -Force
} catch {
  Limpar
  Erro "falha ao copiar o firmware ($($_.Exception.Message)). O firmware foi removido do pendrive; NAO use este pendrive."
}
Write-Host '  conferindo o firmware depois da copia'
if ((Md5Arquivo ($dest + 'usb_update.bin')) -ne $OficialMd5) { Limpar; Erro "usb_update.bin NAO confere com o md5 oficial $OficialMd5. O firmware foi removido do pendrive; copie de novo." }
Ok "usb_update.bin (oficial V1.0.0.9, md5 $OficialMd5)"
if ((Md5Arquivo (Join-Path $pasta $NossoBin)) -ne $NossoMd5 -or (Md5Arquivo (Join-Path $pasta 'LEIA-ME.txt')) -ne (Md5Arquivo $leiame)) {
  Limpar; Erro "$NossoPasta\ NAO confere com a origem. O firmware foi removido do pendrive; copie de novo."
}
Ok "$NossoPasta\ ($NossoBin md5 $NossoMd5 e LEIA-ME.txt; NAO esta ativo)"
Write-Host '  [!] pendrive com firmware de resgate: ligar o projetor SEGURANDO O POWER com ele plugado REFLASHA o aparelho e apaga o /data. Deixe-o desconectado no uso normal.' -ForegroundColor Yellow
exit 0
