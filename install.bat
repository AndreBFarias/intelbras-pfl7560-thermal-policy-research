@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title PFL7560 - setup do PC (Windows)

REM ============================================================================
REM  install.bat — prepara o PC (Windows) para a correcao PFL7560 via adb
REM
REM  NAO grava nada no projetor ate voce escolher "Aplicar".
REM  Metodo sem PC (recomendado se nao quiser adb): pasta pendrive-autorun\
REM
REM  Uso:  clique duplo em install.bat   ou   install.bat  no cmd
REM ============================================================================

cd /d "%~dp0"
set "HERE=%CD%"
set "TOOLS=%HERE%\tools\platform-tools"
set "ADB="
set "INI=%HERE%\pendrive-autorun\ZYCustom.ini"
set "PORT=5555"

call :find_adb
if defined ADB goto :menu

echo.
echo  [!] adb nao encontrado. Vamos instalar as Platform-Tools (Google).
echo.
call :install_adb
call :find_adb
if not defined ADB (
  echo  [ERRO] Ainda sem adb. Instale manualmente:
  echo    https://developer.android.com/tools/releases/platform-tools
  echo    Extraia e coloque adb.exe no PATH, ou em tools\platform-tools\
  pause
  exit /b 1
)

:menu
echo.
echo  ============================================================
echo       PFL7560 - Windows
echo       PC: adb pronto  ^|  Projetor: mesmo Wi-Fi, IP visivel
echo  ============================================================
echo.
echo     1^) Verificar ferramentas (nao muda o projetor^)
echo     2^) Ver estado do projetor  (pede IP^)
echo     3^) Aplicar correcao termica (pede IP^)
echo     4^) Reverter para fabrica   (pede IP; usa backup local^)
echo     5^) Copiar o kit v2 para o PENDRIVE (metodo SEM PC^)
echo     6^) Corrigir COR (so se voce TROCOU o painel LCD^)
echo     7^) VERIFICAR se esta tudo certo (recomendado; nao cutuca o sensor^)
echo     8^) Sair
echo.
set /p "OP=  Escolha [1-8]: "

if "%OP%"=="1" goto :do_check
if "%OP%"=="2" goto :do_status
if "%OP%"=="3" goto :do_apply
if "%OP%"=="4" goto :do_revert
if "%OP%"=="5" goto :do_pendrive
if "%OP%"=="6" goto :do_lcd
if "%OP%"=="7" goto :do_saude
if "%OP%"=="8" exit /b 0
echo  opcao invalida.
goto :menu

:do_check
echo.
echo  adb = %ADB%
"%ADB%" version
if exist "%INI%" (echo  [OK] ZYCustom.ini do fix presente) else (echo  [ERRO] falta pendrive-autorun\ZYCustom.ini)
if exist "%HERE%\pfl7560-fix.sh" (
  echo  [i] pfl7560-fix.sh existe — no Windows o fluxo nativo e este .bat
  echo      Com WSL2 voce pode:  wsl ./install.sh ^&^& wsl bash -lc "PFL_IP=x.x.x.x ./pfl7560-fix.sh status"
)
echo.
echo  Proximo: anote o IP do projetor ^(Configuracoes -^> Wi-Fi^) e use a opcao 2 ou 3.
pause
goto :menu

