# 13 - Auditoria dos outros bugs (logs ao vivo + firmware)

Baseado no pacote de logs em `artefatos/diagnostico/audit-logs/` (logcat, dmesg, getprop, dumpsys, packages).

## 1. Wi-Fi não reconecta após reboot - BUG REAL, FIXÁVEL (severidade alta)

**Causa raiz:** a propriedade **`vendor.newlink.wifi_disconnect_on_boot=1`** (em `/vendor/build.prop`, linha 70)
faz o app **NewLinkService** chamar `WifiManager.disableNetwork()` na rede salva **a cada boot**, deixando-a em
`NETWORK_SELECTION_DISABLED_BY_WIFI_MANAGER`. Nesse estado o auto-join do Android **ignora** a rede - só volta com
uma reconexão **manual** (seleção explícita). É **comportamento intencional do firmware por prop**, não bug de driver.

- Evidência: `getprop` linha 527 `[vendor.newlink.wifi_disconnect_on_boot]: [1]`; logcat mostra a rede indo a
  `NETWORK_SELECTION_PERMANENTLY_DISABLED`; dmesg mostra `cfg80211_unlink Beholder` ~32 s após o boot.
- **Correção:** `vendor.newlink.wifi_disconnect_on_boot=0` em `/vendor/build.prop` + reboot. É `build.prop` estática
  (não `persist.*`), então precisa editar o arquivo (vendor rw ou repack) - não adianta `setprop` em runtime.
- Chip Wi-Fi: **dongle USB AICSemi** (não o rádio interno HiSilicon). Os 26 erros `WifiVendorHal` são **benignos**
  (o HAL AIC não implementa link-layer-stats/APF - só ruído de polling). Quedas intermitentes: possível
  BT-coex/power-save do driver AIC (secundário, não comprovado).

## 2. PowerManagerService (218 erros) - BENIGNO (só ruído de log)

Todas as 218 são a mesma string `"screensaver enable true"` logada em nível ERROR por uma PowerManagerService
modificada pelo vendor. Estado de energia **saudável** (Awake, DisplayReady, sem wakelock leak, tela nunca dorme =
modo signage). **Não afeta o usuário.** Nada a corrigir.

## 3. Apps / USB / player - sem crash, mostly benigno (severidade baixa)

- **Nenhum crash/ANR.** Os `E/ActivityManager`, `E/TaskPersister`, `E/ActivityThread` são logging do vendor em
  nível errado (comportamento normal). Player de vídeo, troca de fonte e **USB (pen drive/host) OK**.
- Único bug funcional: um **loop de retry** tentando iniciar o serviço de voz/espelhamento `com.gsk.xirivoice`
  (pacote **não instalado** nesta build) ~1x/s -> gasta CPU/log. O serviço de espelhamento (`xiriservice`/eShare)
  roda no **domínio SELinux errado** (`u:r:tee:s0`) e só funciona porque o SELinux está permissivo.

## 4. Segurança / qualidade de release - RUIM (mas foi o que permitiu o conserto)

Build de engenharia em produto de varejo: `userdebug` + `dev-keys`, **adb root aberto por padrão** (USB + TCP 5555),
**sem dm-verity**, updater **sem assinatura** (só CRC), **SELinux permissivo** com dezenas de `avc denied`.
Implicação: qualquer um na rede local pega **root via adb** sem senha. Uma release de produção deveria ter `user`
build, AVB/verity, adb desligado, SELinux enforcing e update assinado. (Ironia: foi esse descuido que nos deixou
consertar o aparelho.)

## Resumo de prioridade

| Bug | Severidade | Conserto |
|---|---|---|
| Sensor térmico desligado (mux) | CRÍTICO | FEITO (nossa build) |
| Wi-Fi não reconecta pós-boot | Alta | FEITO (fix2, ver doc 14): `wifi_disconnect_on_boot=0` em `/vendor/build.prop` |
| Espelhamento xiri (retry + SELinux) | Baixa-média | FEITO (fix3, ver doc 14): `xiriservice` disabled (remover retry / rotular domínio) |
| PowerManager / ActivityManager logs | Cosmético | nada a fazer |
| Postura de segurança | Alta (design) | responsabilidade da Intelbras |
