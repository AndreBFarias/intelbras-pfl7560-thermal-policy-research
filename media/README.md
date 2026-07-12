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
| `teardown-05-blowers-dfh8025s.jpg` | REVISAR | Desfocar/recortar o topo: possível **reflexo de pessoa** no painel escuro ao fundo + bancada com objetos. |
| `placa-header-gnd-ntc.jpg` | REVISAR | Desfocar o **data-matrix (código 2D)** do módulo Wi-Fi/BT (canto sup. direito) — pode codificar MAC/serial. |
| `mapa-placa-original-topo.jpg` | REVISAR | Desfocar a **etiqueta da placa** (anotação 19): data-matrix + código alfanumérico (possível serial da placa). |
| `mapa-placa-original-visao-geral.jpg` | REVISAR | Recortar a borda inferior (perna nua) + desfocar o pequeno data-matrix da etiqueta da placa. |

**Pendente de captura (checklist acima):** `polarizador-danificado.jpg`, `termometro-saida-*.jpg`,
`hidebug-gtt-*.png`, `tela-antes-depois.jpg` ainda não existem em `media/`. Quando forem adicionados, os
prints `hidebug-gtt-*.png` precisam de nova auditoria por causa de **SSID/IP/hostname** na janela do PC.

Antes de commitar qualquer foto nova: abra a imagem e confira se não aparece rede Wi-Fi, MAC, serial,
código 2D/barras, rosto ou ambiente doméstico identificável.