:do_saude
call :ask_ip || goto :menu
call :connect || goto :menu
echo.
echo  ============================================================
echo   VERIFICACAO - nenhuma destas leituras toca o sensor
echo  ============================================================
echo.
echo  [1] os 3 arquivos corrigidos
"%ADB%" -s %DEV% shell "md5sum /vendor/etc/ZYCustom.ini" 2>nul | findstr /c:"252ab7a72a007a8b79b3fc86bd5c0d19" >nul && (echo      OK    ZYCustom.ini e o config de correcao) || (echo      FALHA ZYCustom.ini divergente ou ilegivel)
"%ADB%" -s %DEV% shell "grep -a wifi_disconnect_on_boot /vendor/build.prop" 2>nul | findstr /c:"=0" >nul && (echo      OK    Wi-Fi reconecta no boot) || (echo      FALHA Wi-Fi nao corrigido)
"%ADB%" -s %DEV% shell "grep -a -A3 'service xiriservice' /vendor/etc/init/hw/init.bigfish.rc" 2>nul | findstr /c:"disabled" >nul && (echo      OK    xiriservice silenciado) || (echo      FALHA xiriservice ativo)
echo.
echo  [2] o conserto em si - o mux dos termistores
"%ADB%" -s %DEV% shell "grep -ac 'HW_VIRTUAL_CHANNEL = 1' /vendor/etc/ZYCustom.ini" 2>nul | findstr /r "[1-9]" >nul && (echo      OK    HW_VIRTUAL_CHANNEL = 1 presente) || (echo      FALHA mux travado no canal 0)
"%ADB%" -s %DEV% shell "ls /atv/ini/ZYCustom.ini" 2>nul | findstr /c:"No such" >nul && (echo      OK    sem ZYCustom.ini em /atv/ini) || (echo      ATENCAO existe /atv/ini/ZYCustom.ini - ele VENCE o de /vendor)
echo.
echo  [3] apareceu LSADC Error no buffer? - sinal POSITIVO, nao prova
"%ADB%" -s %DEV% shell "logcat -d | grep -c 'LSADC Error'" 2>nul | findstr /r "^0" >nul && (echo      OK    nenhum LSADC Error no buffer - NAO prova que esta viva) || (echo      FALHA LSADC Error presente - PROTECAO CEGA. REINICIE O PROJETOR.)
echo      Zero ocorrencias NAO prova que a protecao esta viva: o erro so
echo      aparece em 2 de cada 10 iteracoes do loop termico, e o buffer do
echo      logcat dura 60-150 s neste aparelho. Se aparecer, ai sim algo esta
echo      errado de fato - reinicie o projetor.
echo      sensores (o 1o e a optica, o 2o a placa; iguais = mux nao comutou^):
"%ADB%" -s %DEV% shell "getprop zysys.env_temp; getprop zysys.light_temp" 2>nul
echo.
echo  [4] correcao de cor do painel trocado
REM VESA ou JEIDA sao ambos validos: depende do painel que esta na optica. O que se confere aqui
REM e se o formato em uso bate com o byte lvds_fmt gravado no perfil ativo da panelparam (exige root).
"%ADB%" -s %DEV% shell "f=$(grep -a lvds_fmt /proc/msp/panel | head -1 | sed 's/^[^:]*:\([^|]*\).*/\1/;s/[^A-Za-z]//g' | tr 'A-Z' 'a-z'); i=$(grep -a cut_idx /proc/msp/panel | head -1 | sed 's/^[^:]*:\([^|]*\).*/\1/;s/[^0-9]//g'); b=; case $i in ?*) b=$(dd if=/dev/block/by-name/panelparam bs=1 skip=$((168+i*768+92)) count=1 2>/dev/null | od -An -tu1 | tr -d ' ');; esac; case $f:$b in jeida:1|vesa:0) echo COR_OK;; *) echo COR_DIVERGE;; esac" 2>nul | findstr /c:"COR_OK" >nul && (echo      OK    formato em uso bate com o byte gravado na panelparam) || (echo      ATENCAO formato em uso diverge do byte gravado, ou ilegivel ^(a leitura exige root^))
"%ADB%" -s %DEV% shell "grep -a lvds_fmt /proc/msp/panel" 2>nul
echo      O software nao sabe qual painel esta na optica: confira a cor na tela.
echo.
echo  ============================================================
echo   A configuracao pode estar perfeita e a protecao estar cega
echo   mesmo assim - sao coisas diferentes. O bloco [3] NAO decide
echo   isso: ausencia de LSADC Error nao prova nada, so a presenca.
echo   A prova que decide e o teste de vivacidade, que injeta 71 C
echo   e ve se o firmware REAGE. Ele roda no Linux/WSL:
echo      wsl bash -lc "PFL_IP=IP-DO-PROJETOR ./pfl7560-saude.sh --vivacidade"
echo   Se a protecao estiver cega, reiniciar o projetor restaura.
echo  ============================================================
echo.
pause
goto :menu

:do_status
call :ask_ip || goto :menu
call :connect || goto :menu
echo.
echo  --- estado ---
"%ADB%" -s %DEV% shell "printf 'custom\ngtc\ngtt 0\ngtt 1\ngfs 0\ngfs 1\ngbri 0\nquit\n'|/vendor/bin/hidebug" 2>nul | findstr /i "NTC fan brightness"
"%ADB%" -s %DEV% shell "grep -aE 'HW_VIRTUAL_CHANNEL|POLICY_0_SPEED|POLICY_0_THRESHOLD|POLICY_0_BRIGHTNESS' /vendor/etc/ZYCustom.ini; grep -a wifi_disconnect_on_boot /vendor/build.prop; getprop init.svc.xiriservice" 2>nul
echo.
pause
goto :menu

