# Bloco 14 - Levar ao kit o que foi feito à mão no aparelho (2026-10-31, a fazer)

Feito no projetor do dono por adb em 2026-10-31 e provado. Ainda **não** está no kit do pendrive: um aparelho
novo, ou este depois de regravar o firmware, não recebe estas mudanças.

| Mudança | Como foi feita | Prova no aparelho |
|---|---|---|
| Sobreposições Drácula do `com.zhiying.settings` e do `com.newlink.nlprovision` (bloco 13A) | `/vendor/overlay/PFL7560TemaZYSetting/` e `PFL7560TemaNLProvision/` (0755/0644 root, `vendor_overlay_file`), reboot, `cmd overlay enable com.pfl7560.tema.zysetting` e `com.pfl7560.tema.nlprovision` | `cmd overlay list` com `[x]` depois do reboot; Configurações com o fundo escuro, vistas pela câmera |
| Sobreposição do `android` (aviso de temperatura) | **não aplicada**: vai por último, com o pendrive de resgate à mão (doc 48 §7) | - |
| VLC 3.7.1 ARMv7 (oficial, sha256 `a6a7f940...d8a0`, assinado pela VideoLAN) | `/vendor/app/VLC/VLC.apk` + `lib/arm/*.so` extraídas do APK (app de sistema não extrai biblioteca nativa sozinho neste Android), 0755/0644 root, `vendor_app_file`; usa ~90 MB do `/vendor` (126 MB livres depois) | `codePath=/vendor/app/VLC`, `flags=[ SYSTEM ]`, abre a tela de boas-vindas da versão TV sem erro |
| Office (`com.mobisystems.editor.office_registered`, de fábrica) desligado | `pm disable-user --user 0` (volta com `pm enable`) | `new state: disabled-user` |

## Para o kit

1. `newlink_update.sh`: a lista de sobreposições, no molde do `KIT_APPS`, gravadas em `/vendor/overlay` na
   janela rw. O `enable` precisa do `system_server` depois do boot: o `suite-boot.sh` liga as que estiverem
   instaladas e desligadas, e o desinstalar desliga e remove.
2. O VLC é grande (47 MB de APK + 44 MB de bibliotecas). Decidir com o dono se entra no kit, que hoje tem ~2 MB
   fora o firmware de resgate, ou se fica como passo à parte com o script de PC.
3. O Office desligado: um passo do `suite-boot.sh` ou do kit (`pm disable-user`), reversível.
4. Testes no harness para cada item. As listas de md5 são regeneradas pelo script.
