param(
  [Parameter(Mandatory = $true)][ValidateSet('conferir', 'copiar')][string]$Modo,
  [Parameter(Mandatory = $true)][string]$Dest,
  [string]$Firmware = (Join-Path $PSScriptRoot 'firmware')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipNome = 'Software PFL7560.zip'
$OficialMd5 = '28a2f280eee313a4b115567926b2ba4f'
$NossoBin = 'PFL7560-S4a-NAO-GRADUADO.bin'
$NossoMd5 = 'a6e5da14cb3f53b42a457eb92bd91814'
$ResgatePasta = 'resgate-oficial'
$LegadoPasta = 'firmware-nosso-NAO-GRADUADO'
$LeiameResgate = @'
FIRMWARE OFICIAL DE FABRICA (V1.0.0.9) - RESGATE
================================================

O PFL7560.bin desta pasta e o firmware OFICIAL de fabrica da Intelbras,
V1.0.0.9, do aparelho COM entrada USB-C. Ele NAO esta ativo: o projetor so
olha o usb_update.bin da RAIZ do pendrive, e esse e o NOSSO firmware (escada
de brilho, wi-fi, xiri e o servico da suite), que nunca foi provado no
aparelho.

QUANDO USAR
  So se o nosso firmware deixar o projetor sem ligar ou sem funcionar direito.

COMO USAR
  1. Num PC, apague o usb_update.bin da raiz do pendrive.
  2. Copie este PFL7560.bin para a RAIZ do pendrive com o nome usb_update.bin.
  3. Com o projetor desligado e o pendrive plugado, ligue SEGURANDO O POWER.
     Isso regrava o aparelho e APAGA o /data (Wi-Fi, contas e apps).
  4. Depois, rode o kit do pendrive de novo (sem segurar o power).
  NAO use o firmware do modelo sem USB-C ("Firmware PFL7560.zip").

CONFERENCIA
  md5 deste PFL7560.bin: 28a2f280eee313a4b115567926b2ba4f
  (no Linux: md5sum PFL7560.bin)
'@

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
$leiameTexto = $LeiameResgate.Replace("`r`n", "`n") + "`n"

function Entrada($z) {
  $e = @($z.Entries | Where-Object { $_.FullName -match '(^|/)PFL7560\.bin$' })
  if ($e.Count -ne 1) { Erro "'$ZipNome' deveria ter exatamente um PFL7560.bin e tem $($e.Count). Nada foi copiado." }
  return $e[0]
}

if ($Modo -eq 'conferir') {
  Write-Host "  firmware: conferindo as origens em $Firmware"
  if (-not (Test-Path -LiteralPath $zip)) { Erro "falta '$zip' (o firmware OFICIAL V1.0.0.9 do aparelho com USB-C). NAO use o 'Firmware PFL7560.zip': e do modelo sem USB-C." }
  if (-not (Test-Path -LiteralPath $nosso)) { Erro "falta '$nosso' (o nosso .bin; e 'local only', nao vem no git: copie-o para $Firmware). Nada foi copiado." }
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
  Ok "nosso .bin $NossoBin (md5 $NossoMd5) e firmware oficial V1.0.0.9 (md5 $OficialMd5) conferidos"
  exit 0
}

function Limpar {
  foreach ($c in @("$dest" + 'usb_update.bin', "$dest" + 'usb_update.bin.copiando')) { Remove-Item -LiteralPath $c -Force -ErrorAction SilentlyContinue }
  foreach ($c in @($ResgatePasta, $LegadoPasta)) { Remove-Item -LiteralPath ($dest + $c) -Recurse -Force -ErrorAction SilentlyContinue }
}
$pasta = $dest + $ResgatePasta
$oficial = Join-Path $pasta 'PFL7560.bin'
$leiaDest = Join-Path $pasta 'LEIA-ME.txt'
Limpar
Write-Host "  copiando o firmware: o nosso .bin como usb_update.bin e o oficial em $ResgatePasta\ (sao grandes: leva alguns minutos)"
try {
  New-Item -ItemType Directory -Force -Path $pasta | Out-Null
  $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $e = Entrada $z
    $tmp = $oficial + '.copiando'
    $saida = [System.IO.File]::Create($tmp)
    try { $entrada = $e.Open(); try { $entrada.CopyTo($saida) } finally { $entrada.Dispose() } } finally { $saida.Dispose() }
  } finally { $z.Dispose() }
  Move-Item -LiteralPath $tmp -Destination $oficial -Force
  [System.IO.File]::WriteAllText($leiaDest, $leiameTexto, [System.Text.Encoding]::ASCII)
  Copy-Item -LiteralPath $nosso -Destination ($dest + 'usb_update.bin.copiando') -Force
  Move-Item -LiteralPath ($dest + 'usb_update.bin.copiando') -Destination ($dest + 'usb_update.bin') -Force
} catch {
  Limpar
  Erro "falha ao copiar o firmware ($($_.Exception.Message)). O firmware foi removido do pendrive; NAO use este pendrive."
}
Write-Host '  conferindo o firmware depois da copia'
if ((Md5Arquivo $oficial) -ne $OficialMd5 -or [System.IO.File]::ReadAllText($leiaDest) -ne $leiameTexto) {
  Limpar; Erro "$ResgatePasta\ NAO confere (md5 oficial $OficialMd5 ou o LEIA-ME). O firmware foi removido do pendrive; copie de novo."
}
Ok "$ResgatePasta\PFL7560.bin (oficial V1.0.0.9, md5 $OficialMd5) e LEIA-ME.txt; NAO esta ativo"
if ((Md5Arquivo ($dest + 'usb_update.bin')) -ne $NossoMd5) { Limpar; Erro "usb_update.bin NAO confere com o md5 do nosso .bin $NossoMd5. O firmware foi removido do pendrive; copie de novo." }
Ok "usb_update.bin (o nosso $NossoBin, md5 $NossoMd5)"
Write-Host "  [!] pendrive com firmware: ligar o projetor SEGURANDO O POWER com ele plugado REFLASHA o aparelho com o NOSSO .bin (nao provado no hardware) e apaga o /data. O resgate e o oficial em $ResgatePasta\ (LEIA-ME.txt dela). Deixe-o desconectado no uso normal." -ForegroundColor Yellow
exit 0