:do_apply
call :ask_ip || goto :menu
if not exist "%INI%" (
  echo  [ERRO] Arquivo nao encontrado: %INI%
  pause
  goto :menu
)
echo.
echo  ATENCAO: vai editar /vendor no projetor ^(termico + wi-fi + xiri^).
echo  Backup sera salvo em backups-projetor\
set /p "C=  Continuar? [s/N]: "
if /i not "%C%"=="s" (
  echo  cancelado.
  goto :menu
)
call :connect || goto :menu
REM bloco 6: este .bat grava o ini e o build.prop do V1.0.0.9 (com USB-C). No modelo sem USB-C
REM (V1.0.0.1, NOTYPEC) isso rebaixaria o CONFIG_MODEL e o revert daria USB-C fantasma e o canal
REM de OTA errado: so segue se o CONFIG_MODEL E o ro.newlink.projectname forem os do V1.0.0.9 (um
REM aparelho sem USB-C que ja levou este ini tem o CONFIG_MODEL rebaixado, mas nao o projectname).
REM O pfl7560-fix.sh (Linux/WSL) trata os dois.
"%ADB%" -s %DEV% shell "grep -aq '^CONFIG_MODEL *= *KJM_5H039_412;' /vendor/etc/ZYCustom.ini && getprop ro.newlink.projectname | grep -qx KJM_5H039_412_INTELBRAS_TP"
if errorlevel 1 (
  echo  [ERRO] Aparelho nao reconhecido como o modelo com USB-C ^(V1.0.0.9^): nada foi alterado.
  echo         Para o modelo sem USB-C ^(V1.0.0.1, NOTYPEC^) use o pendrive ^(opcao 5^) ou,
  echo         no Linux/WSL, ./pfl7560-fix.sh apply ^(ele detecta o modelo^).
  pause
  goto :menu
)
call :backup_stock
if errorlevel 1 goto :menu

echo  [1/3] ZYCustom.ini ...
"%ADB%" -s %DEV% remount >nul 2>&1
"%ADB%" -s %DEV% push "%INI%" /vendor/etc/ZYCustom.ini.new
if errorlevel 1 (
  echo  [ERRO] push do ini falhou
  pause
  goto :menu
)
"%ADB%" -s %DEV% shell "grep -q 'HW_VIRTUAL_CHANNEL = 1' /vendor/etc/ZYCustom.ini.new && grep -q '= 66000, 67500, 69000, 70000, 71500, 73000' /vendor/etc/ZYCustom.ini.new && chmod 644 /vendor/etc/ZYCustom.ini.new && chcon u:object_r:vendor_configs_file:s0 /vendor/etc/ZYCustom.ini.new && mv /vendor/etc/ZYCustom.ini.new /vendor/etc/ZYCustom.ini"
if errorlevel 1 (
  echo  [ERRO] gravacao do ini falhou
  pause
  goto :menu
)
echo  [OK] termico

echo  [2/3] wifi_disconnect_on_boot=0 ...
REM atomico: edita uma copia .new, confere, e so entao mv por cima (original intacto se cair no meio)
"%ADB%" -s %DEV% shell "cp /vendor/build.prop /vendor/build.prop.new && sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' /vendor/build.prop.new && grep -q wifi_disconnect_on_boot=0 /vendor/build.prop.new && mv /vendor/build.prop.new /vendor/build.prop || rm -f /vendor/build.prop.new"
"%ADB%" -s %DEV% shell "grep -q wifi_disconnect_on_boot=0 /vendor/build.prop"
if errorlevel 1 (
  echo  [ERRO] wifi nao confirmado
  pause
  goto :menu
)
echo  [OK] wifi

