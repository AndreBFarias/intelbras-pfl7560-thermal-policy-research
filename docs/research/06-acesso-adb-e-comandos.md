# 06 - Acesso adb e comandos de runtime (cookbook)

Resultado da pesquisa de viabilidade (workflow wq31yy1uy). Tudo abaixo é de baixo risco:
os comandos de runtime (Tier 1) NAO gravam nada e não bricam; reboot volta ao stock.

## Obter adb root (sem reflash)

O build é `userdebug` com `ro.debuggable=1`, `persist.sys.usb.config=adb`, `ro.adb.secure` ausente
(sem prompt de autorização RSA). adbd sobe no boot.

> **Correção de campo (2026-07-09).** Neste aparelho o **USB-C NÃO expõe adb** — é apenas
> entrada de vídeo ("leitura de tela"). A única via de adb confirmada em campo é a **rede
> (Wi-Fi / TCP 5555)**. A suposição original de adb por USB-C (VID 18d1 / PID 4EE7) era
> inferida e **não se confirmou** no hardware.

- **Rota principal (rede, sem cabo) — CONFIRMADA:** a porta TCP 5555 já vem aberta
  (`service.adb.tcp.port=5555`; Ethernet é prioritária).
  ```
  adb connect <IP_DO_PROJETOR>:5555
  adb root
  ```
  **Requisito de campo:** o Wi-Fi do projetor só fica ativo na **tela inicial do Android
  (launcher)**. Ao exibir uma fonte HDMI externa (ex.: dongle/stick de streaming), o Wi-Fi
  dorme e o adb some — volte ao launcher para reconectar.
- **USB-C — NÃO serve para adb** neste aparelho (só vídeo). As 2x USB-A são host-only.
- **Fallback:** menu de fábrica `HiFactoryMenu` -> "Open UartDebug" habilita console serial UART com root;
  ou `am start -n com.newlink.factorymenu/.MainActivity`.

## Pré-checagens (rodar uma vez)

```
adb shell getprop ro.boot.projectid        # se != 0, o arquivo efetivo pode ser ZYCustom_<id>.ini
adb shell ls -l /atv/ini/ZYCustom*.ini      # se existir aqui, ESTE tem precedência sobre /vendor
adb shell 'echo gfc | /vendor/bin/hidebug'  # numero de fans (esperado 2)
adb shell 'echo gbll | /vendor/bin/hidebug' # lista de niveis de brilho disponiveis
```

Precedência de leitura do `.ini` (confirmada no `libhitvservice.so`, `ZYConfig::LoadIniFile`):
`/atv/ini/ZYCustom_<projectid>.ini` -> `/atv/ini/ZYCustom.ini` -> `/vendor/etc/ZYCustom.ini`.
O primeiro que existir vence. O `.ini` é lido AO VIVO a cada boot (sem cache compilado, sem versionamento).

## Interface de comandos: `/vendor/bin/hidebug`

Não há node em `/sys` nem `service call`. Os comandos vão por `/vendor/bin/hidebug` (REPL que lê stdin e
despacha para o middleware de TV via Binder). Interativo (certo) ou por pipe (inferido, mas provável):
```
adb shell /vendor/bin/hidebug     # e digite os comandos
echo 'gtt 0' | adb shell /vendor/bin/hidebug   # forma one-shot
```

### Tabela de comandos (extraída do firmware, milésimos de grau para temperatura)

```
FANS
  sfs  <fan 0-1> <0-1000>   SetFanSpeed (duty/level)
  gfs  <fan 0-1>            GetFanSpeed (level 0-1000, NAO e RPM)
  gfc                       GetFanCount
  sfe  <fan 0-1> <0/1>      SetFanEnable
  gfe  <fan 0-1>            GetFanEnable
THERMAL
  stp  <pol>                SetThermalPolicy  (STANDARD:0 COOLING:1 QUIET:2 FAST:3 MAXSPEED:-1)
  gtp                       GetThermalPolicy
  gtt  <NTC 0-2>            GetThermalTemp (miliC; dividir por 1000)
  gtc                       GetThermalCount
BACKLIGHT (fonte de luz)
  sbe  <0/1>                SetBacklightEnable
  sbl  <level>              SetBacklightLevel (indice da lista gbll)
  gbl / gbll                GetBacklightLevel / GetBacklightLevelList
  sbp  <pol>                SetBacklightPolicy (STANDARD:0 ENERGY_SAVING:1 CUS1:2)
  sbri <bl 0-1> <0-1000>    SetBacklightBrightness (CAP DIRETO de brilho)
  gbri <bl 0-1>             GetBacklightBrightness
  gbc                       GetBacklightCount
GPIO
  sgpioe <nome> <0/1>       ex: sgpioe FAN 1   (nomes: FOCUS_CAMERA TEC FAN ...)
```

