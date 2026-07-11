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

## Já no repositório — teardown 2026-07

Fotos da sessão de abertura do aparelho. Usadas no dossiê [`docs/dossie-teardown.html`](../docs/dossie-teardown.html) e em [`docs/research/27-teardown-cabo-gnd-ntc.md`](../docs/research/27-teardown-cabo-gnd-ntc.md).

| Arquivo | Conteúdo |
|---|---|
| `teardown-01-base-cabo-solto.jpg` | Base do projetor; cabo solto visível pela grade. **Contém o número de série — borre se for publicar.** |
| `teardown-02-interior-forca-led.jpg` | Interior: dissipador do LED, chicote de força, terminais |
| `teardown-03-olhal-solto-blowers.jpg` | O olhal (ring-lug) solto entre os 2 sopradores |
| `teardown-04-blower-removido.jpg` | Um soprador DFH8025S removido (etiqueta legível) |
| `teardown-05-blowers-dfh8025s.jpg` | Os 2 sopradores DFH8025S montados |
| `placa-header-gnd-ntc.jpg` | Placa: header `GND/NTC` com o conector plugado |
| `mapa-placa-original-topo.jpg` | Mapa antigo da placa (topo) — com o SoC no chip errado |
| `mapa-placa-original-visao-geral.jpg` | Mapa antigo da placa (visão geral) |

Antes de commitar: abra a imagem e confira se não aparece rede Wi-Fi, MAC, serial ou ambiente doméstico identificável.
