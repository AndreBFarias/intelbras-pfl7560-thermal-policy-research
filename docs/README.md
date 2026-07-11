# Documentação técnica — PFL7560 thermal policy research

Índice da pesquisa e dos guias. Para **aplicar a correção**, comece pelo [`../INSTALL.md`](../INSTALL.md) e pelo [`../README.md`](../README.md) na raiz.

## Guias (uso prático)

| Doc | Conteúdo |
|---|---|
| [`guide/10-guia-replicacao.md`](guide/10-guia-replicacao.md) | Replicar a correção em outro PFL7560 |
| [`guide/12-seguranca-e-recuperacao.md`](guide/12-seguranca-e-recuperacao.md) | Backups, revert, cenários de pânico |
| [`guide/16-recuperacao-brick.md`](guide/16-recuperacao-brick.md) | Power-hold + `usb_update.bin` de fábrica |

## Divulgação responsável

| Doc | Conteúdo |
|---|---|
| [`disclosure/relatorio-csirt.md`](disclosure/relatorio-csirt.md) | Relatório ≤3 páginas para CSIRT / suporte |
| [`disclosure/STATUS.md`](disclosure/STATUS.md) | Data de envio, protocolo, follow-up |

## Pesquisa (ordem de leitura)

| Doc | Conteúdo |
|---|---|
| [`research/01-teardown-tecnico.md`](research/01-teardown-tecnico.md) | SoC, partições, como o firmware foi aberto |
| [`research/02-sistema-termico-atual.md`](research/02-sistema-termico-atual.md) | Valores térmicos de fábrica |
| [`research/03-causa-raiz-e-limites.md`](research/03-causa-raiz-e-limites.md) | Por que a óptica queima; teto do software |
| [`research/04-plano-de-build-e-riscos.md`](research/04-plano-de-build-e-riscos.md) | Caminhos de deploy e riscos |
| [`research/05-ZYCustom.ini-proposto.md`](research/05-ZYCustom.ini-proposto.md) | Rascunho histórico de parâmetros |
| [`research/06-acesso-adb-e-comandos.md`](research/06-acesso-adb-e-comandos.md) | Cookbook adb / hidebug |
| [`research/07-hardware-upgrade.md`](research/07-hardware-upgrade.md) | Fans, limpeza, upgrades de hardware |
| [`research/08-por-que-fica-cego.md`](research/08-por-que-fica-cego.md) | **Causa-raiz:** mux + sensor desacoplado |
| [`research/09-build-final-e-resultados.md`](research/09-build-final-e-resultados.md) | Diff final + medições |
| [`research/11-email-intelbras.md`](research/11-email-intelbras.md) | Rascunho de e-mail (legado; preferir relatório CSIRT) |
| [`research/13-auditoria-outros-bugs.md`](research/13-auditoria-outros-bugs.md) | Wi-Fi, xiri, postura de release |
| [`research/14-estado-final-aplicado.md`](research/14-estado-final-aplicado.md) | O que ficou no aparelho (`/vendor`) |
| [`research/15-bin-definitivo.md`](research/15-bin-definitivo.md) | Container `.bin` (em quarentena) |
| [`research/26-persistencia-do-fix.md`](research/26-persistencia-do-fix.md) | Persistência do fix térmico entre boots |
| [`research/27-teardown-cabo-gnd-ntc.md`](research/27-teardown-cabo-gnd-ntc.md) | Teardown fotografado; cabo GND/NTC; mapa da placa |

## Reparo de hardware — troca do painel LCD e correção de cor

Tema distinto do térmico: quando se **troca o micro-painel LCD** do motor óptico por um de sufixo
diferente (ex.: `RX058B-4300` de fábrica → `RX058B-0600`), as cores saem erradas nos meios-tons por
**mapeamento LVDS divergente (VESA vs JEIDA)**. Resolvido por software, sem trocar hardware.

| Doc | Conteúdo |
|---|---|
| [`research/28-troca-painel-rx058b-diagnostico-cor.md`](research/28-troca-painel-rx058b-diagnostico-cor.md) | **Diagnóstico completo + solução:** decompilação da lib do aparelho, `lvdsctl` (chama `SetLvdsFormat`), correção VESA→JEIDA no `panelparam` (byte `0x5c`). Tentativa-e-erro incluído. |
| [`research/29-roadmap-troca-lcd.md`](research/29-roadmap-troca-lcd.md) | **Roadmap e sprints (planejamento):** aplicador fácil, wizard de pareamento, auto-pareamento via câmera interna, integração no `.bin`, guia leigo, matriz de painéis, auditoria de nomenclatura de IC. |
| [`research/30-sprint-validacao-repositorio.md`](research/30-sprint-validacao-repositorio.md) | **Sprint de higiene:** validar a reorganização `mod-termica`→`docs/artifacts` (links, integridade, política de versionamento). |

Artefatos da correção de cor em [`../artifacts/lcd-color-fix/`](../artifacts/lcd-color-fix/) (`lvdsctl.c` + padrões de teste).

## Arquivo interno (histórico de auditorias)

Pasta [`archive/`](archive/) — sprints e auditorias internas (não é o caminho leigo).

## Artefatos

Pasta [`../artifacts/`](../artifacts/) — `ZYCustom.ini` stock e build, `bin-build/`, históricos.
