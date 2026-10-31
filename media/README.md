# Mídia (evidências visuais)

Coloque aqui fotos **sem dados pessoais** (sem rosto, sem SSID/IP na tela, sem nota fiscal legível se não quiser).

## Checklist sugerido para o relatório CSIRT / README

| Arquivo sugerido | Conteúdo |
|---|---|
| `polarizador-danificado.jpg` | Polarizador/LCD com manchas de superaquecimento (peça trocada) |
| `termometro-saida-stock.jpg` | Termômetro IR na saída de ar (cenário stock, se ainda tiver registro) |
| `termometro-saida-fix.jpg` | Mesma medição com a correção aplicada (~37 °C) |
| `hidebug-gtt-antes.png` | Leitura `gtt 0`/`gtt 1` iguais (~26 °C) no stock — recorte SSID/IP |
| `hidebug-gtt-depois.png` | `gtt 0` ~26 °C e `gtt 1` ~55–61 °C com o mux destravado |
| `tela-antes-depois.jpg` | Brilho da imagem (stock escurecendo vs fix em 100%) |

## Guias ilustrados de manutenção — 2026-10-29

Fotos do aparelho aberto com anotações, feitas com IA para o dono durante a troca de pasta térmica e do
LCD. **São guias de bancada, não evidência:** os rótulos não foram conferidos peça a peça. Duas imagens
existem em duas versões (`-a`/`-b`) que discordam num rótulo; as duas ficam até a peça ser verificada.

| Arquivo | Conteúdo | Ressalva |
|---|---|---|
| `guia-placa-forca-led-nl5h039.jpg` | Placa de força do LED `NL-5H039-LED`: conectores, bobina, shunts `R120`, local do dissipador 30x40 opcional | Etiqueta com QR/data-matrix da placa visível |
| `guia-vista-de-cima-pasta-a.jpg` | Vista de cima: o que leva pasta e o que não leva | Diz "processador sob a chapinha preta"; bate com o [doc 27](../docs/research/27-teardown-cabo-gnd-ntc.md) |
| `guia-vista-de-cima-pasta-b.jpg` | Mesma vista | Diz "processador sem dissipador"; diverge do doc 27 |
| `guia-lateral-pasta-led-a.jpg` | Lateral: pasta entre o LED e o bloco dos heat pipes, passo a passo | Rotula a peça no topo do bloco como "fio com terminal parafusado". **Incompleto:** o terminal é o NTC do `gtt1` (OPT-S7) |
| `guia-lateral-pasta-led-b.jpg` | Mesma lateral | Rotula a mesma peça como "sensor de temperatura (NTC)". **Confirmado em 2026-10-29** (OPT-S7 fechado, [doc 40](../docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3): é o NTC do `gtt1`, encapsulado no olhal. O olhal que o doc 27 trata como aterramento EMI é outro, o solto entre os sopradores |
| `guia-motor-optico-angulo.jpg` | Motor óptico em ângulo: funil, LCD, bloco do LED, ventoinha | — |
| `guia-ordem-pecas-opticas.jpg` | Ordem e posição de Fresnel, polarizadores, LCD e espelho; 3 testes rápidos | Diz que "o firmware já está em JEIDA". Vale para o painel em uso na foto; o formato muda a cada troca ([doc 33](../docs/research/33-matriz-paineis.md)) |

Auditoria de privacidade: **REVISAR** antes de publicar. Há QR/data-matrix de placas, mãos e fundo
doméstico (tecido, piso).

## Evidências de bancada — 2026-10-29

Fotos do dono com o aparelho aberto, usadas no [doc 40](../docs/research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md).

| Arquivo | Conteúdo | Privacidade |
|---|---|---|
| `2026-10-29-trajeto-fio-ntc-gnd.jpg` | Trajeto do fio do conector `NTC GND` até o olhal no bloco do LED (marcado em verde) | REVISAR: mão |
| `2026-10-29-flat-lcd-rx058b-4300.jpg` | Flat do LCD instalado: `FPX-RX058B-4300-V0`, `20241101 HT` | REVISAR: mão |
| `2026-10-29-olhal-ntc-no-bloco-do-led.webp` | Olhal do NTC no topo do bloco do LED: 2 fios e resina no tubo | REVISAR: mão |
| `2026-10-29-placa-led-neopix-npx725.jpg` | Placa de força do LED, marcação `NeoPix 725 NPX725 CN LED` | REVISAR: mão, etiqueta da placa principal ao fundo |

## Já no repositório — teardown 2026-07

Fotos da sessão de abertura do aparelho. Usadas no dossiê [`docs/dossie-teardown.html`](../docs/dossie-teardown.html) e em [`docs/research/27-teardown-cabo-gnd-ntc.md`](../docs/research/27-teardown-cabo-gnd-ntc.md).

## Auditoria de privacidade pré-publicação (sprint REPO-S2)

Revisão visual das 8 fotos: **2 publicáveis como estão, 6 exigem redação/crop antes de tornar o repo
público, nenhuma precisa ser expurgada por completo.** Guarde as cópias **não** redigidas (com serial)
fora do Git, só para o destino jurídico/CDC.

| Arquivo | Veredito | Ação antes de publicar |
|---|---|---|
| `teardown-01-base-cabo-solto.jpg` | **REVISAR (crítico)** | Redigir a etiqueta inferior: **número de série + código de barras** totalmente legíveis (identificador único do aparelho). Homologação ANATEL/CNPJ podem ficar. |
| `teardown-02-interior-forca-led.jpg` | REVISAR | Recortar/desfocar o terço direito: perna nua + mão + relógio de uma pessoa (a área técnica está nos círculos verdes à esquerda). |
| `teardown-03-olhal-solto-blowers.jpg` | **PUBLICÁVEL** | Só uma mão e componentes; sem serial/rosto/tela. |
| `teardown-04-blower-removido.jpg` | **PUBLICÁVEL** | Só mão + etiqueta do ventilador (dado de componente). |
| `teardown-05-sopradores-dfh8030s.jpg` | REVISAR | Desfocar/recortar o topo: possível **reflexo de pessoa** no painel escuro ao fundo + bancada com objetos. |
| `placa-header-gnd-ntc.jpg` | REVISAR | Desfocar o **data-matrix (código 2D)** do módulo Wi-Fi/BT (canto sup. direito) — pode codificar MAC/serial. |
| `mapa-placa-original-topo.jpg` | REVISAR | Desfocar a **etiqueta da placa** (anotação 19): data-matrix + código alfanumérico (possível serial da placa). |
| `mapa-placa-original-visao-geral.jpg` | REVISAR | Recortar a borda inferior (perna nua) + desfocar o pequeno data-matrix da etiqueta da placa. |

**Pendente de captura (checklist acima):** `polarizador-danificado.jpg`, `termometro-saida-*.jpg`,
`hidebug-gtt-*.png`, `tela-antes-depois.jpg` ainda não existem em `media/`. Quando forem adicionados, os
prints `hidebug-gtt-*.png` precisam de nova auditoria por causa de **SSID/IP/hostname** na janela do PC.

Antes de commitar qualquer foto nova: abra a imagem e confira se não aparece rede Wi-Fi, MAC, serial,
código 2D/barras, rosto ou ambiente doméstico identificável.
