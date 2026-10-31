# Bloco 14 - Levar ao kit o que foi feito à mão no aparelho (2026-10-31)

Tudo abaixo foi feito no projetor do dono por adb em 2026-10-31 e provado lá. Ainda **não** está no kit do
pendrive: um aparelho novo, ou este depois de regravar o firmware, não recebe estas mudanças. O dono autorizou
("pode tocar todo o resto").

## O que entra no kit (`newlink_update.sh`, `suite-boot.sh`, `suite.sh --desinstalar`)

| Mudança | Como foi feita à mão | Como o kit faz |
|---|---|---|
| 9 sobreposições Drácula (`artifacts/overlay/apk/PFL7560Tema*.apk`, blocos 13A e 16A) | `/vendor/overlay/<Nome>/<Nome>.apk`, 0755/0644 root, `vendor_overlay_file`; reboot; `cmd overlay enable com.pfl7560.tema.<x>` | no molde do `KIT_APPS`: lista `KIT_OVERLAYS`, gravadas na janela rw do `/vendor` e idempotentes por conteúdo. O `enable` precisa do `system_server`: o `suite-boot.sh` liga as instaladas e desligadas, uma vez por boot, **com a do `android` por último**. O desinstalar desliga e remove todas |
| Gerenciador de arquivos abrindo direto na lista | `vendor.nl.filemanage_file=1` no `/vendor/build.prop` | linha no `build.prop`, como a da home (`gravar_home_prop`); o desinstalar tira |
| Office, iOSCast e Espelhamento desligados | `pm disable-user --user 0` em `com.mobisystems.editor.office_registered`, `com.newlink.cast` e `com.hisilicon.miracast`; esperar uns 10 s antes de reiniciar, porque o estado é gravado com atraso | o `suite-boot.sh` desliga os que estiverem ligados, uma vez por boot, e confere no `package-restrictions.xml` (`enabled="3"`). O desinstalar religa (`pm enable`) |
| Marca MeowCast no `/atv/bootvideo/logo.jpg` e no `bootanimation.zip` (`artifacts/tema/marca/`) | `cat` por cima, que preserva dono e rótulo; backup dos originais em `evidencias/logo-fabrica/` | o kit grava os dois com backup no `/data/vendor/pfl7560-suite/` (a 1ª vez só), confere o md5 e restaura no desinstalar |
| Marca na partição `logo` (imagem do carregador, distorcida pelos 4 pontos do aparelho) | `artifacts/tema/gerar-marca.py` com os cantos lidos do aparelho; cabeçalho `LOGO_TABLE` com `LOGO_KEY_LEN` no 0x78 e JPEG no byte 8192; backup da partição inteira (40 MB) | **fora do pendrive**, porque a imagem depende dos cantos de cada aparelho e é a partição do carregador. Vai num script de PC `pfl7560-marca.sh`: lê os cantos por adb, gera, faz o backup, confere o md5 antes e grava com `dd` (sem `conv`, que o toybox recusa). Relê e confere. Tem o modo `--restaurar <backup>` |
| VLC 3.7.1 em `/vendor/app/VLC` | APK oficial (sha256 `a6a7f940...d8a0`) + `lib/arm/*.so` extraídas | **fora do git** (47 MB). Script de PC `pfl7560-vlc.sh`: baixa do get.videolan.org, confere o sha256 publicado e a assinatura (VideoLAN, SHA-256 do certificado `c8768d2c...f68e`), extrai as `lib/armeabi-v7a`, instala por adb com remount e reinicia. Modo `--remover` |

## Regras

- O kit continua ASCII puro; md5 só pelo `tests/atualizar-md5-kit.sh`, que passa a listar os APKs das
  sobreposições, conferidos contra `artifacts/overlay/apk/`.
- Cada item novo tem casos no `tests/test-kit-pendrive.sh` ou no `tests/test-suite.sh`: instala, 2ª vez
  idempotente, remount falha, desinstalar reverte.
- Os scripts de PC seguem o estilo dos `pfl7560-*.sh` e ganham um harness com adb falso, como o
  `tests/test-processos.sh`.
- Docs: doc 44 (o que o kit faz agora), `INSTALL.md`, `LEIA-ME.txt` do kit.
