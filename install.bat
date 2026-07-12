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
echo     5^) Abrir pasta pendrive-autorun (metodo SEM PC^)
echo     6^) Corrigir COR (so se voce TROCOU o painel LCD^)
echo     7^) Sair
echo.
set /p "OP=  Escolha [1-7]: "

if "%OP%"=="1" goto :do_check
if "%OP%"=="2" goto :do_status
if "%OP%"=="3" goto :do_apply
if "%OP%"=="4" goto :do_revert
if "%OP%"=="5" goto :do_pendrive
if "%OP%"=="6" goto :do_lcd
if "%OP%"=="7" exit /b 0
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

:do_status
call :ask_ip || goto :menu
call :connect || goto :menu
echo.
echo  --- estado ---
"%ADB%" -s %DEV% shell "printf 'custom\ngtc\ngtt 0\ngtt 1\ngfs 0\ngfs 1\nquit\n'|/vendor/bin/hidebug" 2>nul | findstr /i "NTC fan"
"%ADB%" -s %DEV% shell "grep -aE 'HW_VIRTUAL_CHANNEL|POLICY_0_SPEED' /vendor/etc/ZYCustom.ini; grep -a wifi_disconnect_on_boot /vendor/build.prop; getprop init.svc.xiriservice" 2>nul
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
"%ADB%" -s %DEV% shell "grep -q 'HW_VIRTUAL_CHANNEL = 1' /vendor/etc/ZYCustom.ini.new && chmod 644 /vendor/etc/ZYCustom.ini.new && mv /vendor/etc/ZYCustom.ini.new /vendor/etc/ZYCustom.ini"
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

"%ADB%" -s %DEV% shell "grep -q 'HW_VIRTUAL_CHANNEL = 1' /vendor/etc/ZYCustom.ini && grep -q wifi_disconnect_on_boot=0 /vendor/build.prop"
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
echo  Correcao de cor pos-troca de painel ^(RX058B -4300 -^> -0600^).
echo  So use se voce TROCOU o micro-painel LCD e as cores dos meios-tons sairam erradas.
echo    a^) Ver o formato LVDS atual (nao muda nada^)
echo    c^) Aplicar JEIDA  (corrige o -0600^)
echo    d^) Voltar p/ VESA (padrao de fabrica -4300^)
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
echo  Metodo SEM PC:
echo    1. Formate um pendrive FAT32 ^(MBR^)
echo    2. Copie para a RAIZ:
echo         newlink_update.sh
echo         ZYCustom.ini
echo       ^(pasta: %HERE%\pendrive-autorun^)
echo    3. Projetor DESLIGADO -^> plugue -^> LIGUE
echo  Detalhes: pendrive-autorun\LEIA-ME.txt
echo.
explorer "%HERE%\pendrive-autorun"
pause
goto :menu

REM ---- helpers ----

:ask_ip
REM herda PFL_IP do ambiente se ja estiver definido (set PFL_IP=x.x.x.x)
if not defined PFL_IP set /p "PFL_IP=  IP do projetor (ex 192.168.0.50): "
if "%PFL_IP%"=="" (
  echo  [ERRO] IP vazio. Dica: set PFL_IP=x.x.x.x antes de rodar, ou digite agora.
  exit /b 1
)
set "DEV=%PFL_IP%:%PORT%"
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
echo  [OK] PFL7560 em %PFL_IP% ^(root^)
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
