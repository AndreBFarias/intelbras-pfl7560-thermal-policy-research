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
2. Copie o **kit v2 completo** para a **raiz** do pendrive (os arquivos soltos na raiz, não a pasta `pendrive-autorun`):
   - `pendrive-autorun/newlink_update.sh`
   - `pendrive-autorun/cor.sh`
   - `pendrive-autorun/lvdsctl`
   - `pendrive-autorun/ZYCustom.ini`
   - `pendrive-autorun/LEIA-ME.txt`
   - `pendrive-autorun/kit/*.png` (seis imagens, na subpasta `kit/` do pendrive)

   O jeito certo é pelo instalador, que copia tudo e **confere o md5 de cada arquivo depois da cópia**
   contra a lista embutida no `newlink_update.sh`: no Linux/macOS `./install.sh --pendrive /caminho/do/pendrive`,
   no Windows `install.bat` opção 5 (pede a letra do pendrive). Se um arquivo não conferir, não use o pendrive.
   O aparelho faz a mesma conferência e **aborta sem escrever nada** se faltar ou divergir qualquer arquivo.
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

**Jeito recomendado — 12 checagens de uma vez:**

```bash
PFL_IP=<ip> ./pfl7560-saude.sh            # 0 = tudo certo, 1 = algo falhou
PFL_IP=<ip> ./pfl7560-saude.sh --idempotencia   # roda 2x e confere que o veredito nao muda
PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade     # a prova FORTE: pergunta se a protecao reage
```

No menu: opção **5**. Ele confere os 3 arquivos corrigidos, o mux destravado, a escada de brilho, se a
proteção está **enxergando neste boot**, e a correção de cor do painel. Nas duas primeiras formas não
escreve nada e não toca o sensor, então pode rodar quantas vezes quiser.

**A prova que decide é o teste de vivacidade:** `PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade`. Ele injeta
71 °C por ~40 s pela propriedade `vendor.zy.power.tm.temp` e pergunta ao firmware se a política **reage**:
se o `Overheat Warning` sair e a escada de brilho descer até 850 e voltar sozinha, a proteção está viva
**agora**, sem margem para dúvida. É o único teste **positivo** da proteção que existe. Diferente das
outras duas formas, este **não é read-only**: escreve a propriedade, mexe no brilho e grava log em
`evidencias/vivacidade/` — o override é limpo ao final aconteça o que acontecer.

**A ausência de `LSADC Error` no buffer NÃO prova que a proteção está viva.** O erro só aparece em **2 de
cada 10** iterações do loop térmico, e o ring do logcat dura **60-150 s** neste aparelho: zero ocorrências
pode significar apenas que você não olhou tempo suficiente, ou que o buffer rolou. O grep continua
valendo como sinal **positivo** — se `LSADC Error` aparecer, algo está errado de fato, e **reiniciar o
projetor** é o que restaura a proteção. Mecanismo em
[`docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md`](docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md).

**Outras formas:**

- **De olho/ouvido:** ventiladores no talo + brilho estável.
- **Pelo pendrive:** `newlink_update.log` com `CORRECAO APLICADA COM SUCESSO`.
- **Sondando** (`PFL_IP=... ./pfl7560-fix.sh status`): espera-se `NTC count:2`, `fan speed:1000`, e no
  ini `HW_VIRTUAL_CHANNEL = 1` no 2º termistor. **Use com moderação** — ver o aviso abaixo.

## Acompanhar durante o uso

A escada de brilho só atua quando a óptica passa de 66 °C, então ela não aparece num teste rápido: é
preciso observar durante uso real. Para isso existe o vigia, que fica de fora e só lê o log:

```bash
PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh            # acompanha (Ctrl-C para parar)
PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh --resumo   # o que ja foi observado
```

No menu: opção **6**. Ele anota quando o brilho baixa sozinho (a escada protegendo a óptica) e quando
volta a subir, se algum ventilador sair do máximo, e se a proteção cegar.

