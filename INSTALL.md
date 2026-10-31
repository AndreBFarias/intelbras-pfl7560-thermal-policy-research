# Instalação — correção térmica PFL7560

Três formas de aplicar a **mesma** correção. Dependências: [`requirements`](requirements) · [`REQUIREMENTS.md`](REQUIREMENTS.md).
Nada aqui toca no bootloader; tudo é reversível (métodos 1–3).

**Alvo:** Intelbras PFL7560 com o firmware de fábrica **V1.0.0.9** (modelo com entrada USB-C) ou
**V1.0.0.1** (modelo sem USB-C, "NOTYPEC", fabricado a partir de 25/08/2026;
[doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md)). O kit de pendrive, o `pfl7560-fix.sh` e o
builder servem aos dois; no V1.0.0.1 tudo foi provado **só em simulação**. A térmica de fábrica é a mesma
nos dois, com o mesmo bug do mux.

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
   - `pendrive-autorun/nl_camcheck` (lê a câmera interna, para o teste de cor automático)
   - `pendrive-autorun/ZYCustom.ini`
   - `pendrive-autorun/LEIA-ME.txt`
   - `pendrive-autorun/suite.sh`, `suite-boot.sh`, `suite-pedido.sh` e `pfl7560-suite.rc` (a suíte de verificação, bloco 9B)
   - `pendrive-autorun/nl_tela` (gera as telas da suíte) e `pendrive-autorun/fontes/*` (as fontes dela, na subpasta `fontes/` do pendrive)
   - `pendrive-autorun/pfl7560.apk` (o app dos ícones "Verificar projetor" e "Wi-Fi", bloco 9C)
   - `pendrive-autorun/kit/*.png` (oito imagens, na subpasta `kit/` do pendrive)

   O jeito certo é pelo instalador, que copia tudo e **confere o md5 de cada arquivo depois da cópia**
   contra a lista embutida no `newlink_update.sh`: no Linux/macOS `./install.sh --pendrive /caminho/do/pendrive`,
   no Windows `install.bat` opção 5 (pede a letra do pendrive). Se um arquivo não conferir, não use o pendrive.
   Para formatar e preparar um pendrive do zero (FAT32, com o kit e o firmware de resgate), no Linux:
   `sudo bash tests/preparar-pendrive.sh /dev/sdX`: só aceita pendrive removível por USB, pede para digitar o
   dispositivo antes de formatar e confere o md5 no fim (ver "Firmware de resgate" abaixo).
   O aparelho faz a mesma conferência e **aborta sem escrever nada** se faltar ou divergir qualquer arquivo.
3. Com o projetor **desligado**, plugue o pendrive numa porta USB dele.
4. **Ligue.** Se aparecer "AJUSTANDO", espere: a parte térmica é aplicada e o aparelho **reinicia sozinho** uma vez (~1 min). Se nenhuma tela do kit aparecer em 2 minutos, desligue e ligue de novo (o pendrive montou tarde).
5. **Teste de cor.** O projetor projeta uma escada de 16 cinzas e olha com a **câmera interna**: escada em ordem = cor certa, nada é gravado (é o caso do painel de fábrica); fora de ordem = ele troca o formato sozinho, confere de novo e mostra "COR CORRIGIDA AUTOMATICAMENTE" (qualquer tecla em 30 s desfaz). Se a câmera não ajudar, ele pergunta olhando a tela: escada fora de ordem, aperte qualquer tecla; ele mostra no outro formato, e só **mantém** se você apertar de novo diante de uma escada em ordem. Sem a segunda tecla, volta sozinho ao formato de antes.
6. **A suíte de verificação.** Depois da cor o kit roda o resto da suíte: ângulo, foco e nitidez pela câmera,
   temperatura (só leitura) e um teste da proteção térmica em que a imagem **escurece por cerca de 1 minuto** (é
   proposital), e termina num **resumo** em tela cheia (20 s; qualquer tecla fecha) e na tela "Pode tirar o
   pendrive". Tire o pendrive. Confirme: ventiladores mais audíveis + imagem estável em brilho; no pendrive ficam
   `newlink_update.log` (procure `CORRECAO APLICADA COM SUCESSO`), `newlink_cor.log` e `newlink_suite.log`.
   O mesmo pendrive instala o app `pfl7560.apk` (`pm install -r`, antes da suíte; uma falha só avisa no log) e o
   serviço de boot da suíte. **Daí em diante a suíte roda sozinha, sem pendrive,** quando o projetor volta da
   tomada, e a pedido pelo ícone **"Verificar projetor"** (o app também tem o ícone "Wi-Fi"). O ícone só passa a
   valer no **boot seguinte** à instalação (o vigia do pedido liga no boot): desligue e ligue uma vez. Um pedido
   até 10 minutos depois do fim de outra suíte é ignorado. Detalhes, arquivos e limites:
   [`docs/research/44-suite-de-boot.md`](docs/research/44-suite-de-boot.md).