echo  [3/3] xiriservice disabled ...
REM BOOT-CRITICO: nunca sed -i no arquivo vivo; edita .new, confere e so entao mv (senao rm do .new)
"%ADB%" -s %DEV% shell "grep -A1 'service xiriservice' /vendor/etc/init/hw/init.bigfish.rc | grep -q disabled || { cp /vendor/etc/init/hw/init.bigfish.rc /vendor/etc/init/hw/init.bigfish.rc.new && sed -i '/^service xiriservice \/system\/bin\/xiriservice/a\    disabled' /vendor/etc/init/hw/init.bigfish.rc.new && grep -A1 'service xiriservice' /vendor/etc/init/hw/init.bigfish.rc.new | grep -q disabled && mv /vendor/etc/init/hw/init.bigfish.rc.new /vendor/etc/init/hw/init.bigfish.rc || rm -f /vendor/etc/init/hw/init.bigfish.rc.new; }"
"%ADB%" -s %DEV% shell "grep -A1 'service xiriservice' /vendor/etc/init/hw/init.bigfish.rc | grep -q disabled"
if errorlevel 1 (
  echo  [ERRO] xiri nao confirmado
  pause
  goto :menu
)
echo  [OK] xiri

"%ADB%" -s %DEV% shell "grep -q 'HW_VIRTUAL_CHANNEL = 1' /vendor/etc/ZYCustom.ini && grep -q '= 66000, 67500, 69000, 70000, 71500, 73000' /vendor/etc/ZYCustom.ini && grep -q wifi_disconnect_on_boot=0 /vendor/build.prop"
if errorlevel 1 (
  echo  [ERRO] validacao final falhou — NAO reiniciei
  pause
  goto :menu
)

echo  reiniciando projetor...
"%ADB%" -s %DEV% shell sync
"%ADB%" -s %DEV% reboot
echo  [OK] APLICADO. Aguarde o boot; wi-fi deve reconectar sozinho.
pause
goto :menu

:do_revert
call :ask_ip || goto :menu
set "BK=%HERE%\backups-projetor"
if not exist "%BK%\ZYCustom.ini.STOCK" goto :no_bk
if not exist "%BK%\build.prop.STOCK" goto :no_bk
if not exist "%BK%\init.bigfish.rc.STOCK" goto :no_bk
echo.
set /p "C=  Restaurar stock de fabrica a partir do backup local? [s/N]: "
if /i not "%C%"=="s" (
  echo  cancelado.
  goto :menu
)
call :connect || goto :menu
REM bloco 6: este .bat grava o ini e o build.prop do V1.0.0.9 (com USB-C). No modelo sem USB-C
REM (V1.0.0.1, NOTYPEC) isso rebaixaria o CONFIG_MODEL e o revert daria USB-C fantasma e o canal
REM de OTA errado: so segue se o CONFIG_MODEL E o ro.newlink.projectname forem os do V1.0.0.9 (um
REM aparelho sem USB-C que ja levou este ini tem o CONFIG_MODEL rebaixado, mas nao o projectname).
REM O pfl7560-fix.sh (Linux/WSL) trata os dois.
"%ADB%" -s %DEV% shell "grep -aq '^CONFIG_MODEL *= *KJM_5H039_412;' /vendor/etc/ZYCustom.ini && getprop ro.newlink.projectname | grep -qx KJM_5H039_412_INTELBRAS_TP"
if errorlevel 1 (
  echo  [ERRO] Aparelho nao reconhecido como o modelo com USB-C ^(V1.0.0.9^): nada foi alterado.
  echo         Para o modelo sem USB-C ^(V1.0.0.1, NOTYPEC^) use o pendrive ^(opcao 5^) ou,
  echo         no Linux/WSL, ./pfl7560-fix.sh apply ^(ele detecta o modelo^).
  pause
  goto :menu
)
"%ADB%" -s %DEV% remount >nul 2>&1
set "RVOK=1"
REM os 3 restauros sao atomicos (.new + confere + mv); qualquer falha marca RVOK=0 e NAO reinicia
REM SEM '|| rm': se o mv falhar (destino read-only/FS cheio) o adb shell retorna != 0
REM e o 'if errorlevel 1' abaixo marca RVOK=0. Um .new remanescente e inofensivo (sobrescrito).
"%ADB%" -s %DEV% push "%BK%\ZYCustom.ini.STOCK" /vendor/etc/ZYCustom.ini.new
if errorlevel 1 set "RVOK=0"
"%ADB%" -s %DEV% shell "[ -s /vendor/etc/ZYCustom.ini.new ] && mv /vendor/etc/ZYCustom.ini.new /vendor/etc/ZYCustom.ini"
if errorlevel 1 set "RVOK=0"
"%ADB%" -s %DEV% push "%BK%\build.prop.STOCK" /vendor/build.prop.new
if errorlevel 1 set "RVOK=0"
"%ADB%" -s %DEV% shell "[ -s /vendor/build.prop.new ] && mv /vendor/build.prop.new /vendor/build.prop"
if errorlevel 1 set "RVOK=0"
REM init.bigfish.rc e BOOT-CRITICO: so promove o .new se tiver conteudo E a linha do xiriservice
"%ADB%" -s %DEV% push "%BK%\init.bigfish.rc.STOCK" /vendor/etc/init/hw/init.bigfish.rc.new
if errorlevel 1 set "RVOK=0"
"%ADB%" -s %DEV% shell "[ -s /vendor/etc/init/hw/init.bigfish.rc.new ] && grep -q 'service xiriservice' /vendor/etc/init/hw/init.bigfish.rc.new && mv /vendor/etc/init/hw/init.bigfish.rc.new /vendor/etc/init/hw/init.bigfish.rc"
if errorlevel 1 set "RVOK=0"
if "%RVOK%"=="0" (
  echo  [ERRO] Revert incompleto ^(push/gravacao falhou^). NAO reiniciei - reexecute.
  pause
  goto :menu
)
REM confirmacao final por CONTEUDO stock (nao so existencia): build.prop de fabrica tem wifi=1
REM (o fix poe =0), o que prova que o build.prop reverteu; os outros 2 sao cobertos pela deteccao
REM de falha do mv acima. Sem '!' aqui: com EnableDelayedExpansion o cmd.exe corromperia o '!'.
"%ADB%" -s %DEV% shell "grep -q wifi_disconnect_on_boot=1 /vendor/build.prop && [ -s /vendor/etc/ZYCustom.ini ] && [ -s /vendor/etc/init/hw/init.bigfish.rc ]"
if errorlevel 1 (
  echo  [ERRO] validacao final do revert falhou. NAO reiniciei.
  pause
  goto :menu
)
"%ADB%" -s %DEV% shell sync
"%ADB%" -s %DEV% reboot
echo  [OK] REVERTIDO (3 arquivos, confirmados). Projetor reiniciando.
pause
goto :menu

