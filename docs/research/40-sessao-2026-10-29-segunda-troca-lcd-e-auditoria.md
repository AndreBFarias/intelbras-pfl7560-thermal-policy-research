# 40 - Sessão 2026-10-29: 2ª troca de LCD (VESA), medição térmica e auditoria do repositório

Sessão com o aparelho **aberto**: 2ª troca do micro-painel LCD, pasta térmica nova entre o LED e o bloco
dos heat pipes, limpeza. Cobre a correção de cor, uma medição térmica com ambiente anotado e duas
auditorias somente leitura (código e docs) mais uma pesquisa de fichas técnicas.

**Convenção** (a mesma do [doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md)): `OBSERVADO` = visto
neste aparelho nesta sessão. `PROVADO` = verificado em fonte primária. `REFUTADO` = registro anterior
derrubado.

---

## 1. Cor: o painel novo é VESA (`OBSERVADO`)

- Flat lido com o aparelho aberto: **`FPX-RX058B-4300-V0`, `20241101 HT`**
  (`media/2026-10-29-flat-lcd-rx058b-4300.jpg`). Mesmo modelo e mesma data de fabricação do painel
  **original de fábrica** registrado no [doc 28](28-troca-painel-rx058b-diagnostico-cor.md). Por isso
  pede VESA, como o perfil 69 (`RX058B_4300_5010E`) sempre previu: o aparelho estava em JEIDA por causa
  do `-0600` da 1ª troca.
- Sintoma relatado: "verde virou azul, canais trocados". As barras puras mostraram **primárias certas**;
  o preto e os cinzas saíram tingidos, com cor que **mudava conforme a imagem** (verde num padrão,
  laranja noutro). Assinatura de formato LVDS invertido, não de troca de canal nem de bit preso.
- Mecanismo: o DCI levanta o preto alguns níveis, de forma diferente por canal. Com o formato errado,
  os 2 LSBs viram os 2 MSBs, e essa diferença de 1-2 níveis vira 64-128.
- `lvdsctl fmt 0` (VESA) corrigiu na hora. O byte `0x5c` do perfil 69 da `panelparam` foi lido como `0`
  logo depois: **a API grava na partição**, sem `dd`. Sobreviveu ao reboot (`lvds_fmt: vesa`).
- Backup de antes (ainda JEIDA): `private/panelparam-2026-10-29-antes-swap.img`, md5
  `4899eefc02a2505d4894d63f18525b33`.
- `PROVADO` (pesquisa): a única ficha pública de painel LTPS 1080p com o controlador SC5010 (Midas
  MDT0400GIHC-LVDS, farnell.com/datasheets/3984937.pdf) documenta **só VESA**. Coerente com o perfil
  `RX058B_4300_5010E` ser VESA de fábrica. Nenhuma variante RX058B tem formato documentado em público;
  o formato só se decide por teste de cinza.

## 2. Medição térmica (`OBSERVADO`, com ressalvas)

Artefato: `evidencias/2026-10-29/props-221947.tsv`. Branco `#FFFFFF`, brilho 1000, fans 1000/1000.

| | 2026-09-03 (doc 39 §4.1) | 2026-10-29 |
|---|---|---|
| Sala (informada) | 35,1 °C | 34 °C |
| `gtt1` em regime | 58,73 °C | 65,8 °C (pico 68,2) |
| Delta sobre a sala | 23,63 °C | 31,80 °C |
| `gtt0` (placa) | 28,2 °C | 31,9-33,7 °C |

- Delta **+8,17 °C** (em `LC_ALL=C`; o `awk` em pt_BR trunca e dá 7,45, ver §4 item 3).
- A escada de brilho atuou no uso normal: brilho oscilando 944-974 com o `gtt1` entre 65,8 e 68,2 °C.
- IR do dono: entrada embaixo 29 °C, saída esquerda 37 °C (igual ao histórico com fans a 100%), saída
  direita 63 °C (nunca medida antes).
