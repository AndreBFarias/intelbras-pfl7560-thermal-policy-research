# intelbras-pfl7560-thermal-policy-research

Pesquisa independente de **engenharia reversa e reparabilidade** sobre um **defeito de configuração de fábrica** no projetor **Intelbras PFL7560** (firmware V1.0.0.9) que torna a proteção térmica ineficaz e contribui para **falha prematura** da óptica (polarizador/LCD).

> **Aviso.** Projeto **sem vínculo com a Intelbras**. Os métodos 1–3 editam apenas a partição `/vendor`, por sua conta e risco. **São reversíveis, não tocam no bootloader e o aparelho permanece recuperável.** O firmware `.bin` completo experimental está em **quarentena** (não use).

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

A política térmica do aparelho é um arquivo de texto (`/vendor/etc/ZYCustom.ini`). Os dois termistores foram mapeados no **mesmo canal virtual** do multiplexador (`HW_VIRTUAL_CHANNEL=0`), de modo que o segundo sensor — o que enxerga o calor real da óptica — **nunca é lido**. O sistema opera como se estivesse frio; a refrigeração e o desligamento de proteção não acompanham a temperatura real.

Detalhes técnicos: [`docs/research/08-por-que-fica-cego.md`](docs/research/08-por-que-fica-cego.md).

**Segundo defeito de configuração, da mesma natureza (2026-07-29):** o firmware também traz uma proteção
por **ventilador travado** (desliga o aparelho se um soprador para). Ela só roda se `MONITOR_MODE = 1`, e o
`ZYCustom.ini` de fábrica **não tem a seção `[FanMonitor]`** — o valor fica em zero e a proteção **nunca
executa**. Ou seja: se um dos dois sopradores morrer, nada detecta, e a óptica cozinha em silêncio.
Diagnóstico e plano de calibração em
[`docs/research/34-escada-brilho-e-fanmonitor.md`](docs/research/34-escada-brilho-e-fanmonitor.md).

## O que a correção comunitária faz

| Item | Configuração de fábrica | Após a correção |
|---|---|---|
| **2º sensor de temperatura** | mapeamento incorreto (`HW_VIRTUAL_CHANNEL=0` nos dois canais) → proteção térmica ineficaz | canal virtual `1` → mux comuta; proteção passa a enxergar o calor real |
| **Ventiladores** | aceleram tarde, guiados pelo sensor inadequado | **100% desde o boot** |
| **Brilho** | curva de dimming atada ao sensor inadequado (`1000→750`) → imagem enfraquecia no uso | **100% no uso normal**; escada de dimming ancorada no sensor **real**, caindo até 850 entre 66 °C e 70 °C e voltando sozinha na descida ([doc 34](docs/research/34-escada-brilho-e-fanmonitor.md)) |
| **Desligamento de proteção** | limiar que quase nunca dispara na prática | **75 °C** (rede de segurança calibrada ao sensor real) |
| **Wi-Fi** | não reconecta após reiniciar | reconecta sozinho |
| **Log** | spam do serviço `xiriservice` ~1×/s | serviço desabilitado |

**Resultado medido** na saída de ar: **46,7 °C (fábrica) → 37,2 °C** (com a correção). A imagem também permanece mais estável em brilho.

A correção essencial é **mínima** (essencialmente um caractere no canal virtual do 2º termistor, mais curvas e limiares coerentes). Três arquivos em `/vendor`; não é necessário reflash de bootloader.

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
   Copie o kit v2 **completo** (`newlink_update.sh`, `cor.sh`, `lvdsctl`, `ZYCustom.ini`, `LEIA-ME.txt` e `kit/*.png`) para a raiz de um pendrive FAT32 com `./install.sh --pendrive /caminho/do/pendrive` (Windows: `install.bat`, opção 5), que confere o md5 depois da cópia; plugue no projetor **desligado** e ligue. Idempotente.

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

Confere os 3 arquivos, o mux destravado, a escada de brilho, a correção de cor **e** se a proteção está
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

Investigação separada, no mesmo aparelho: ao substituir o micro-painel LCD do motor óptico por uma
variante de sufixo diferente (`RX058B-4300` de fábrica → `RX058B-0600`, peça vendida p/ Thundeal TD96),
a imagem sai com **cores erradas nos meios-tons** — os painéis usam **mapeamento LVDS diferente** (o
`-0600` espera **JEIDA**; o firmware emitia **VESA**).

Resolvido **100% por software, sem trocar hardware**: decompilando a `libhitvservice.so` do aparelho
(capstone), compilando um programa (`lvdsctl`, NDK) que chama `HiPanelCtrl::SetLvdsFormat(JEIDA)` — que
grava **1 byte** (`0x5c`) no perfil de painel do `panelparam`. Persiste no boot nativamente. Diagnóstico
completo, tentativa-e-erro e comandos em
[`docs/research/28-troca-painel-rx058b-diagnostico-cor.md`](docs/research/28-troca-painel-rx058b-diagnostico-cor.md).

**Como aplicar** (só quem trocou o painel): `PFL_IP=<ip> ./pfl7560-lcd-color.sh wizard` (faz backup do
painel e testa VESA/JEIDA na tela) ou `./pfl7560-menu.sh` → opção 4; no Windows, `install.bat` → opção 6.
**Não** aplique num aparelho com o painel de fábrica.

## Estrutura do repositório

```
.
├── install.sh / install.bat        # setup do PC (Linux·macOS / Windows)
├── requirements · REQUIREMENTS.md
├── pfl7560-fix.sh                  # correção térmica (status/apply/revert) — sonda o sensor
├── pfl7560-saude.sh                # verifica se a correção está ativa (12 checagens, passivo)
│                                   #   --vivacidade = prova forte, e o ÚNICO modo não read-only
├── pfl7560-vigia-lsadc.sh          # acompanha a proteção durante o uso real (passivo)
├── pfl7560-monitor-props.sh        # curva térmica por props (passivo)
├── pfl7560-monitor-termico.sh      # curva térmica por hidebug (sonda — só pontual)
├── pfl7560-autocaptura.sh          # captura automática da curva em uso real (sonda — serviço DESABILITADO)
├── pfl7560-lcd-color.sh            # correção de cor pós-troca de painel (VESA/JEIDA)
├── pfl7560-menu.sh · pfl7560-evidencias.sh · PFL7560-Corrigir.desktop
├── INSTALL.md · LICENSE (GPLv3)
├── pendrive-autorun/               # método sem PC
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
│   └── (ZYCustom stock/fix, históricos)
├── media/                          # fotos do teardown + evidências
├── tests/                          # make check (integridade md5)
├── firmware/                       # zip oficial (LFS) + .bin (fora do Git)
└── referencia/                     # manuais PDF (fora do Git)
```

## Aparelho-alvo

Intelbras **PFL7560** · SoC HiSilicon Hi3751V553 · Android 9 (HiDPT) · firmware **V1.0.0.9**. Outras versões podem diferir — confira antes.

## Licença

[GPLv3](LICENSE). Sem garantia. Marcas, firmware e manuais da Intelbras pertencem à Intelbras — usados aqui apenas para fins de reparo e interoperabilidade.