## DIAGNOSTICO - ler NTC ao vivo (Tier 1, zero risco)

```
adb root
adb shell 'while :; do date +%s; echo "gtt 0"; echo "gtt 1"; echo "gtt 2"; sleep 1; done | /vendor/bin/hidebug | tee /data/local/ntc.log'
```
Rode por ~10-15 min de uso real. Anote a leitura (miliC/1000 = C) no ponto em que hoje você considera
"quente demais". Esse número calibra o `EMERGENCY_VALUE` do build. Repita em 3 cenários: (a) stock,
(b) fans forçados a 100%, (c) brilho reduzido — para medir o ganho de cada alavanca.

## MITIGACAO IMEDIATA (Tier 1, por sessão, zero risco)

O ganho instantâneo, sem gravar nada (reseta no reboot). O `stp -1` = MAXSPEED força os fans ao máximo
sobrepondo o loop automático; `sbri` capa o brilho (o "undervolt da luz" que realmente esfria a óptica):
```
adb root
adb shell '{ echo "sfe 0 1"; echo "sfe 1 1"; echo "stp -1"; echo "sfs 0 1000"; echo "sfs 1 1000"; echo "sbri 0 700"; } | /vendor/bin/hidebug'
# voltar ao automatico:  echo "stp 0" | adb shell /vendor/bin/hidebug
```
Ressalva: o loop automático pode reassumir `sbri`; por isso forçamos `stp` e, se preciso, `sbp`.

## PERSISTENTE (Tier 2 - recomendado, reversível)

Sem dm-verity em `/vendor` (confirmado), há dois caminhos. O **preferido é o override em `/atv`**, porque
não toca em `/vendor` e é reversível apenas apagando o arquivo:

**Opção 1 - override em /atv (mais seguro, reversível):**
```
adb root
adb pull /vendor/etc/ZYCustom.ini ZYCustom.backup.ini      # BACKUP primeiro
# edite conforme 05-ZYCustom.ini-proposto.md, depois:
adb shell mkdir -p /atv/ini
adb push ZYCustom.ini /atv/ini/ZYCustom.ini                 # (ou /atv/ini/ZYCustom_<projectid>.ini se projectid!=0)
adb shell sync && adb reboot
# reverter:  adb shell rm /atv/ini/ZYCustom.ini && adb reboot
```

**Opção 2 - editar /vendor direto:**
```
adb root && adb remount            # /vendor rw (sem verity para quebrar)
adb push ZYCustom.ini /vendor/etc/ZYCustom.ini
adb shell sync && adb reboot
```

Validação pós-boot: repita o loop de `gtt` e compare a temperatura antes/depois.

## REFLASH (Tier 3 - só se quiser 1 arquivo .bin flashável; risco moderato)

O container `LOAD` é protegido por **CRC-32/MPEG-2 apenas** (sem assinatura). Cada payload tem prefixo
`[u32 size BE][u32 CRC BE]`. Repack: editar o ext4 vendor no `super.img` -> re-sparse -> recomputar o CRC da
partição modificada -> manter o tamanho total em `0x10` -> gravar via "Atualização local do sistema" (pendrive).
**Só editar vendor/system; NUNCA bootloader/recovery.** Se algo der errado com vendor/system, basta regravar o
`PFL7560.bin` stock pelo mesmo updater. Recuperação de brick de bootloader: UART bootrom do Hi3751 via HiTool/HiBurn
ou OpenIPC/burn (115200 8N1) — sobrevive até a bootloader apagada, desde que haja header UART na placa.

## Backup e recuperação (obrigatório antes de gravar)

- `adb pull` do `.ini` efetivo antes de qualquer mudança (guardar junto de `artifacts/ZYCustom.ini.ORIGINAL`).
- Guardar o `PFL7560.bin` stock (o `.zip` original) como imagem de recuperação.
- Regra de ouro: enquanto só mexer em vendor/system/data e não tocar bootloader/recovery, um erro é recuperável
  regravando o stock; brick real só se mexer na bootloader.

## Confirmado vs inferido

- CONFIRMADO: adb root disponível; sem dm-verity em /vendor; container só-CRC; tabela de comandos `cus`;
  `/vendor/bin/hidebug` como interface; precedência /atv > /vendor; `.ini` lido ao vivo por boot.
- INFERIDO (não testado em hardware): que `echo 'cmd' | hidebug` funciona one-shot (a forma interativa é certa);
  que `sbri` abaixo de ~750 é aceito pelo LED (validar com `gbll`/`sbri` ao vivo); estado do fuse de secure-boot
  (não lê de dump) — o build dev-keys/userdebug torna secure boot forçado improvável.