7. **Para desligar a suíte:** crie um arquivo vazio `DESINSTALAR-SUITE.txt` na raiz do pendrive e ligue com ele
   plugado: remove o serviço, a pasta da suíte e o pedido, leva a cópia do backup da cor para o pendrive
   (`suite-panelparam-backup-<serial>.img`) e roda só a fase de cor. O app fica instalado, sem efeito; para tirá-lo,
   `adb uninstall com.pfl7560.verificar`.

É **idempotente** (rodar de novo não muda nada nem reinicia) e só age se o modelo for `PFL7560`. A parte
térmica reconhece o `.ini` de fábrica **dos dois modelos** (e as versões anteriores nossas) e troca **só as
seções térmicas** do `.ini` do próprio aparelho, mantendo o `CONFIG_MODEL`; `.ini` desconhecido = recusa e
avisa. Antes de mexer na cor, faz backup da `panelparam` conferido com `cmp` e grava um journal: se a
energia cair no meio do teste, o formato original volta no boot seguinte. O kit v2 foi provado **só em
simulação** (`make check-kit`); a bancada no aparelho ainda não foi feita (etapa E4 do
[bloco 5](docs/sprints/2026-10-29-bloco-5-kit-universal.md)).

**Atenção:** o recomendado é **não** colocar `usb_update.bin` no mesmo pendrive do autorun: o pendrive de **resgate** (firmware de fábrica) fica **separado** e desconectado no dia a dia. O `LEIA-ME.txt` descreve também um "kit de emergência" pessoal com os dois juntos (arranjo B), aceitável só para quem conhece o risco: ligar segurando o power com ele plugado reflasha o aparelho.

**Firmware de resgate no pendrive (arranjo B, opcional).** `./install.sh --pendrive /caminho/do/pendrive --com-firmware`
(Windows: `install.bat` opção 5, resposta `s` à pergunta do firmware) copia, além do kit, o `usb_update.bin`
**oficial V1.0.0.9** (tirado do `firmware/Software PFL7560.zip` e conferido pelo md5 `28a2f280eee313a4b115567926b2ba4f`;
**nunca** o `Firmware PFL7560.zip`, que é do modelo sem USB-C) na raiz e o nosso `.bin` em
`firmware-nosso-NAO-GRADUADO/`, com um `LEIA-ME.txt`: ele **não está ativo**, não foi provado no hardware e só vale
com a palavra do dono. O nosso `.bin` é local (`*.bin` fora do git): coloque-o em `firmware/`, ou aponte outra
pasta com `PFL_FIRMWARE_DIR=<pasta>`. Faltou um arquivo ou o md5 não bate: a opção falha e não copia nada.

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

O script/batch faz backup do stock em `backups-projetor/` antes de mudar qualquer coisa (no modelo sem
USB-C, em `backups-projetor/notypec/`; ver "Dois modelos" abaixo).

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

No menu: opção **5**. Ele confere os 3 arquivos corrigidos (no `.ini` que o firmware lê de fato: um
`/atv/ini/ZYCustom*.ini` vence o do `/vendor`), o mux destravado, a escada de brilho, se a proteção está
**enxergando neste boot**, e o formato de cor do painel. Na cor, VESA e JEIDA são ambos válidos: passa
quando o formato **em uso** bate com o byte **gravado** na `panelparam` (essa leitura exige root); para
exigir um formato, `PFL_LVDS_ESPERADO=vesa` ou `jeida`. Nas duas primeiras formas não escreve nada e não
toca o sensor, então pode rodar quantas vezes quiser.

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