:no_bk
echo  [ERRO] Backup incompleto em backups-projetor\
echo         Rode Aplicar uma vez neste PC, ou reflash o firmware de fabrica.
pause
goto :menu

:do_lcd
call :ask_ip || goto :menu
set "LVDSCTL=%HERE%\artifacts\lcd-color-fix\lvdsctl"
if not exist "%LVDSCTL%" (
  echo  [ERRO] nao achei artifacts\lcd-color-fix\lvdsctl
  pause
  goto :menu
)
echo.
echo  Correcao de cor pos-troca de painel ^(formato LVDS VESA ou JEIDA^).
echo  So use se voce TROCOU o micro-painel LCD e as cores dos meios-tons sairam erradas.
echo    a^) Ver o formato LVDS atual (nao muda nada^)
echo    c^) Aplicar JEIDA  (o -0600 da 1a troca^)
echo    d^) Aplicar VESA   (painel de fabrica e o da 2a troca^)
echo  ^(c e d GRAVAM na particao panelparam; o backup e feito antes, em backups-projetor\^)
echo  ^(backup/restore/wizard completos: use o WSL -^> wsl ./pfl7560-lcd-color.sh wizard^)
set /p "LOP=  Escolha [a/c/d]: "
call :connect || goto :menu
if /i "%LOP%"=="a" (
  "%ADB%" -s %DEV% shell "cat /proc/msp/panel | grep -iE 'panel_name|lvds_fmt|bit_width'"
  pause
  goto :menu
)
set "FMT="
if /i "%LOP%"=="c" set "FMT=1"
if /i "%LOP%"=="d" set "FMT=0"
if not defined FMT (
  echo  opcao invalida.
  pause
  goto :menu
)
call :backup_panelparam
if errorlevel 1 (
  pause
  goto :menu
)
"%ADB%" -s %DEV% push "%LVDSCTL%" /data/local/tmp/lvdsctl >nul
if errorlevel 1 (
  echo  [ERRO] push do lvdsctl falhou ^(rede?^) - a cor NAO foi aplicada.
  pause
  goto :menu
)
"%ADB%" -s %DEV% shell "chmod 755 /data/local/tmp/lvdsctl && cd /data/local/tmp && LD_LIBRARY_PATH=/vendor/lib:/system/lib:/vendor/lib/hw ./lvdsctl fmt %FMT%"
if errorlevel 1 (echo  [ERRO] lvdsctl fmt %FMT% falhou - a cor NAO foi aplicada.) else (echo  [OK] formato LVDS %FMT% aplicado ^(0=VESA 1=JEIDA^). Confira o lvds_fmt abaixo.)
"%ADB%" -s %DEV% shell "cat /proc/msp/panel | grep -iE 'panel_name|lvds_fmt'"
pause
goto :menu

