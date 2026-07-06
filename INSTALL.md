# Instalação — PFL7560 Fix

Três formas de aplicar a mesma correção. **Dependências:** veja [`REQUIREMENTS.md`](REQUIREMENTS.md).
Nada aqui toca no bootloader; tudo é reversível.

---

## Método 1 — Pendrive autorun (mais fácil, sem PC, sem adb)

O firmware do PFL7560 executa `nl_usb_update.sh` a cada boot, que roda como root qualquer
`newlink_update.sh` achado num pendrive. Usamos exatamente isso.

1. Formate um pendrive em **FAT32 (MBR)**.
2. Copie para a **raiz** do pendrive:
   - `pendrive-autorun/newlink_update.sh`
   - `pendrive-autorun/ZYCustom.ini`
3. Com o projetor **desligado**, plugue o pendrive numa porta USB dele.
4. **Ligue.** Ele aplica a correção e **reinicia sozinho** uma vez (~1 min). Se na 1ª vez não aplicar
   (pendrive montou tarde), reinicie mais uma vez.
5. Confirme: tela mais clara + ventiladores barulhentos, e um arquivo **`newlink_update.log`** aparece
   no pendrive com o passo a passo. Pode remover o pendrive.

É **idempotente** (se já estiver aplicado, não faz nada) e só age se o modelo for `PFL7560`.

---

## Método 2 — Script no PC (adb por Wi-Fi)

Requer `adb` no PC e o projetor **ligado no mesmo Wi-Fi**.

```bash
./pfl7560-fix.sh status     # le o estado (nao muda nada)
./pfl7560-fix.sh apply      # backup + aplica os 3 fixes + reinicia
./pfl7560-fix.sh revert     # restaura o /vendor de fabrica (do backup)
```

Se a busca automática (nmap por MAC) não achar o projetor, informe o IP:

```bash
PFL_IP=192.168.0.50 ./pfl7560-fix.sh apply
```

O IP aparece no projetor em *Configurações → Wi-Fi → (rede conectada)*. O script faz backup do stock em
`backups-projetor/` antes de mudar qualquer coisa.

**Duplo-clique (Linux):** use `PFL7560-Corrigir.desktop` (abre um menu no terminal). Na 1ª vez o
GNOME/Pop pode pedir botão direito → *Permitir Execução*.

---

## Método 3 — Manual (adb, para quem quer entender)

Comandos crus (remount + push da config + edição de props) documentados em
[`mod-termica-PFL7560/06-acesso-adb-e-comandos.md`](mod-termica-PFL7560/06-acesso-adb-e-comandos.md).
Resumo:

```bash
adb connect <ip>:5555
adb root && adb connect <ip>:5555
adb remount
adb push pendrive-autorun/ZYCustom.ini /vendor/etc/ZYCustom.ini
adb shell "sed -i 's/wifi_disconnect_on_boot=1/wifi_disconnect_on_boot=0/' /vendor/build.prop"
adb shell "sed -i '/^service xiriservice \/system\/bin\/xiriservice/a\\    disabled' /vendor/etc/init/hw/init.bigfish.rc"
adb shell sync && adb reboot
```

---

## Verificar se aplicou

- **De olho/ouvido:** tela clara + ventiladores no talo = ativo.
- **Pelo PC:** `./pfl7560-fix.sh status` mostra `NTC count:2`, `fan speed:1000`, brilho 1000.
- **Pelo pendrive:** o `newlink_update.log` traz a linha `CORRECAO APLICADA COM SUCESSO`.

## Reverter

`./pfl7560-fix.sh revert` (restaura o backup do stock) ou regrave o firmware de fábrica pela
"Atualização local do sistema" no menu do projetor. Para ficar 100% stock via pendrive, remova o
pendrive do autorun antes de reiniciar.
