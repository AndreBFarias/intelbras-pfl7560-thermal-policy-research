# Documentação técnica — PFL7560 thermal policy research

Índice da pesquisa e dos guias. Para **aplicar a correção**, comece pelo [`../INSTALL.md`](../INSTALL.md) e pelo [`../README.md`](../README.md) na raiz.

## Guias (uso prático)

| Doc | Conteúdo |
|---|---|
| [`guide/10-guia-replicacao.md`](guide/10-guia-replicacao.md) | Replicar a correção em outro PFL7560 |
| [`guide/12-seguranca-e-recuperacao.md`](guide/12-seguranca-e-recuperacao.md) | Backups, revert, cenários de pânico |
| [`guide/16-recuperacao-brick.md`](guide/16-recuperacao-brick.md) | Power-hold + `usb_update.bin` de fábrica |
| [`guide/32-guia-troca-painel-lcd.md`](guide/32-guia-troca-painel-lcd.md) | Guia leigo: trocar o painel LCD e corrigir a cor (VESA/JEIDA) |
| [`guide/36-lista-de-compras-reparo-optico.md`](guide/36-lista-de-compras-reparo-optico.md) | Lista de compras do reparo óptico (polarizador, painel, peças) |

## Divulgação responsável

| Doc | Conteúdo |
|---|---|
| [`disclosure/relatorio-csirt.md`](disclosure/relatorio-csirt.md) | Relatório ≤3 páginas para CSIRT / suporte |
| [`disclosure/STATUS.md`](disclosure/STATUS.md) | Data de envio, protocolo, follow-up |
| [`disclosure/roteiro-evidencias.md`](disclosure/roteiro-evidencias.md) | Roteiro de captura de evidências (fotos, medições, redação de dados pessoais) |

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
| [`research/34-escada-brilho-e-fanmonitor.md`](research/34-escada-brilho-e-fanmonitor.md) | Alarme de 70 °C, **escada de brilho** ancorada no sensor real, `THERMAL_MODE`, e o FanMonitor **inarmável por software** |
| [`research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md`](research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md) | Sessão de campo: a proteção cegou no meio do uso; ferramental novo (saúde / vigia / props); quem sonda e quem não sonda |
| [`research/37-mecanismo-lsadc-defasagem-dos-aneis.md`](research/37-mecanismo-lsadc-defasagem-dos-aneis.md) | **O documento mais importante do projeto.** O mecanismo do `LSADC Error`: defasagem dos anéis de amostras, provado no binário. Explica os dois regimes com um único mecanismo, dá o **teste de vivacidade** (`--vivacidade`) e o experimento decisivo de 2 minutos |
| [`research/38-motor-optico-e-troca-do-polarizador.md`](research/38-motor-optico-e-troca-do-polarizador.md) | **A geometria do motor óptico**, observada com o aparelho aberto, e o procedimento de troca do polarizador. **Fecha o POL-S1:** o polarizador é placa de vidro **separada** (não laminada ao painel). Corrige dois registros errados do doc 07 |
| [`research/39-sessao-2026-09-02-optica-e-balanco-termico.md`](research/39-sessao-2026-09-02-optica-e-balanco-termico.md) | **Reparo óptico executado** (3ª troca de polarizador, Fresnel limpas) e **auditoria adversarial do balanço térmico**: seis registros do repositório derrubados, incluindo "os ventiladores são axiais" (são centrífugos — a lista de compras do doc 07 compraria peça que não monta) e "o teto do software foi atingido". **O experimento que discrimina vazão de acoplamento nunca foi rodado** |
| [`research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md`](research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) | **2ª troca de LCD: o painel novo é VESA** (o aparelho estava em JEIDA); medição térmica com o `gtt1` +8,17 °C sobre a base, com ressalvas; **OPT-S7 fechado:** o `gtt1` mede o **bloco dissipador do LED** e nenhum sensor mede o polarizador/LCD; **OPT-S6 fechado:** 3 ventiladores; 26 achados de auditoria de código e docs em 4 blocos |
| [`research/41-auto-pareamento-camera-e-kit-universal.md`](research/41-auto-pareamento-camera-e-kit-universal.md) | **Cor automática após troca de LCD:** a câmera interna é USB UVC (lida direto por V4L2, captura ainda não provada); não existe ID elétrico do painel; critério **"duas metades" 63\|64** que não se engana com balanço de branco; desenho do **kit universal** de pendrive (térmica + cor, idempotente, para leigo) |
| [`research/42-firmware-2026-10-modelo-sem-usbc.md`](research/42-firmware-2026-10-modelo-sem-usbc.md) | **Firmware de 2026-10-20 decompilado:** é o modelo **sem USB-C** (V1.0.0.1), não atualização do V1.0.0.9; **a térmica não mudou** (o bug do mux segue de fábrica); 4 perfis de painel novos; não aplicar no aparelho com USB-C; lições para o kit e o builder |