A escada de brilho só atua quando o sensor quente (`gtt1`, no bloco dissipador do LED) passa de 66 °C,
então ela não aparece num teste rápido: é preciso observar durante uso real. Em 2026-10-29, com a sala a
34 °C, ela atuou no uso normal (brilho entre 944 e 974 com o `gtt1` em 65,8-68,2 °C,
[doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2). Para isso existe o vigia, que fica de fora e só lê o log:

```bash
PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh            # acompanha (Ctrl-C para parar)
PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh --resumo   # o que ja foi observado
```

No menu: opção **6**. Ele anota quando o brilho baixa sozinho (a escada cortando o calor na fonte) e quando
volta a subir, se algum ventilador sair do máximo, e se a proteção cegar.

Para medir a curva térmica: `PFL_IP=<ip> ./pfl7560-monitor-props.sh --ambiente <sala_C>` (passivo, por
props; a temperatura da sala é obrigatória). Ele separa os boots (lê o `boot_id` a cada amostra), marca
lacuna quando o aparelho some e o override do teste de vivacidade, e o `--resumo` agrupa por boot. Todos
os scripts que formatam ou comparam número fixam `LC_ALL=C`, então o resultado não muda com o idioma do PC.
A coluna `optica_C` do TSV é o `gtt1`, que mede o bloco do LED
([doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3).

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

`PFL_IP=... ./pfl7560-fix.sh revert` (restaura o backup do stock) ou regrave o firmware de fábrica **do seu modelo** pela “Atualização local do sistema” (não grave o de um modelo no outro; quem trocou o painel LCD refaz o teste de cor depois, ver o fim deste guia).

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

Tema distinto do térmico. Se você substituiu o micro-painel e a imagem saiu com **primárias certas e
preto/cinzas tingidos** (a cor do tingimento muda com a imagem), é o formato LVDS (VESA ou JEIDA) que não
casa com o painel, corrigível **por software**. **O formato não se deduz do nome do painel:** o
`RX058B-0600` da 1ª troca pediu JEIDA; o `RX058B-4300` instalado na 2ª troca (2026-10-29, o mesmo modelo
do de fábrica) pediu VESA ([doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md)
§1). Quem decide é o teste de cinza.

- **Sem PC:** o kit de pendrive do Método 1 já faz o teste da escada de cinzas (pela câmera interna, ou pelo
  controle se a câmera não ajudar). Escada em ordem = cor certa, nada é gravado. Só troca o formato com backup e
  journal antes, e desfaz com uma tecla (automático) ou só mantém com **duas** teclas (manual).
- **Linux / macOS:** `PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard` (backup obrigatório antes de gravar,
  testa JEIDA e VESA na tela e reverte sozinho se a tela apagar), ou `./pfl7560-menu.sh` → opção **4**.
  Direto, se você já viu qual formato deixa o cinza neutro: `... jeida` / `... vesa` (também fazem o
  backup do dia antes de gravar; `swap`/`bit` pedem confirmação).
- **Windows:** `install.bat` → opção **6** (`c` = JEIDA, `d` = VESA, com backup antes em
  `backups-projetor\`). O wizard completo e o backup/restore usam WSL
  (`wsl ./pfl7560-lcd-color.sh wizard`).

Num aparelho com o painel de fábrica o teste mostra a escada em ordem e nada muda. Depois de **regravar o
firmware de fábrica**, refaça o teste: a `panelparam` parece estar dentro do `.bin` e o reflash pode
devolver o formato ao de fábrica (VESA) ([doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md) §5).

Guia leigo: [`docs/guide/32-guia-troca-painel-lcd.md`](docs/guide/32-guia-troca-painel-lcd.md).
Diagnóstico e detalhes: [`docs/research/28-troca-painel-rx058b-diagnostico-cor.md`](docs/research/28-troca-painel-rx058b-diagnostico-cor.md).