> **Aviso — não deixe um sondador rodando durante o uso.** Não é a sondagem em si que faz mal: `gtt N`
> avança o anel de amostras do termistor `N` **e só dele** ([doc 37](docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md)),
> então `gtt 0` **e** `gtt 1` **em par** avançam um anel cada e **preservam a fase** — foi o que os 1060
> comandos `gtt` do histórico fizeram, com **zero** episódios. O que arrisca cegar a proteção
> (`LSADC Error`) é sondagem **ÍMPAR**: um `gtt` sozinho, os canais crus do LSADC, **ou um par
> interrompido no meio** — que é exatamente o que um `timeout` de adb produz.
>
> Daí a regra prática: as ferramentas que leem o sensor pelo `hidebug` (`pfl7560-fix.sh status`,
> `pfl7560-evidencias.sh`, `pfl7560-monitor-termico.sh`, `pfl7560-autocaptura.sh`) devem ser usadas
> **pontualmente, com o aparelho supervisionado**, e **nunca deixadas rodando como serviço** — quanto
> mais pares emitidos, maior a chance de um deles ser cortado no meio. Para acompanhamento contínuo use
> os passivos: `pfl7560-saude.sh`, `pfl7560-vigia-lsadc.sh` e `pfl7560-monitor-props.sh`. Detalhes em
> [`docs/research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md`](docs/research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md).

## Reverter

`PFL_IP=... ./pfl7560-fix.sh revert` (restaura o backup do stock) ou regrave o firmware de fábrica pela “Atualização local do sistema”.

**Dois modelos.** O `pfl7560-fix.sh` detecta o modelo do aparelho (`CONFIG_MODEL` do `ZYCustom.ini` e
`ro.newlink.projectname`): o com USB-C (V1.0.0.9) e o sem USB-C (V1.0.0.1, “NOTYPEC”, doc 42). O backup do
modelo sem USB-C fica em `backups-projetor/notypec/` e o revert só restaura backup **do mesmo modelo**
(o `build.prop` de um dá ao outro uma entrada USB-C fantasma e o canal de OTA errado). Modelo desconhecido
ou sinais contraditórios: recusa, sem tocar em nada. O `install.bat` só aplica/reverte no modelo com USB-C
e recusa o outro (use o pendrive ou o `pfl7560-fix.sh`).
Resgate com boot travado: [`docs/guide/16-recuperacao-brick.md`](docs/guide/16-recuperacao-brick.md) — use **somente** o `.bin` de fábrica como `usb_update.bin`.

## O que **não** fazer

- **Nunca** renomear um `.bin` experimental para `usb_update.bin` — resgate é **só** o firmware de fábrica.
- Não distribua/flashe `.bin` caseiro sem validar boot + metadados (ver `artifacts/bin-build/`).

---

## Reparo relacionado — correção de cor (só se você **trocou** o painel LCD)

Tema distinto do térmico. Se você substituiu o micro-painel por uma variante de sufixo diferente
(ex.: `RX058B-4300` de fábrica → `RX058B-0600`) e as cores dos **meios-tons** saíram erradas, é
mapeamento LVDS divergente (VESA vs JEIDA), corrigível **por software**. **Não** aplique isto num
aparelho com o painel de fábrica — mudaria a cor para errado.

- **Linux / macOS:** `PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard` (faz backup do painel e testa VESA/JEIDA
  na tela), ou `./pfl7560-menu.sh` → opção **4**. Direto: `... jeida` (corrige o `-0600`) / `... vesa`.
- **Windows:** `install.bat` → opção **6**. O wizard completo e o backup/restore usam WSL
  (`wsl ./pfl7560-lcd-color.sh wizard`).

Diagnóstico e detalhes: [`docs/research/28-troca-painel-rx058b-diagnostico-cor.md`](docs/research/28-troca-painel-rx058b-diagnostico-cor.md).