- **Ressalvas:** só 6 amostras em regime; o resumo mistura dois boots (o aparelho foi religado às
  22:33); o `gtt0` lê **abaixo** da sala anotada nas duas sessões, o que põe a âncora de ambiente em
  dúvida. Pela placa como referência, a diferença cai para +1,6 °C (abaixo de um degrau do ADC).
- A base de 2026-09-03 pode ter tido ventilador externo (o dono não lembra).

## 3. Onde está o NTC do `gtt1` (OPT-S7)

> **ATUALIZAÇÃO (mesma sessão, aparelho aberto) — `OBSERVADO`, confiança ~85 %:** o dono seguiu o fio do
> conector `NTC GND` da placa principal (`media/2026-10-29-trajeto-fio-ntc-gnd.jpg`). São **dois fios
> pretos finos trançados** (formato de sensor de 2 fios) que descem pela lateral da placa de força do LED
> e terminam no parafuso do canto inferior, onde o **olhal de latão** fica preso no topo do **bloco
> dissipador do LED**. Leitura: **o `gtt1` mede o bloco do LED, não a óptica.** O que falta para 100 %:
> ver o olhal com os dois fios entrando nele (sem outro fio no mesmo parafuso). O olhal solto na base,
> com luva metálica, é outra peça (o do doc 27).
>
> Consequências: (1) a coluna `optica_C` e o nome "óptica" nos scripts e docs são rótulo errado; o
> valor é a temperatura do dissipador do LED. (2) Os +8 °C depois da pasta nova são compatíveis com a
> pasta **funcionando** (mais calor sai do LED para o bloco). (3) A temperatura do polarizador e do LCD
> **não é medida por nenhum sensor** do aparelho. (4) A placa de força do LED traz a marcação
> **`NeoPix 725 NPX725 CN LED`** com logotipo **PHILIPS**, código `ZC 2306`, e MOSFET de potência
> **`JMT K80N06A`** (`media/2026-10-29-placa-led-neopix-npx725.jpg`); pistas novas para a ficha do LED.
>
> **OPT-S6 FECHADO (`OBSERVADO`, dono):** são **3 ventiladores**, os 2 sopradores embaixo (os que a
> política térmica controla, `gfc` = 2) e 1 no exaustor do dissipador do LED (sem controle por software).
> Os três estão funcionando.

- `OBSERVADO`: em cima do bloco do LED há um **olhal de latão parafusado** (já aparece em
  `media/teardown-02-interior-forca-led.jpg`, de julho) e um **cabo cinza terminado num tubinho metálico**.
- O doc 27 classifica como aterramento EMI um **outro** olhal (o solto entre os sopradores). O argumento
  "terminal de anel não é sensor" não exclui NTC encapsulado em terminal de anel, que é formato comum.
- Hipótese "o `gtt1` mede o bloco do LED, não a óptica": ~60 %, nada medido a refuta. Se for isso, os
  +8 °C depois da pasta nova podem ser o bloco recebendo mais calor do LED (pasta funcionando).
- **Teste decisivo:** seguir o fio do conector `NTC GND` da placa principal (entre o 4 vias P1-P4 e os
  dois `Vfan GND`) até a ponta; ou contar fios no olhal (2 = NTC, 1 = terra); ou o teste do secador do
  doc 39 com o monitor rodando.

## 4. Achados das auditorias, por prioridade

Detalhes de cada item (arquivo:linha) nos relatórios dos auditores desta sessão; resumo aqui.

**Bloco A - risco de estragar o aparelho ou a cor**
1. `pendrive-autorun/newlink_update.sh:93-113,274-305`: FIX 4 só vai de VESA para JEIDA, travado pelo
   serial do aparelho, não pelo painel. Desfaria a correção de hoje. (O dono não tem mais o pendrive.)
