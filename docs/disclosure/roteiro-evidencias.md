# Roteiro de evidências — PFL7560 (registro bruto)

Guia de captura para o dossiê de prova do defeito de política térmica. **Registro bruto**:
lista de tomadas etiquetadas e sincronizadas com o `pfl7560-evidencias.sh` — sem narração
roteirizada. Grave tudo cru e bem nomeado; a edição/narração fica para depois.

**Destinos** (a mesma captura serve a vários): **CSIRT** (relatório técnico) ·
**GitHub** (repositório público) · **Jurídico** (prova sob o CDC, arts. 18/25) · **Vídeo** (divulgação).

**Princípio de ouro:** *duas câmeras para o mesmo fenômeno* — o **sensor interno**
(`hidebug gtt`, sai do script) e o **termômetro IR** (sua mão). Elas se confirmam e blindam a prova.

---

## 0. Antes de começar

- **Equipamento:** termômetro IR · celular (foto + vídeo) · PC com o script · tripé (se tiver).
- **Ambiente:** luz **difusa** (janela/luminária, **sem flash**) · fundo neutro (pano branco ou preto) para as peças.
- **Carga térmica padrão:** uma **tela 100% branca** projetada (pior caso, reproduzível). Abra uma
  imagem branca em tela cheia na fonte de vídeo do projetor.
- **Higiene (crítico):** o script já **redige** IP/MAC/SSID dos logs. Mas as **fotos são sua
  responsabilidade** — nunca deixe no quadro: número de série/etiqueta do aparelho, telas de
  configuração de rede (SSID), rosto, documentos. Confira cada foto antes de commitar.

### Convenção de nomes (use exatamente estes)

| Arquivo | Conteúdo | Destinos |
|---|---|---|
| `polarizador-danificado.jpg` | Óptica velha com a queima térmica nítida | CSIRT · Jurídico · Vídeo |
| `termometro-saida-stock.jpg` | Termômetro IR na saída de ar — **antes** (~46 °C) | CSIRT · GitHub · Jurídico |
| `termometro-saida-fix.jpg` | Termômetro IR na saída de ar — **depois** (~37 °C) | CSIRT · GitHub · Jurídico |
| `hidebug-gtt-antes.png` | Print: os 2 NTC **iguais** (~26 °C) — o bug | CSIRT · GitHub |
| `hidebug-gtt-depois.png` | Print: NTC1 ~61 °C **divergindo** — a cura | CSIRT · GitHub |
| `tela-antes-depois.jpg` | Montagem: projeção escurecida (stock) × estável (fix) | GitHub · Vídeo |
| `teardown-*.jpg` | Fotos internas (ver Fase 2) | CSIRT · GitHub |
| `optica-velha-*.jpg` / `.mp4` | A peça removida (ver Fase 1) | Jurídico · Vídeo |

---

## Fase 1 — Óptica velha — URGENTE (antes de remover)

> A peça sai hoje. É **agora ou nunca** — é a evidência que liga a causa-raiz de firmware ao **dano físico real**.

| Take | Arquivo | Enquadramento / cuidado |
|---|---|---|
| Peça montada, in situ | `optica-velha-insitu.jpg` | Mostra **onde** fica antes de tirar. |
| Frontal isolada | `optica-velha-frontal.jpg` | Fundo neutro, luz difusa, sem flash. |
| **Contra-luz** | `optica-velha-contraluz.jpg` | Peça **entre você e a luz** — revela a mancha de queima do polarizador. **A foto mais forte.** |
| Macro do ponto queimado | `optica-velha-macro.jpg` | Aproximação do dano; foco no defeito. |
| Escala | `optica-velha-escala.jpg` | Peça + moeda/régua ao lado (anexo de laudo). |
| Velha vs nova | `optica-velha-vs-nova.jpg` | Lado a lado, se a peça nova estiver à mão. O contraste vende sozinho. |
| Vídeo | `video-optica-velha.mp4` | 10-20 s girando a peça **na contra-luz**. |

Escolha a melhor como `polarizador-danificado.jpg` para `media/`. **Guarde a peça velha** (prova física CDC).

---

## Fase 2 — Teardown (gabinete aberto)

> **Desligue da tomada** antes de abrir. Cuidado com ESD. Não capture número de série no quadro.

| Take | Arquivo | O que precisa aparecer |
|---|---|---|
| Visão geral | `teardown-visao-geral.jpg` | Interior montado, orientação. |
| Sopradores | `teardown-blowers.jpg` | Os **2 blowers DFH8025S** (a refrigeração que fica lenta no stock). |
| Dissipador/óptica | `teardown-dissipador.jpg` | Caminho do ar até a óptica. |
| **Termistores + mux** | `teardown-termistores-mux.jpg` | Região dos **2 NTC ZL103SAF** e do **mux BL1551B** — o coração do bug. Se conseguir identificar, é a foto técnica de ouro. |
| Placa/SoC | `teardown-placa.jpg` | Placa principal (SoC HiSilicon Hi3751V553). |

