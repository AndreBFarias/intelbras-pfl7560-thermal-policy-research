# intelbras-pfl7560-thermal-policy-research

Pesquisa independente de **engenharia reversa e reparabilidade** sobre um **defeito de configuração de fábrica** no projetor **Intelbras PFL7560** (firmware V1.0.0.9; o mesmo defeito segue no V1.0.0.1 de outubro de 2026, [doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md)) que torna a proteção térmica ineficaz e contribui para **falha prematura** da óptica (polarizador/LCD).

> **Aviso.** Projeto **sem vínculo com a Intelbras**. Os métodos 1–3 editam a partição `/vendor` (o kit do pendrive mexe também na cor da `panelparam`, com backup, em `/data/vendor` e no logo de boot em `/atv/bootvideo`, guardando o de fábrica), por sua conta e risco. **São reversíveis, não tocam no bootloader e o aparelho permanece recuperável.** O firmware `.bin` completo experimental está em **quarentena** (não use).

## Status da divulgação responsável

Relatório técnico preparado para o [CSIRT Intelbras](https://www.intelbras.com/pt-br/CSIRT-Intelbras). **Envio ainda pendente** (atualizar data/protocolo em [`docs/disclosure/STATUS.md`](docs/disclosure/STATUS.md) após o registro).

Esta pesquisa foi conduzida de forma **independente**, com foco em **reparabilidade** e **proteção ao consumidor**. **Este repositório é privado** (backup pessoal do reparo). Uma eventual abertura pública só ocorre após a janela de divulgação coordenada (7–10 dias úteis pós-envio, ou resposta da fabricante) **e** depois de redigir os dados sensíveis das fotos e decidir sobre o firmware proprietário — ver [`docs/research/30-sprint-validacao-repositorio.md`](docs/research/30-sprint-validacao-repositorio.md) (REPO-S2).

| Campo | Valor |
|---|---|
| **Visibilidade** | **Privado** (backup pessoal; ainda não publicado) |
| **Estado** | Relatório pronto · envio CSIRT pendente |
| **Canal** | [CSIRT Intelbras](https://www.intelbras.com/pt-br/CSIRT-Intelbras) |
| **Relatório** | [`docs/disclosure/relatorio-csirt.md`](docs/disclosure/relatorio-csirt.md) |
| **Status detalhado** | [`docs/disclosure/STATUS.md`](docs/disclosure/STATUS.md) |

## O problema (em uma frase)

A política térmica do aparelho é um arquivo de texto (`/vendor/etc/ZYCustom.ini`). Os dois termistores foram mapeados no **mesmo canal virtual** do multiplexador (`HW_VIRTUAL_CHANNEL=0`), de modo que o segundo sensor — o que enxerga o calor real do motor óptico — **nunca é lido**. O sistema opera como se estivesse frio; a refrigeração e o desligamento de proteção não acompanham a temperatura real.

> **Onde fica esse sensor (2026-10-29):** o 2º NTC (`gtt1`) é um termistor encapsulado num olhal parafusado
> no topo do **bloco dissipador do LED**. Ele mede o dissipador do LED, não o polarizador nem o LCD:
> **nenhum sensor do aparelho mede o polarizador/LCD** ([doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3).
> Onde este repositório chama o `gtt1` de "óptica" (inclusive a coluna `optica_C` dos scripts), leia
> "bloco do LED".

Detalhes técnicos: [`docs/research/08-por-que-fica-cego.md`](docs/research/08-por-que-fica-cego.md).

**Segunda proteção que não funciona (2026-07-29):** o firmware também traz uma proteção por **ventilador
travado** (desliga o aparelho se um soprador para), e ela **nunca executa**. A primeira suspeita foi omissão
de config (a seção `[FanMonitor]` falta no `ZYCustom.ini` de fábrica); o veredito final (**FAN-S1**) é
outro: o monitor é **inarmável por software** neste aparelho. Mesmo com a seção, um portão
(`SW_SENSE_TYPE = 0`) desliga a leitura, e os sopradores são de **2 fios, sem sinal de tacômetro**; a cura
seria hardware (sopradores de 3 fios com o sinal ligado a um GPIO livre). **Não arme `SW_SENSE_TYPE` sem a
fiação: é pior que deixar desarmado.** Ou seja: se um dos dois sopradores controlados morrer, nada detecta,
e o motor óptico cozinha em silêncio. Diagnóstico em
[`docs/research/34-escada-brilho-e-fanmonitor.md`](docs/research/34-escada-brilho-e-fanmonitor.md).
O aparelho tem **3 ventiladores**: os 2 sopradores DFH8030S (12 V, 0,45 A) que a política térmica
controla e 1 axial no exaustor do dissipador do LED, sem controle por software (OPT-S6,
[doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3).

## O que a correção comunitária faz

| Item | Configuração de fábrica | Após a correção |
|---|---|---|
| **2º sensor de temperatura** | mapeamento incorreto (`HW_VIRTUAL_CHANNEL=0` nos dois canais) → proteção térmica ineficaz | canal virtual `1` → mux comuta; proteção passa a enxergar o calor real |
| **Ventiladores** (os 2 sopradores controlados) | aceleram tarde, guiados pelo sensor inadequado | **100% desde o boot** |
| **Brilho** | curva de dimming atada ao sensor inadequado (`1000→750`) → imagem enfraquecia no uso | **100% abaixo de 66 °C**; escada de dimming ancorada no sensor **real**, caindo até 850 entre 66 °C e 70 °C e voltando sozinha na descida ([doc 34](docs/research/34-escada-brilho-e-fanmonitor.md)). Com a sala a 34 °C (2026-10-29) ela atuou no uso normal, brilho 944-974 ([doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §2) |
| **Desligamento de proteção** | limiar que quase nunca dispara na prática | **75 °C** (rede de segurança calibrada ao sensor real) |
| **Wi-Fi** | não reconecta após reiniciar | reconecta sozinho |
| **Log** | spam do serviço `xiriservice` ~1×/s | serviço desabilitado |

**Resultado medido** na saída de ar: **46,7 °C (fábrica) → 37,2 °C** (com a correção). A imagem também permanece mais estável em brilho.

A correção essencial é **mínima** (essencialmente um caractere no canal virtual do 2º termistor, mais curvas e limiares coerentes). Três arquivos em `/vendor`; não é necessário reflash de bootloader.

## MeowCast: o sistema que o kit deixa no projetor (2026-10)

**MeowCast** é o nome do conjunto que o kit de pendrive instala por cima do Android de fábrica: a correção
térmica, a cor do painel, uma suíte que confere a imagem sozinha, uma tela inicial nova, o tema Drácula em todo o
sistema e a marca MeowCast no boot. Não troca o firmware, não toca no bootloader e não apaga o `/data`: o
Android do fabricante continua lá, e o que o kit põe sai com um arquivo no pendrive (abaixo). Estado do
conjunto: [`docs/sprints/ESTADO-2026-10-31.md`](docs/sprints/ESTADO-2026-10-31.md).

| Parte | O que faz | Onde fica | Doc |
|---|---|---|---|
| Térmica | o 2º sensor lido, ventiladores a 100%, escada de brilho, Wi-Fi que reconecta, sem o spam do `xiriservice` | `/vendor/etc/ZYCustom.ini`, `build.prop`, `init.bigfish.rc` | [34](docs/research/34-escada-brilho-e-fanmonitor.md) |
| Cor | confere a escada de 16 cinzas pela câmera interna e troca VESA/JEIDA se ela sair fora de ordem | 1 byte da `panelparam`, com backup e journal | [41](docs/research/41-auto-pareamento-camera-e-kit-universal.md) |
| Suíte de verificação | cor, ângulo, foco e nitidez pela câmera, temperatura, teste da proteção térmica e um resumo em tela cheia; roda ao voltar da tomada, pelo pendrive e pelo ícone "Verificar projetor" | `/data/vendor/pfl7560-suite` e o serviço `/vendor/etc/init/pfl7560-suite.rc` | [44](docs/research/44-suite-de-boot.md) |
| Home MeowCast | tela inicial nova (entradas, atalhos, apps), com o botão **Luz** (o nível escolhido volta a cada boot) | `/vendor/app/PFL7560Home` e a prop `vendor.newlink.launcher.package` | [45](docs/research/45-home-pfl7560.md) |
| App Verificar | os ícones "Verificar projetor" e "Wi-Fi" e o descanso de tela MeowCast, que baixa a luz a 10% enquanto está na tela | `/vendor/app/PFL7560` | [44](docs/research/44-suite-de-boot.md) §7 e §14 |
| Tema Drácula | 20 sobreposições (só cor, forma, imagens e layouts só de cor) ligadas no boot; Office, iOSCast e Espelhamento desligados; gerenciador de arquivos direto na lista | `/vendor/overlay/PFL7560Tema*` | [48](docs/research/48-tema-no-sistema.md) |
| Marca | logo e animação de boot MeowCast | `/atv/bootvideo` (o de fábrica guardado na pasta da suíte) | [44](docs/research/44-suite-de-boot.md) §15 |

Fora do pendrive, pelo PC: `pfl7560-marca.sh` (a imagem do carregador, na partição `logo`, que depende dos 4
cantos de cada aparelho) e `pfl7560-vlc.sh` (VLC 3.7.1 como app do sistema).

**Instalar.** `./install.sh --pendrive <ponto de montagem>` (Windows: `install.bat`, opção 5) copia o kit e
confere o md5 de cada arquivo. Com o projetor **desligado**, plugue e ligue. A térmica e a cor valem na hora (a
térmica reinicia uma vez); a home, o tema, o ícone e o descanso valem a partir do **boot seguinte**. Passo a
passo no [`INSTALL.md`](INSTALL.md), método 1.

**Desfazer.** Um arquivo vazio `DESINSTALAR-SUITE.txt` na raiz do pendrive, e ligar com ele plugado: sai o
serviço, a pasta da suíte, a home como tela inicial, as sobreposições e a prop do gerenciador; os três apps do
fabricante voltam; o logo e a animação de fábrica são restaurados; o descanso volta ao do fabricante. A térmica
fica (desfaz pelo PC com `./pfl7560-fix.sh revert`, que precisa do backup de fábrica de um `apply` feito naquele
PC, ou regravando o firmware de fábrica), a cor fica no formato que o painel pede, e os dois apps
ficam instalados sem efeito (são apps do sistema; o `adb uninstall` não os tira). Resgate total: o firmware de
fábrica por power-hold ([guia 16](docs/guide/16-recuperacao-brick.md)), que apaga o `/data`.

**Provado no projetor do dono (V1.0.0.9, 2026-10-30 e 2026-10-31):** a suíte pelo boot, pelo ícone e pelo
pendrive; a marca de "ligado" que detecta a queda de energia, com um reset sem desligamento (`sysrq b`); o botão
Luz e o descanso a 10%; a home como tela inicial; as 20 sobreposições; a marca no boot. **PROVISÓRIO:** tirar da
tomada **com o projetor ligado** com o cabo de verdade; a varredura fina de foco com o foco ruim de propósito (a
unidade do `gfd`/`sfd` e os passos não foram vistos no aparelho); olhar com o controle o teclado na tela, o
pareamento do controle, o menu de imagem de uma entrada HDMI e a contagem de desligar; o modelo sem USB-C
(V1.0.0.1), só em simulação; a bancada completa do pendrive (etapa E4 do bloco 5) e a prova com um leigo. A build
`.bin` completa existe, mas **não foi gravada** (método 4).

## Impacto no consumidor

Em condições normais de uso, o defeito de configuração térmica favorece **superaquecimento da óptica** e degradação/substituição recorrente de polarizador e LCD (no equipamento de origem desta pesquisa: **duas trocas em 18 meses**).

Sob o **Código de Defesa do Consumidor** (Lei 8.078/1990):

- **Art. 18** — o fornecedor responde por **vícios de qualidade** que tornem o produto **impróprio ou inadequado ao consumo** a que se destina, ou lhe diminuam o valor.
- **Art. 25** — é vedada a exoneração contratual do fornecedor pela reparação dos danos causados por defeitos relativos a produtos (incluindo a cadeia de fornecimento, nos termos da lei).

Quando o vício decorre de **configuração sistemática de firmware** (e não de mau uso isolado), há base para discutir **inadequação ao uso ordinário** e, em escala, eventual **responsabilidade coletiva** / reclamações em massa. Este repositório não substitui assessoria jurídica; documenta fatos técnicos e medições para o consumidor, a assistência e a fabricante.

## Como aplicar (escolha **um**)

Passo a passo: **[`INSTALL.md`](INSTALL.md)** · dependências: [`requirements`](requirements) / [`REQUIREMENTS.md`](REQUIREMENTS.md).

### Preparar o PC (Linux / Windows / macOS)

```bash
# Linux ou macOS
./install.sh          # instala adb (+ nmap opcional) e verifica
./install.sh --check  # só verifica
```

```bat
REM Windows (cmd / duplo-clique)
install.bat
```

1. **Pendrive autorun (mais fácil, sem PC)**
   Copie o kit v2 **completo** (`newlink_update.sh`, `cor.sh`, `lvdsctl`, `nl_camcheck`, `ZYCustom.ini`, `LEIA-ME.txt`, `kit/*.png`, a suíte: `suite.sh`, `suite-boot.sh`, `suite-pedido.sh`, `pfl7560-suite.rc`, as telas dela: `nl_tela` e `fontes/*`, o app `pfl7560.apk`, a home `pfl7560-home.apk`, `overlay/*.apk` e `marca/*`) para a raiz de um pendrive FAT32 com `./install.sh --pendrive /caminho/do/pendrive` (Windows: `install.bat`, opção 5), que confere o md5 depois da cópia; plugue no projetor **desligado** e ligue. Aplica a térmica (só as seções térmicas do `.ini` do aparelho, nos dois modelos) e faz o teste de cor da escada de 16 cinzas, sozinho pela câmera interna ou, se ela não ajudar, pelo controle remoto. Depois roda a **suíte de verificação** (ângulo, foco, nitidez, temperatura, teste da proteção térmica e um resumo em tela cheia), instala o app dos ícones **Verificar projetor** e **Wi-Fi** e deixa um serviço de boot: dali em diante a suíte roda sozinha quando o projetor volta da tomada e a pedido pelo ícone (que só vale a partir do boot seguinte). Sem serial, sem arquivo para editar, idempotente; `DESINSTALAR-SUITE.txt` no pendrive desliga a suíte. Com `--com-firmware` o pendrive leva também o firmware de resgate (`tests/preparar-pendrive.sh` prepara um do zero). O mesmo pendrive instala o sistema MeowCast (seção acima). Em uso no projetor do dono desde 2026-10-31; o que falta provar está na seção MeowCast e em [`docs/research/44-suite-de-boot.md`](docs/research/44-suite-de-boot.md).

2. **Script no PC (adb por Wi-Fi)**
   ```bash
   PFL_IP=<ip-do-projetor> ./pfl7560-fix.sh status
   PFL_IP=<ip-do-projetor> ./pfl7560-fix.sh apply
   PFL_IP=<ip-do-projetor> ./pfl7560-fix.sh revert
   ```
   Linux: também `./pfl7560-menu.sh` / `PFL7560-Corrigir.desktop`.
   Windows: `install.bat` → opções 2–4.

3. **Manual (adb)** — [`docs/research/06-acesso-adb-e-comandos.md`](docs/research/06-acesso-adb-e-comandos.md).

### Verificar depois de aplicar

```bash
PFL_IP=<ip> ./pfl7560-saude.sh                # 12 checagens; exit 0 = tudo certo
PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade   # a PROVA FORTE: a protecao reage?
```

Confere os 3 arquivos (no `.ini` efetivo), o mux destravado, a escada de brilho, o formato de cor (o em uso tem de bater com o byte gravado) **e** se a proteção está
**enxergando neste boot** — a configuração pode estar perfeita e a proteção estar cega mesmo assim
(`LSADC Error`; um reboot restaura). Nessa forma não escreve nada e não toca o sensor. Menu: opção **5**.

**A prova forte é `--vivacidade`.** Ela injeta 71 °C por ~40 s (`vendor.zy.power.tm.temp`) e verifica se o
firmware **reage**: `Overheat Warning` no log e a escada de brilho descendo até 850 e voltando sozinha.
É o único teste **positivo** da proteção que existe — contar `LSADC Error` no logcat não serve como prova
de ausência (o erro só sai em 2 de cada 10 iterações e o buffer dura 60-150 s). Diferente das outras
checagens, este modo **não é read-only**: escreve a propriedade, mexe no brilho e grava log em
`evidencias/vivacidade/`. Mecanismo e aviso de segurança em
[`docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md`](docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md).

Para acompanhar durante o uso real (a escada só atua acima de 66 °C):
`PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh` — menu opção **6**. Ver o aviso sobre sondagem em
[`INSTALL.md`](INSTALL.md#acompanhar-durante-o-uso).

4. **Firmware `.bin` completo (experimental)** — um protótipo antigo **travava o boot** (metadados errados) e foi **apagado**. O builder atual (`artifacts/bin-build/`) já carimba mode/rótulo SELinux; existe uma build nova que passa offline, mas **ainda não bootou em hardware** — segue em quarentena. Use só os métodos 1–3. Caminho até um `.bin` que boota: [`docs/research/31-plano-mestre-bin-final.md`](docs/research/31-plano-mestre-bin-final.md). Recuperação: [`docs/guide/16-recuperacao-brick.md`](docs/guide/16-recuperacao-brick.md).

## Segurança e recuperação

- **Métodos 1 a 3 são reversíveis, não tocam no bootloader e o aparelho permanece recuperável.**
- Só editamos `/vendor` (sem dm-verity nesta build) — a correção **sobrevive** a reset de fábrica.
- Toda aplicação por script faz **backup do stock** antes; `revert` restaura.
- Recuperação máxima: firmware de fábrica (“Atualização local” ou power-hold + `usb_update.bin` de **fábrica**).
- Guia: [`docs/guide/12-seguranca-e-recuperacao.md`](docs/guide/12-seguranca-e-recuperacao.md).

### Por que o `.bin` experimental não funcionou (resumo)

O flash **completou** e a config térmica **foi aplicada** (fans e brilho no máximo mesmo com boot travado). O hang na logo do Android veio dos **metadados** dos 3 arquivos reescritos via `debugfs write`, não do conteúdo:

| Arquivo | Stock (fábrica) | `.bin` experimental |
|---|---|---|
| `ZYCustom.ini` | mode **0644** + `security.selinux=u:object_r:vendor_configs_file:s0` | mode **0664**, **sem** xattr |
| `build.prop` | mode **0600** + `vendor_file:s0` | mode **0664**, **sem** xattr |
| `init.bigfish.rc` | mode **0644** + `vendor_configs_file:s0` | mode **0664**, **sem** xattr |

Em especial, o **init do Android recusa parsear arquivos `.rc` group/world-writable** (`0664` tem bit de escrita para grupo). Isso é causa suficiente de boot preso na logo. Rótulos SELinux ausentes agravam o quadro (mesmo com SELinux permissivo nesta build, o modo do `.rc` já é crítico). Checksums do container estavam corretos. Aquele protótipo foi **removido** do repositório; o builder atual corrige metadados, mas **ainda exige teste em hardware**.

## Reparo relacionado: troca de painel LCD e correção de cor (VESA↔JEIDA)

Investigação separada, no mesmo aparelho: ao substituir o micro-painel LCD do motor óptico, a imagem
pode sair com **primárias certas e preto/cinzas tingidos** (a cor do tingimento muda com a imagem). É o
**formato LVDS** (VESA ou JEIDA) que o SoC emite não casar com o painel. Na 1ª troca (2026-07-10), o
`RX058B-0600` (peça vendida p/ Thundeal TD96) pediu **JEIDA**; na 2ª troca (2026-10-29), o painel
instalado é o `FPX-RX058B-4300-V0` `20241101 HT`, o mesmo modelo e data do painel de fábrica, e pediu
**VESA** (byte `0x5c` = 0,
[doc 40](docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1). Na 3ª troca (2026-10-30) o painel
pediu **JEIDA**, e o aparelho está hoje em JEIDA (byte `0x5c` = 1,
[doc 41](docs/research/41-auto-pareamento-camera-e-kit-universal.md) §8). **O formato não se
deduz do nome do painel:** descobre-se olhando um padrão de cinza (a escada de 16 cinzas,
[doc 41](docs/research/41-auto-pareamento-camera-e-kit-universal.md) §4).

Resolvido **por software, sem trocar hardware**: decompilando a `libhitvservice.so` do aparelho
(capstone), compilando um programa (`lvdsctl`, NDK) que chama `HiPanelCtrl::SetLvdsFormat` — que
grava **1 byte** (`0x5c`) no perfil de painel do `panelparam`. Persiste no boot nativamente. Diagnóstico
completo, tentativa-e-erro e comandos em
[`docs/research/28-troca-painel-rx058b-diagnostico-cor.md`](docs/research/28-troca-painel-rx058b-diagnostico-cor.md).

**Como aplicar** (só quem trocou o painel):
- **sem PC:** o kit de pendrive (método 1) projeta a escada de cinzas e a câmera interna confere; escada em ordem =
  nada a fazer, e a troca do formato tem backup e journal antes (sem câmera, só com duas teclas do controle);
- **com PC:** `PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard` (backup obrigatório antes de gravar, testa
  JEIDA e VESA na tela) ou `./pfl7560-menu.sh` → opção 4; no Windows, `install.bat` → opção 6.

Todo comando que grava na `panelparam` faz backup antes e aborta se o backup falhar. Guia leigo:
[`docs/guide/32-guia-troca-painel-lcd.md`](docs/guide/32-guia-troca-painel-lcd.md). **Regravar o firmware
de fábrica provavelmente devolve o byte `0x5c` ao de fábrica (VESA)**: a `panelparam` parece estar dentro
do `.bin` ([doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md) §5); depois de um reflash,
refaça o teste de cor.

## Estrutura do repositório

```
.
├── install.sh / install.bat        # setup do PC (Linux·macOS / Windows) e kit no pendrive (--pendrive [--com-firmware])
├── requirements · REQUIREMENTS.md
├── pfl7560-fix.sh                  # correção térmica (status/apply/revert) — sonda o sensor
├── pfl7560-saude.sh                # verifica se a correção está ativa (12 checagens, passivo)
│                                   #   --vivacidade = prova forte, e o ÚNICO modo não read-only
├── pfl7560-vigia-lsadc.sh          # acompanha a proteção durante o uso real (passivo)
├── pfl7560-monitor-props.sh        # curva térmica por props (passivo)
├── pfl7560-processos.sh            # CPU por processo com o projetor parado + props (só leitura, bloco 9C)
├── pfl7560-marca.sh                # marca MeowCast na partição `logo` do carregador (backup, dd, releitura; bloco 14)
├── pfl7560-vlc.sh                  # VLC 3.7.1 como app do sistema (sha256 e assinatura conferidos; bloco 14)
├── pfl7560-monitor-termico.sh      # curva térmica por hidebug (sonda — só pontual)
├── pfl7560-autocaptura.sh          # captura automática da curva em uso real (sonda — serviço DESABILITADO)
├── pfl7560-lcd-color.sh            # correção de cor pós-troca de painel (VESA/JEIDA)
├── pfl7560-menu.sh · pfl7560-evidencias.sh · PFL7560-Corrigir.desktop
├── INSTALL.md · LICENSE (GPLv3)
├── pendrive-autorun/               # método sem PC: kit + suíte + apps (pfl7560.apk, pfl7560-home.apk) + overlay/ + marca/
├── docs/
│   ├── dossie-teardown.html        # dossiê visual do teardown (fotos + achados)
│   ├── research/                   # teardown, causa-raiz, build, LCD, plano mestre (31),
│   │                               #   escada de brilho + FanMonitor (34), sessão de campo (35),
│   │                               #   mecanismo do LSADC (37 — o mais importante do projeto)
│   ├── guide/                      # replicação, segurança, brick, troca de painel (32),
│   │                               #   lista de compras do reparo óptico (36)
│   ├── disclosure/                 # relatório CSIRT + status
│   └── archive/                    # sprints e auditorias internas
├── artifacts/
│   ├── bin-build/                  # builder do .bin (com metadados/SELinux)
│   ├── lcd-color-fix/              # lvdsctl + padrões de teste de cor
│   ├── camcheck/ · tela/           # nl_camcheck (câmera) e nl_tela (telas da suíte), ARM
│   ├── app/                        # app "PFL7560" (Verificar projetor, Wi-Fi, descanso de tela): fonte, build.sh sem Gradle, chave
│   ├── home/                       # home MeowCast (com.pfl7560.home): fonte, build.sh, prévias
│   ├── overlay/                    # as 20 sobreposições do tema Drácula (RRO) e o conferir.py
│   ├── tema/                       # paleta, fundo e marca MeowCast (gerar-marca.py)
│   └── (ZYCustom stock/fix, históricos)
├── media/                          # fotos do teardown + evidências
├── tests/                          # make check (md5) · check-kit · check-bin · check-fix (simulação, sem aparelho)
│                                   #   preparar-pendrive.sh = formata e prepara um pendrive (só removível por USB)
├── firmware/                       # zip oficial (LFS) + .bin (fora do Git)
└── referencia/                     # manuais PDF (fora do Git)
```

## Aparelho-alvo

Intelbras **PFL7560** · SoC HiSilicon Hi3751V553 · Android 9 (HiDPT) · firmware **V1.0.0.9** (com USB-C) ou
**V1.0.0.1** (sem USB-C, "NOTYPEC", fabricado a partir de 25/08/2026; só simulação). O kit e o `pfl7560-fix.sh`
reconhecem os dois e recusam qualquer outro; o builder recusa `.ini` de modelo diferente do stock. **Não** grave o firmware de um modelo no outro
([doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md)).

## Licença

[GPLv3](LICENSE). Sem garantia. Marcas, firmware e manuais da Intelbras pertencem à Intelbras — usados aqui apenas para fins de reparo e interoperabilidade.