:do_pendrive
echo.
echo  Metodo SEM PC: copia o kit v2 COMPLETO para a RAIZ de um pendrive FAT32
echo  e confere o md5 de cada arquivo contra a lista do newlink_update.sh.
echo    Arquivos: newlink_update.sh, cor.sh, lvdsctl, nl_camcheck, nl_tela, ZYCustom.ini, LEIA-ME.txt,
echo              suite.sh, suite-boot.sh, suite-pedido.sh, pfl7560-suite.rc, pfl7560.apk, pfl7560-home.apk, kit\*.png e fontes\*
echo    Origem:   %HERE%\pendrive-autorun
echo    O pendrive tem de estar em FAT32 ^(MBR^). NAO use o pendrive de resgate do firmware.
echo    Opcional: juntar o firmware de RESGATE ^(usb_update.bin oficial V1.0.0.9 na raiz e o nosso .bin em
echo              firmware-nosso-NAO-GRADUADO\, sem ativar^). Com ele, ligar o projetor SEGURANDO O POWER reflasha.
echo.
set "DRV="
set /p "DRV=  Letra do pendrive (ex E): "
if not defined DRV goto :menu
set "DRV=%DRV::=%"
set "DRV=%DRV:\=%"
set "DRV=%DRV:~0,1%"
if /i "%DRV%:"=="%SystemDrive%" (
  echo  [ERRO] %DRV%: e o disco do Windows. Informe a letra do PENDRIVE.
  pause
  goto :menu
)
if not exist "%DRV%:\" (
  echo  [ERRO] nao achei a unidade %DRV%:
  pause
  goto :menu
)
set "DST=%DRV%:"
set "SRC=%HERE%\pendrive-autorun"
set "KITFAIL=0"
set "COMFW=0"
set "FWRESP="
set /p "FWRESP=  Incluir o firmware de resgate no pendrive? [s/N]: "
if /i "%FWRESP%"=="s" set "COMFW=1"
REM com firmware, as origens sao conferidas ANTES de copiar o kit: nada vai pela metade
if "%COMFW%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%\install-firmware-pendrive.ps1" -Modo conferir -Dest "%DST%" -Firmware "%HERE%\firmware"
  if errorlevel 1 (
    echo.
    echo  [ERRO] o firmware de resgate nao confere ^(ver acima^). NADA foi copiado para o pendrive.
    pause
    goto :menu
  )
)
if not exist "%DST%\kit\" mkdir "%DST%\kit"
if not exist "%DST%\fontes\" mkdir "%DST%\fontes"
for %%F in (newlink_update.sh cor.sh lvdsctl nl_camcheck nl_tela ZYCustom.ini LEIA-ME.txt suite.sh suite-boot.sh suite-pedido.sh pfl7560-suite.rc pfl7560.apk pfl7560-home.apk) do copy /y "%SRC%\%%F" "%DST%\%%F" >nul || set "KITFAIL=1"
copy /y "%SRC%\kit\*.png" "%DST%\kit\" >nul || set "KITFAIL=1"
copy /y "%SRC%\fontes\*" "%DST%\fontes\" >nul || set "KITFAIL=1"
if "%KITFAIL%"=="1" (
  echo  [ERRO] a copia falhou ^(pendrive cheio, protegido ou removido?^). NAO use este pendrive.
  pause
  goto :menu
)
echo  copiado. Conferindo o md5 de cada arquivo depois da copia ...
set "PFL_SRC=%SRC%"
set "PFL_DST=%DST%"
REM a lista (md5  nome) esta embutida no newlink_update.sh entre KIT_LISTA_INICIO e KIT_LISTA_FIM;
REM o proprio newlink_update.sh e o LEIA-ME.txt nao estao nela e sao comparados com a origem.
powershell -NoProfile -Command "$s=$env:PFL_SRC; $d=$env:PFL_DST; $txt=Get-Content -Raw -LiteralPath ($s+'\newlink_update.sh'); $bad=0; $n=0; foreach($m in [regex]::Matches($txt,'(?m)^(?:KIT_LISTA=\x22)?([0-9a-f]{32})  (\S+)\s*$')){ $n++; $h=$m.Groups[1].Value; $f=$m.Groups[2].Value -replace '/','\'; $g=''; if(Test-Path -LiteralPath ($d+'\'+$f)){ $g=(Get-FileHash -Algorithm MD5 -LiteralPath ($d+'\'+$f)).Hash.ToLower() }; if($g -eq $h){ Write-Host ('     OK    '+$f) } else { Write-Host ('     FALHA '+$f); $bad++ } }; foreach($f in 'newlink_update.sh','LEIA-ME.txt'){ $n++; if((Test-Path -LiteralPath ($d+'\'+$f)) -and ((Get-FileHash -LiteralPath ($s+'\'+$f)).Hash -eq (Get-FileHash -LiteralPath ($d+'\'+$f)).Hash)){ Write-Host ('     OK    '+$f) } else { Write-Host ('     FALHA '+$f); $bad++ } }; if($n -lt 14){ Write-Host '     FALHA lista de md5 nao encontrada'; $bad++ }; if($bad -gt 0){ exit 1 }"
if errorlevel 1 (
  echo.
  echo  [ERRO] algum arquivo NAO confere com a lista. NAO use este pendrive: copie de novo.
  pause
  goto :menu
)
if "%COMFW%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%\install-firmware-pendrive.ps1" -Modo copiar -Dest "%DST%" -Firmware "%HERE%\firmware"
  if errorlevel 1 (
    echo.
    echo  [ERRO] o firmware de resgate NAO ficou bom no pendrive. NAO use este pendrive: copie de novo.
    pause
    goto :menu
  )
)
echo.
echo  [OK] kit v2 completo e conferido em %DST%\ . Desligue o projetor, plugue o pendrive e LIGUE.
pause
goto :menu