2. `pfl7560-lcd-color.sh:96-99`, `pfl7560-menu.sh:53-54`, `install.bat:~288-296`: gravam na
   `panelparam` sem backup (só o wizard faz). Um `swap`/`bit` errado persiste e volta preto no boot.
3. Docs que mandam esperar `jeida`: `39:664`, `38:204,320-321`, `guide/36:112-113`, `31:98`,
   `guide/32:15-17,70,81`, `33:16-21`, `INSTALL.md:168-173`, `artifacts/lcd-color-fix/README.md:7-8`.
4. `pfl7560-saude.sh:130-140` e `install.bat:108`: só aceitam JEIDA como certo.

**Bloco B - medições erradas**
1. Locale: `monitor-props`, `evidencias` (o CSV desloca colunas), `teste-brilho` e `vigia-lsadc`
   (veredito do LSADC muda em pt_BR). Correção: `export LC_ALL=C` em cada script.
2. `pfl7560-monitor-props.sh:127`: `boot_id` lido uma vez; o resumo mistura boots.
3. `pfl7560-monitor-props.sh:133-136`: laço de reconexão sem limite de falhas.
4. Root suposto sem conferir: `fix.sh:64-67`, `evidencias.sh:99-102`, `monitor-termico.sh`.
5. `saude.sh:89,173-174`: lê o `.ini` do `/vendor`, não o efetivo de `/atv/ini/ZYCustom_<id>.ini`.

**Bloco C - docs desatualizados ou contraditórios**
1. `docs/research/28` §12.1 ("prova de que NÃO é VESA/JEIDA") sem marca de refutada; `28:147+` ("só o
   bit 4") contradiz a tabela do kernel (VESA/JEIDA desloca 2 bits em todos os canais).
2. `README.md:26-32`: descreve o FanMonitor como bug de config; o FAN-S1 (doc 34) diz inarmável.
3. `39:291-292`, `34:98`: "vive em 61-63 °C, a escada não atua" ficou desatualizado.
4. Ventiladores: resíduos de "2 fans DFH8025S axiais" em `27:12,45-47,74`, `38:39`,
   `disclosure/roteiro-evidencias.md:65`. `PROVADO` pela etiqueta: DFH8030S, 12 V, 0,45 A, centrífugo.
   A fonte Amazon do doc 07 é de outro fabricante (Skywalking 8025S).
5. Status divergentes: OPT-S3/S4, BIN-S3b, LCD-S1/S2, OPT-S13 entre docs 29, 31, 38, 39 e archive/18.

**Bloco D - menores**: IP com porta aceito por uns scripts e não por outros; Ctrl-C que não interrompe
`saude --vivacidade` e `teste-brilho`; `term_ok` do pendrive aceita `.ini` antigo; serial casado por
substring; `lvdsctl.c` sempre sai 0; `build_fix_bin.py` ignora código do `e2fsck`.

## 5. Pesquisa de fichas técnicas (resumo)

- Sem ficha pública de: RX058B (qualquer variante), PJ058S1, DFH8030S/DFH8025S, placa NL-5H039-LED,
  NTC ZL103SAF. As lacunas viram leitura de etiqueta na próxima abertura.
- `PROVADO`: SC5010 = controlador de vidro LTPS, VESA (Midas); Semtech SC5010 é homônimo (backlight).
- `PROVADO`: tabelas VESA/JEIDA do kernel Linux (`display/panel/lvds.yaml`) e da TI (SNLA014).
- `PROVADO`: polarizador wire-grid inorgânico (Moxtek ProFlux) aguenta 200-250 °C; filme iodo ~80 °C.
- `INFERIDO`: patentes de projetor LCD põem o termistor ora junto do painel, ora junto da lâmpada/LED.
  Nenhuma fonte pública diz onde a Newlink o põe.

## 6. Próximo passo

1. Fechar OPT-S7 com o aparelho aberto (teste do §3).
2. Decidir com o dono quais blocos do §4 entram no próximo bloco de correções.