## Reparo de hardware — troca do painel LCD e correção de cor

Tema distinto do térmico: quando se **troca o micro-painel LCD** do motor óptico, as primárias saem
certas e o preto/cinzas saem tingidos se o **formato LVDS (VESA ou JEIDA)** não casar com o painel. Na 1ª
troca o `RX058B-0600` pediu JEIDA; na 2ª (2026-10-29) o `RX058B-4300` instalado pediu VESA; na 3ª (2026-10-30)
o painel pediu JEIDA, e o aparelho está hoje em JEIDA (doc 41 §8). O formato não se deduz do nome: decide o teste de cinza (escada de 16 cinzas, doc 41 §4).
Resolvido por software, sem trocar hardware.

| Doc | Conteúdo |
|---|---|
| [`research/28-troca-painel-rx058b-diagnostico-cor.md`](research/28-troca-painel-rx058b-diagnostico-cor.md) | **Diagnóstico completo + solução da 1ª troca:** decompilação da lib do aparelho, `lvdsctl` (chama `SetLvdsFormat`), correção VESA→JEIDA no `panelparam` (byte `0x5c`). Tentativa-e-erro incluído; a §12.1 foi refutada pela §13 e pelo doc 40. |
| [`research/29-roadmap-troca-lcd.md`](research/29-roadmap-troca-lcd.md) | **Roadmap e sprints (planejamento):** aplicador fácil, wizard de pareamento, auto-pareamento via câmera interna, integração no `.bin`, guia leigo, matriz de painéis, auditoria de nomenclatura de IC. |
| [`research/33-matriz-paineis.md`](research/33-matriz-paineis.md) | **Matriz de painéis compatíveis + auditoria de nomenclatura (LCD-S6/S7):** quais painéis, qual formato LVDS, e por que o nome do perfil não garante compatibilidade. |
| [`research/30-sprint-validacao-repositorio.md`](research/30-sprint-validacao-repositorio.md) | **Sprint de higiene:** validar a reorganização `mod-termica`→`docs/artifacts` (links, integridade, política de versionamento). |
| [`research/31-plano-mestre-bin-final.md`](research/31-plano-mestre-bin-final.md) | **Plano mestre:** caminho crítico único até o `.bin` final — ordena todas as sprints pendentes por dependência e marca os gates de hardware. Comece por aqui para entender o todo. |

Artefatos da correção de cor em [`../artifacts/lcd-color-fix/`](../artifacts/lcd-color-fix/) (`lvdsctl.c` + padrões de teste).

## Tarefas por bloco (2026-10)

Os blocos de correção abertos a partir da sessão do doc 40, cada um com a seção "Estado" no fim.

| Doc | Conteúdo |
|---|---|
| [`sprints/2026-10-29-bloco-1-cor-e-gravacao.md`](sprints/2026-10-29-bloco-1-cor-e-gravacao.md) | Backup antes de gravar na `panelparam`, `term_ok`, `install.bat`, builder (feito; T1.1 virou o bloco 5) |
| [`sprints/2026-10-29-bloco-2-medicao.md`](sprints/2026-10-29-bloco-2-medicao.md) | Locale, boots, root, `saude` pelo byte gravado, IP com porta e Ctrl-C (feito) |
| [`sprints/2026-10-29-bloco-3-docs-sem-autorrefutacao.md`](sprints/2026-10-29-bloco-3-docs-sem-autorrefutacao.md) | Docs sem autorrefutação |
| [`sprints/2026-10-29-bloco-4-prova-da-build.md`](sprints/2026-10-29-bloco-4-prova-da-build.md) | Prova de que a build é funcional (partes no aparelho abertas) |
| [`sprints/2026-10-29-bloco-5-kit-universal.md`](sprints/2026-10-29-bloco-5-kit-universal.md) | Kit universal de pendrive: térmica + cor "duas metades" (software feito; bancada aberta) |
| [`sprints/2026-10-30-bloco-6-licoes-do-firmware-novo.md`](sprints/2026-10-30-bloco-6-licoes-do-firmware-novo.md) | Kit, builder e fix para os dois modelos (feito, só em software) |
| [`sprints/2026-10-30-bloco-7-cor-automatica.md`](sprints/2026-10-30-bloco-7-cor-automatica.md) | Cor automática pela câmera interna (`nl_camcheck faixas/niveis`), escada de 16 cinzas no lugar das duas metades e `force-stop` da galeria entre telas (em código e provado com stubs; falta a prova no aparelho) |

## Arquivo interno (histórico de auditorias)

Pasta [`archive/`](archive/) — sprints e auditorias internas (não é o caminho leigo).

## Artefatos

Pasta [`../artifacts/`](../artifacts/) — `ZYCustom.ini` stock e build, `bin-build/`, históricos.