REM ---- helpers ----

:backup_panelparam
REM backup do panelparam ANTES de gravar (a lvdsctl grava o byte na particao). Um por dia: o do
REM 1o uso do dia guarda o estado anterior a qualquer mudanca desse dia. exit /b 1 se nao confirmar.
REM O nome leva o serial: o backup do dia de OUTRO aparelho nao pode ser reaproveitado.
set "HOJE="
for /f %%D in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd" 2^>nul') do set "HOJE=%%D"
if not defined HOJE set "HOJE=semdata"
set "PPSN="
for /f "delims=" %%S in ('"%ADB%" -s %DEV% shell getprop ro.serialno 2^>nul') do set "PPSN=%%S"
if defined PPSN set "PPSN=%PPSN: =%"
REM serial ilegivel = nome unico, entao nunca reaproveita (sempre faz backup novo)
if not defined PPSN set "PPSN=semserial-%RANDOM%"
if not exist "%HERE%\backups-projetor" mkdir "%HERE%\backups-projetor"
set "PPBK=%HERE%\backups-projetor\panelparam.backup-%PPSN%-%HOJE%.img"
if exist "%PPBK%" (
  echo  [OK] backup do dia ja existe: %PPBK%
  exit /b 0
)
echo  backup do panelparam antes de gravar ...
"%ADB%" -s %DEV% exec-out "dd if=/dev/block/by-name/panelparam 2>/dev/null" > "%PPBK%.tmp"
set "PPSZ="
for %%F in ("%PPBK%.tmp") do set "PPSZ=%%~zF"
REM a particao panelparam tem 8 MiB; tamanho diferente = dd truncado ou sem root
if not "%PPSZ%"=="8388608" (
  del "%PPBK%.tmp" >nul 2>&1
  echo  [ERRO] backup do panelparam invalido ^(%PPSZ% bytes, esperado 8388608^) - NAO vou gravar.
  exit /b 1
)
move /y "%PPBK%.tmp" "%PPBK%" >nul
echo  [OK] backup do panelparam salvo em %PPBK%
exit /b 0

:ask_ip
REM herda PFL_IP do ambiente se ja estiver definido (set PFL_IP=x.x.x.x)
if not defined PFL_IP set /p "PFL_IP=  IP do projetor (ex 192.168.0.50): "
if "%PFL_IP%"=="" (
  echo  [ERRO] IP vazio. Dica: set PFL_IP=x.x.x.x antes de rodar, ou digite agora.
  exit /b 1
)
REM aceita IP puro (acrescenta a porta padrao) ou IP:porta (usa como veio)
if not "%PFL_IP::=%"=="%PFL_IP%" (
  set "DEV=%PFL_IP%"
) else (
  set "DEV=%PFL_IP%:%PORT%"
)
exit /b 0

