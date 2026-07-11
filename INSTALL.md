# Instalação — correção térmica PFL7560

Três formas de aplicar a **mesma** correção. Dependências: [`requirements`](requirements) · [`REQUIREMENTS.md`](REQUIREMENTS.md).
Nada aqui toca no bootloader; tudo é reversível (métodos 1–3).

**Alvo:** Intelbras PFL7560, firmware **V1.0.0.9**.

---

## 0) Preparar o PC (só se for usar adb — métodos 2/3)

| SO | Comando |
|---|---|
| **Linux / macOS** | `./install.sh` (ou `./install.sh --check`) |
| **Windows** | duplo-clique em `install.bat` |

Isso instala/localiza o `adb` (e, no Linux, tenta o `nmap` opcional). **Não grava no projetor.**
No Windows, o próprio `install.bat` tem menu para ver estado / aplicar / reverter.

Sem PC de jeito nenhum → pule para o **Método 1**.

---

## Método 1 — Pendrive autorun (recomendado para leigos)

Sem PC e sem adb. O firmware executa `newlink_update.sh` no boot (como root).

1. Formate um pendrive em **FAT32 (MBR)**.
2. Copie para a **raiz** do pendrive:
   - `pendrive-autorun/newlink_update.sh`
   - `pendrive-autorun/ZYCustom.ini`
3. Com o projetor **desligado**, plugue o pendrive numa porta USB dele.
4. **Ligue.** A correção é aplicada e o aparelho **reinicia sozinho** uma vez (~1 min). Se na 1ª vez não aplicar (pendrive montou tarde), reinicie de novo.
5. Confirme: ventiladores mais audíveis + imagem estável em brilho; no pendrive aparece `newlink_update.log` com a linha `CORRECAO APLICADA COM SUCESSO`. Pode remover o pendrive.

É **idempotente** (se já estiver aplicado, não faz nada) e só age se o modelo for `PFL7560`.

**Atenção:** não coloque `usb_update.bin` no mesmo pendrive do autorun. O pendrive de **resgate** (firmware de fábrica) deve ficar **separado** e desconectado no dia a dia.

Instruções resumidas: `pendrive-autorun/LEIA-ME.txt`.

---

## Método 2 — Script no PC (adb por Wi-Fi)

Requer `adb` no PC (`./install.sh` ou `install.bat`) e o projetor **ligado no mesmo Wi-Fi**.

O IP aparece no projetor em *Configurações → Wi-Fi → (rede conectada)*.

### Linux / macOS

```bash
./install.sh                                   # uma vez
PFL_IP=192.168.0.50 ./pfl7560-fix.sh status   # le o estado (nao muda nada)
PFL_IP=192.168.0.50 ./pfl7560-fix.sh apply    # backup + aplica os 3 fixes + reinicia
PFL_IP=192.168.0.50 ./pfl7560-fix.sh revert   # restaura o /vendor de fabrica (do backup)
```

Opcional: `PFL_MAC=aa:bb:cc:dd:ee:ff` se tiver `nmap` (busca na sub-rede).

**Menu / duplo-clique (Linux):** `./pfl7560-menu.sh` ou `PFL7560-Corrigir.desktop`.
Exporte o IP antes se precisar: `export PFL_IP=...`.

### Windows

1. Rode `install.bat` (instala adb se faltar).
2. No menu: **2** status · **3** aplicar · **4** reverter (informa o IP quando pedido).

Alternativa com WSL2: `wsl ./install.sh` e depois `wsl bash -lc 'PFL_IP=... ./pfl7560-fix.sh apply'`.

O script/batch faz backup do stock em `backups-projetor/` antes de mudar qualquer coisa.

---

## Método 3 — Manual (adb)

Comandos crus documentados em [`docs/research/06-acesso-adb-e-comandos.md`](docs/research/06-acesso-adb-e-comandos.md). Resumo:

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

- **De olho/ouvido:** ventiladores no talo + brilho estável.
- **Pelo PC:** `PFL_IP=... ./pfl7560-fix.sh status` — espera-se `NTC count:2`, `fan speed:1000`, e no ini `HW_VIRTUAL_CHANNEL = 1` no 2º termistor.
- **Pelo pendrive:** `newlink_update.log` com `CORRECAO APLICADA COM SUCESSO`.

## Reverter

`PFL_IP=... ./pfl7560-fix.sh revert` (restaura o backup do stock) ou regrave o firmware de fábrica pela “Atualização local do sistema”.
Resgate com boot travado: [`docs/guide/16-recuperacao-brick.md`](docs/guide/16-recuperacao-brick.md) — use **somente** o `.bin` de fábrica como `usb_update.bin`.

## O que **não** fazer

- **Nunca** renomear um `.bin` experimental para `usb_update.bin` — resgate é **só** o firmware de fábrica.
- Não distribua/flashe `.bin` caseiro sem validar boot + metadados (ver `artifacts/bin-build/`).