---

## Fase 3 — ANTES (stock / defeito)

**Comandos (nesta ordem):**
```bash
./pfl7560-evidencias.sh set-thermal stock   # reintroduz o defeito; espera o reboot
# -> ponha a TELA BRANCA 100% no projetor
./pfl7560-evidencias.sh snapshot antes       # captura pontual dos sensores
./pfl7560-evidencias.sh soak antes 10        # 10 min de curva; no fim, pede o termometro
```

| Take | Arquivo | Quando / como |
|---|---|---|
| Print dos sensores | `hidebug-gtt-antes.png` | Durante `snapshot antes`: **print da janela do PC** mostrando `NTC0 ≈ NTC1 ≈ 26 °C` (o `.txt` fica salvo como dado cru). |
| Termômetro na saída | `termometro-saida-stock.jpg` | No fim do `soak antes`, quando o script pedir a leitura: fotografe o **IR na saída de ar** (~46 °C) e digite o valor. |
| Vídeo da tela escurecendo | `video-tela-escurece-antes.mp4` | Time-lapse/tripé da **projeção enfraquecendo** ao longo dos 10 min (o dimming espúrio do stock). |
| Foto da projeção | `foto-tela-antes.jpg` | A projeção no pico do soak (para o comparativo). |

---

## Fase 4 — DEPOIS (corrigido)

**Comandos:**
```bash
./pfl7560-evidencias.sh set-thermal fix      # volta ao corrigido; espera o reboot
# -> TELA BRANCA 100% de novo
./pfl7560-evidencias.sh snapshot depois
./pfl7560-evidencias.sh soak depois 10
```

| Take | Arquivo | Quando / como |
|---|---|---|
| Print dos sensores | `hidebug-gtt-depois.png` | Durante `snapshot depois`: `NTC1 ~61 °C` **divergindo** de NTC0 — a prova de que o 2º sensor acordou. |
| Termômetro na saída | `termometro-saida-fix.jpg` | No fim do `soak depois`: IR na saída (~37 °C). |
| Vídeo da tela estável | `video-tela-estavel-depois.mp4` | A projeção **clara e estável** pelos 10 min (sem o dimming). |
| Foto da projeção | `foto-tela-depois.jpg` | Mesmo enquadramento da `foto-tela-antes.jpg`. |

---

## Fase 5 — Comparativos + relatório

```bash
./pfl7560-evidencias.sh report   # gera evidencias/<data>/relatorio-antes-depois.md (higienizado)
```

- **`tela-antes-depois.jpg`** — monte lado a lado `foto-tela-antes.jpg` vs `foto-tela-depois.jpg`
  (mesmo enquadramento, mesma câmera). É a imagem que o público entende num relance.
- Confira o `relatorio-antes-depois.md`: a tabela deve mostrar NTC1 e a saída de ar caindo do stock para o fix.

---

## Sincronia rápida (take vs comando)

| Comando do script | Fotos/vídeos que acompanham |
|---|---|
| `set-thermal stock` | — (só troca de estado) |
| `snapshot antes` | `hidebug-gtt-antes.png` |
| `soak antes 10` | `termometro-saida-stock.jpg` · `video-tela-escurece-antes.mp4` · `foto-tela-antes.jpg` |
| `set-thermal fix` | — |
| `snapshot depois` | `hidebug-gtt-depois.png` |
| `soak depois 10` | `termometro-saida-fix.jpg` · `video-tela-estavel-depois.mp4` · `foto-tela-depois.jpg` |
| `report` | `tela-antes-depois.jpg` (montagem) |

---

## Checklist de higienização (antes de commitar em `media/`)

1. `report` rodou — logs redigidos (IP/MAC/SSID viram `<...-REDIGIDO>`).
2. Revisar **cada foto/vídeo**: sem número de série, SSID, tela de rede, rosto, documento.
3. Renomear conforme a **convenção de nomes** acima.
4. Copiar **só os arquivos higienizados** para `media/` (os dados crus ficam em `evidencias/`, fora do Git).
5. Conferir que `evidencias/` está no `.gitignore`.

---

## Mapa: o que `media/` pede vs o que este roteiro entrega

| `media/README.md` pede | Entregue por |
|---|---|
| `polarizador-danificado.jpg` | Fase 1 (contra-luz/macro) |
| `termometro-saida-stock.jpg` | Fase 3 (`soak antes`) |
| `termometro-saida-fix.jpg` | Fase 4 (`soak depois`) |
| `hidebug-gtt-antes.png` | Fase 3 (`snapshot antes`) |
| `hidebug-gtt-depois.png` | Fase 4 (`snapshot depois`) |
| `tela-antes-depois.jpg` | Fase 5 (montagem) |