:connect
echo  conectando %DEV% ...
"%ADB%" connect %DEV% >nul 2>&1
"%ADB%" -s %DEV% wait-for-device >nul 2>&1
"%ADB%" -s %DEV% root >nul 2>&1
timeout /t 2 /nobreak >nul
"%ADB%" connect %DEV% >nul 2>&1
"%ADB%" -s %DEV% wait-for-device >nul 2>&1
for /f "delims=" %%M in ('"%ADB%" -s %DEV% shell getprop ro.product.model 2^>nul') do set "MODEL=%%M"
set "MODEL=%MODEL: =%"
if /i not "%MODEL%"=="PFL7560" (
  echo  [ERRO] Dispositivo em %PFL_IP% nao e PFL7560 ^(model='%MODEL%'^). Abortado.
  exit /b 1
)
REM 'adb root' falha em silencio: confere o id de verdade antes de dizer root
"%ADB%" -s %DEV% shell id 2>nul | findstr /c:"uid=0(" >nul
if errorlevel 1 (
  echo  [OK] PFL7560 em %PFL_IP% ^(ATENCAO: SEM root - o id nao e uid=0; gravar e ler particoes pode falhar^)
) else (
  echo  [OK] PFL7560 em %PFL_IP% ^(root confirmado^)
)
exit /b 0

:backup_stock
if not exist "%HERE%\backups-projetor" mkdir "%HERE%\backups-projetor"
set "BK=%HERE%\backups-projetor"
if not exist "%BK%\ZYCustom.ini.STOCK" (
  echo  backup ZYCustom.ini ...
  "%ADB%" -s %DEV% pull /vendor/etc/ZYCustom.ini "%BK%\ZYCustom.ini.STOCK" >nul
)
if not exist "%BK%\build.prop.STOCK" (
  echo  backup build.prop ...
  "%ADB%" -s %DEV% pull /vendor/build.prop "%BK%\build.prop.STOCK" >nul
)
if not exist "%BK%\init.bigfish.rc.STOCK" (
  echo  backup init.bigfish.rc ...
  "%ADB%" -s %DEV% pull /vendor/etc/init/hw/init.bigfish.rc "%BK%\init.bigfish.rc.STOCK" >nul
)
if not exist "%BK%\ZYCustom.ini.STOCK" exit /b 1
if not exist "%BK%\build.prop.STOCK" exit /b 1
if not exist "%BK%\init.bigfish.rc.STOCK" exit /b 1
echo  [OK] backups em %BK%
exit /b 0

:find_adb
set "ADB="
where adb >nul 2>&1 && (
  for /f "delims=" %%A in ('where adb') do (
    set "ADB=%%A"
    goto :eof
  )
)
if exist "%TOOLS%\adb.exe" (
  set "ADB=%TOOLS%\adb.exe"
  goto :eof
)
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
  set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  goto :eof
)
if exist "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
  set "ADB=%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe"
  goto :eof
)
goto :eof

:install_adb
REM 1) winget
where winget >nul 2>&1
if not errorlevel 1 (
  echo  tentando winget install Google.PlatformTools ...
  winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements
  call :find_adb
  if defined ADB goto :eof
)

REM 2) chocolatey
where choco >nul 2>&1
if not errorlevel 1 (
  echo  tentando choco install adb ...
  choco install adb -y
  call :find_adb
  if defined ADB goto :eof
)

REM 3) download zip oficial Google
echo  baixando platform-tools oficiais (Google)...
set "ZIP=%TEMP%\platform-tools-pfl7560.zip"
set "URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
if not exist "%HERE%\tools" mkdir "%HERE%\tools"

where curl >nul 2>&1
if not errorlevel 1 (
  curl -L --fail -o "%ZIP%" "%URL%"
) else (
  powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%ZIP%' -UseBasicParsing } catch { exit 1 }"
)
if not exist "%ZIP%" (
  echo  [ERRO] download falhou
  exit /b 1
)

echo  extraindo para tools\ ...
powershell -NoProfile -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%HERE%\tools' -Force"
if exist "%TOOLS%\adb.exe" (
  echo  [OK] adb em %TOOLS%\adb.exe
  exit /b 0
)
echo  [ERRO] extracao nao produziu adb.exe
exit /b 1
