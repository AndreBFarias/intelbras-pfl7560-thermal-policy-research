# 13 - Auditoria dos outros bugs (logs ao vivo + firmware)

Baseado no pacote de logs em `artefatos/diagnostico/audit-logs/` (logcat, dmesg, getprop, dumpsys, packages).

## 1. Wi-Fi nao reconecta apos reboot - BUG REAL, FIXAVEL (severidade alta)

**Causa raiz:** a propriedade **`vendor.newlink.wifi_disconnect_on_boot=1`** (em `/vendor/build.prop`, linha 70)
faz o app **NewLinkService** chamar `WifiManager.disableNetwork()` na rede salva **a cada boot**, deixando-a em
`NETWORK_SELECTION_DISABLED_BY_WIFI_MANAGER`. Nesse estado o auto-join do Android **ignora** a rede - so volta com
uma reconexao **manual** (selecao explicita). E **comportamento intencional do firmware por prop**, nao bug de driver.

- Evidencia: `getprop` linha 527 `[vendor.newlink.wifi_disconnect_on_boot]: [1]`; logcat mostra a rede indo a
  `NETWORK_SELECTION_PERMANENTLY_DISABLED`; dmesg mostra `cfg80211_unlink Beholder` ~32 s apos o boot.
- **Correcao:** `vendor.newlink.wifi_disconnect_on_boot=0` em `/vendor/build.prop` + reboot. E `build.prop` estatica
  (nao `persist.*`), entao precisa editar o arquivo (vendor rw ou repack) - nao adianta `setprop` em runtime.
- Chip Wi-Fi: **dongle USB AICSemi** (nao o radio interno HiSilicon). Os 26 erros `WifiVendorHal` sao **benignos**
  (o HAL AIC nao implementa link-layer-stats/APF - so ruido de polling). Quedas intermitentes: possivel
  BT-coex/power-save do driver AIC (secundario, nao comprovado).

## 2. PowerManagerService (218 erros) - BENIGNO (so ruido de log)

Todas as 218 sao a mesma string `"screensaver enable true"` logada em nivel ERROR por uma PowerManagerService
modificada pelo vendor. Estado de energia **saudavel** (Awake, DisplayReady, sem wakelock leak, tela nunca dorme =
modo signage). **Nao afeta o usuario.** Nada a corrigir.

## 3. Apps / USB / player - sem crash, mostly benigno (severidade baixa)

- **Nenhum crash/ANR.** Os `E/ActivityManager`, `E/TaskPersister`, `E/ActivityThread` sao logging do vendor em
  nivel errado (comportamento normal). Player de video, troca de fonte e **USB (pen drive/host) OK**.
- Unico bug funcional: um **loop de retry** tentando iniciar o servico de voz/espelhamento `com.gsk.xirivoice`
  (pacote **nao instalado** nesta build) ~1x/s -> gasta CPU/log. O servico de espelhamento (`xiriservice`/eShare)
  roda no **dominio SELinux errado** (`u:r:tee:s0`) e so funciona porque o SELinux esta permissivo.

## 4. Seguranca / qualidade de release - RUIM (mas foi o que permitiu o conserto)

Build de engenharia em produto de varejo: `userdebug` + `dev-keys`, **adb root aberto por padrao** (USB + TCP 5555),
**sem dm-verity**, updater **sem assinatura** (so CRC), **SELinux permissivo** com dezenas de `avc denied`.
Implicacao: qualquer um na rede local pega **root via adb** sem senha. Uma release de producao deveria ter `user`
build, AVB/verity, adb desligado, SELinux enforcing e update assinado. (Ironia: foi esse descuido que nos deixou
consertar o aparelho.)

## Resumo de prioridade

| Bug | Severidade | Conserto |
|---|---|---|
| Sensor termico desligado (mux) | CRITICO | FEITO (nossa build) |
| Wi-Fi nao reconecta pos-boot | Alta | FEITO (fix2, ver doc 14): `wifi_disconnect_on_boot=0` em `/vendor/build.prop` |
| Espelhamento xiri (retry + SELinux) | Baixa-media | FEITO (fix3, ver doc 14): `xiriservice` disabled (remover retry / rotular dominio) |
| PowerManager / ActivityManager logs | Cosmetico | nada a fazer |
| Postura de seguranca | Alta (design) | responsabilidade da Intelbras |
