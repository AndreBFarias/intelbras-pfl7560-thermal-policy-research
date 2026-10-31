# Documentação — índice

Tudo o que o repositório documenta, por tipo. Os números dos docs são únicos em todas as pastas: 10, 12, 16, 32,
36 e 49 ficam em `guide/`; 05, 11, 14, 17 a 25, 29, 30 e 31 em `archive/`; o resto em `research/`.

## Comece aqui

| Doc | Para quê |
|---|---|
| [`../README.md`](../README.md) | o que é o projeto, instalar e desfazer em uma página |
| [`../INSTALL.md`](../INSTALL.md) | o passo a passo: instalar, verificar, acompanhar, reverter, cor depois de trocar o painel |
| [`ESTADO.md`](ESTADO.md) | o que está provado, o que falta e o que é provisório (o único lugar) |
| [`glossario.md`](glossario.md) | siglas, comandos do `hidebug`, termos do projeto e prefixos de ID |
| [`MAPA.md`](MAPA.md) | cada pasta e arquivo de código: o que é, quem chama, teste, doc; pontos de entrada; fluxo de dados no aparelho |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | regras de quem mexe no código |

## Notas do código

O código não tem comentário; o porquê das decisões dele fica aqui, uma nota por área.

| Doc | Área |
|---|---|
| [`codigo/kit.md`](codigo/kit.md) | `pendrive-autorun/`: autorun, cor, suíte, gatilho, pedidos; tabela do que é provisório |
| [`codigo/pc.md`](codigo/pc.md) | comandos `pfl7560-*.sh`, instaladores e `Makefile` |
| [`codigo/apps.md`](codigo/apps.md) | app, home, tema e sobreposições (Java, `build.sh`, Python) |
| [`codigo/binarios.md`](codigo/binarios.md) | `nl_tela`, `nl_camcheck` e `lvdsctl` (C) |
| [`codigo/bin.md`](codigo/bin.md) | gerador do `.bin` (`build_fix_bin.py`, `sparse.py`) |
| [`codigo/testes.md`](codigo/testes.md) | harnesses de `tests/` |

## Guias

| Doc | Conteúdo |
|---|---|
| [`guide/10-guia-replicacao.md`](guide/10-guia-replicacao.md) | Replicar a correção em outro PFL7560 |
| [`guide/12-seguranca-e-recuperacao.md`](guide/12-seguranca-e-recuperacao.md) | Backups, revert, cenários de pânico |
| [`guide/16-recuperacao-brick.md`](guide/16-recuperacao-brick.md) | Resgate: power-hold com o `usb_update.bin` de fábrica; por que a build de julho travou |
| [`guide/32-guia-troca-painel-lcd.md`](guide/32-guia-troca-painel-lcd.md) | Trocar o painel LCD e corrigir a cor (VESA/JEIDA) |
| [`guide/36-lista-de-compras-reparo-optico.md`](guide/36-lista-de-compras-reparo-optico.md) | Lista de compras do reparo óptico (polarizador, painel, peças) |
| [`guide/49-guia-compra-fresnel.md`](guide/49-guia-compra-fresnel.md) | Lentes Fresnel: o que medir, links no Brasil e no AliExpress, armadilhas |

## Referência técnica

| Doc | Conteúdo |
|---|---|
| [`research/01-teardown-tecnico.md`](research/01-teardown-tecnico.md) | SoC, partições, como o firmware foi aberto |
| [`research/02-sistema-termico-atual.md`](research/02-sistema-termico-atual.md) | Valores térmicos de fábrica |
| [`research/03-causa-raiz-e-limites.md`](research/03-causa-raiz-e-limites.md) | Por que a óptica queima; limites do software |
| [`research/04-plano-de-build-e-riscos.md`](research/04-plano-de-build-e-riscos.md) | Caminhos de deploy e riscos |
| [`research/06-acesso-adb-e-comandos.md`](research/06-acesso-adb-e-comandos.md) | Comandos adb e `hidebug` |
| [`research/07-hardware-upgrade.md`](research/07-hardware-upgrade.md) | Ventiladores (o fato e como trocar), limpeza, dissipação |
| [`research/08-por-que-fica-cego.md`](research/08-por-que-fica-cego.md) | **Causa raiz:** o mux e o sensor desacoplado |
| [`research/09-build-final-e-resultados.md`](research/09-build-final-e-resultados.md) | O diff da correção e as medições |
| [`research/13-auditoria-outros-bugs.md`](research/13-auditoria-outros-bugs.md) | Wi-Fi, xiri, postura de release |
| [`research/26-persistencia-do-fix.md`](research/26-persistencia-do-fix.md) | Persistência da correção entre boots |
| [`research/27-teardown-cabo-gnd-ntc.md`](research/27-teardown-cabo-gnd-ntc.md) | Teardown fotografado; cabo GND/NTC; mapa da placa |
| [`research/33-matriz-paineis.md`](research/33-matriz-paineis.md) | **Painéis:** quais servem, qual formato LVDS e o histórico das trocas deste aparelho |
| [`research/34-escada-brilho-e-fanmonitor.md`](research/34-escada-brilho-e-fanmonitor.md) | Escada de brilho ancorada no sensor real, `THERMAL_MODE` e o FanMonitor inarmável |
| [`research/37-mecanismo-lsadc-defasagem-dos-aneis.md`](research/37-mecanismo-lsadc-defasagem-dos-aneis.md) | **O doc mais importante:** o mecanismo do `LSADC Error`, provado no binário, e o teste de vivacidade |
| [`research/38-motor-optico-e-troca-do-polarizador.md`](research/38-motor-optico-e-troca-do-polarizador.md) | Geometria do motor óptico e a troca do polarizador (placa de vidro separada) |
| [`research/41-auto-pareamento-camera-e-kit-universal.md`](research/41-auto-pareamento-camera-e-kit-universal.md) | Cor automática pela câmera interna e o desenho do kit universal de pendrive |
| [`research/42-firmware-2026-10-modelo-sem-usbc.md`](research/42-firmware-2026-10-modelo-sem-usbc.md) | O firmware de 2026-10-20 é do modelo **sem USB-C** (V1.0.0.1); a térmica não mudou |
| [`research/43-pesquisa-autofoco-keystone-teclas.md`](research/43-pesquisa-autofoco-keystone-teclas.md) | Autofoco, keystone, teclas do controle e o launcher, para a suíte |
| [`research/44-suite-de-boot.md`](research/44-suite-de-boot.md) | **A suíte de verificação:** instalação, gatilhos, etapas, telas, luz, descanso, desinstalar, PROVISÓRIO e o roteiro de teste no aparelho |
| [`research/45-home-pfl7560.md`](research/45-home-pfl7560.md) | **A home MeowCast:** entradas, por que entra pela prop `vendor.newlink.launcher.package`, botão Luz |
| [`research/46-foco-e-qualidade.md`](research/46-foco-e-qualidade.md) | Foco pelo `hidebug` (`gfd`, `sfd`), ajustes de imagem, resolução e keystone |
| [`research/48-tema-no-sistema.md`](research/48-tema-no-sistema.md) | **Tema Drácula no sistema:** as 20 sobreposições (RRO) e o que fica de fora |

## Sessões de bancada (diário, citadas por §)

| Doc | Conteúdo |
|---|---|
| [`research/28-troca-painel-rx058b-diagnostico-cor.md`](research/28-troca-painel-rx058b-diagnostico-cor.md) | 1ª troca de painel: diagnóstico, `lvdsctl` e o byte `0x5c` da `panelparam` |
| [`research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md`](research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md) | A proteção cegou no meio do uso; ferramentas passivas (saúde, vigia, props) |
| [`research/39-sessao-2026-09-02-optica-e-balanco-termico.md`](research/39-sessao-2026-09-02-optica-e-balanco-termico.md) | Reparo óptico e auditoria do balanço térmico; a sala como maior alavanca; o clamp do brilho em 750 |
| [`research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md`](research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) | 2ª troca de LCD, onde fica o NTC do `gtt1` (OPT-S7), 3 ventiladores (OPT-S6) e a auditoria de código e docs |

## Build `.bin`

| Doc | Conteúdo |
|---|---|
| [`research/47-build-completa.md`](research/47-build-completa.md) | **O doc único do `.bin`:** o que leva, as builds S4a e S4b, a forma do sparse, o roteiro de gravação, a definição de pronto e a ordem das gravações |
| [`research/15-bin-definitivo.md`](research/15-bin-definitivo.md) | O formato do container LOAD e os checksums |
| [`../firmware/README.md`](../firmware/README.md) | Firmwares de fábrica e a tabela das nossas builds |
| [`../artifacts/bin-build/README.md`](../artifacts/bin-build/README.md) | O gerador (`build_fix_bin.py`) e o manifesto |

## Tarefas por bloco

Cada bloco tem a seção "Estado" no fim.

| Doc | Conteúdo |
|---|---|
| [`sprints/2026-10-29-bloco-1-cor-e-gravacao.md`](sprints/2026-10-29-bloco-1-cor-e-gravacao.md) | Backup antes de gravar na `panelparam`, `term_ok`, `install.bat`, builder |
| [`sprints/2026-10-29-bloco-2-medicao.md`](sprints/2026-10-29-bloco-2-medicao.md) | Locale, boots, root, `saude` pelo byte gravado, IP com porta e Ctrl-C |
| [`sprints/2026-10-29-bloco-3-docs-sem-autorrefutacao.md`](sprints/2026-10-29-bloco-3-docs-sem-autorrefutacao.md) | Docs sem autorrefutação |
| [`sprints/2026-10-29-bloco-4-prova-da-build.md`](sprints/2026-10-29-bloco-4-prova-da-build.md) | Prova de que a build é funcional |
| [`sprints/2026-10-29-bloco-5-kit-universal.md`](sprints/2026-10-29-bloco-5-kit-universal.md) | Kit universal de pendrive: térmica e cor (bancada E4 aberta) |
| [`sprints/2026-10-30-bloco-6-licoes-do-firmware-novo.md`](sprints/2026-10-30-bloco-6-licoes-do-firmware-novo.md) | Kit, builder e fix para os dois modelos |
| [`sprints/2026-10-30-bloco-7-cor-automatica.md`](sprints/2026-10-30-bloco-7-cor-automatica.md) | Cor automática pela câmera, escada de 16 cinzas e `force-stop` da galeria entre telas |
| [`sprints/2026-10-30-bloco-8-camera-robusta.md`](sprints/2026-10-30-bloco-8-camera-robusta.md) | Câmera robusta (janela 47–53 %, 1280×720); prova no aparelho com reboot |
| [`sprints/2026-10-30-bloco-9-suite-de-boot.md`](sprints/2026-10-30-bloco-9-suite-de-boot.md) | Suíte de boot: decisões do dono e contratos C-geo, C-tela e C-res |
| [`sprints/2026-10-30-bloco-9a-tela-e-geometria.md`](sprints/2026-10-30-bloco-9a-tela-e-geometria.md) | `nl_tela` e `nl_camcheck geometria` |
| [`sprints/2026-10-30-bloco-9b-suite.md`](sprints/2026-10-30-bloco-9b-suite.md) | A suíte, o serviço de boot e os gatilhos |
| [`sprints/2026-10-30-bloco-9c-app-pendrive-docs.md`](sprints/2026-10-30-bloco-9c-app-pendrive-docs.md) | App, pendrive com firmware, `pfl7560-processos.sh` |
| [`sprints/2026-10-31-bloco-10-home-e-tema-dracula.md`](sprints/2026-10-31-bloco-10-home-e-tema-dracula.md) | Home nova e tema Drácula |
| [`sprints/2026-10-31-bloco-11-qualidade-e-foco.md`](sprints/2026-10-31-bloco-11-qualidade-e-foco.md) | Nitidez 3x3, varredura fina de foco, `pfl7560-qualidade.sh` |
| [`sprints/2026-10-31-bloco-12-build-completa.md`](sprints/2026-10-31-bloco-12-build-completa.md) | Gerador do `.bin` por manifesto |
| [`sprints/2026-10-31-bloco-13-tema-no-sistema.md`](sprints/2026-10-31-bloco-13-tema-no-sistema.md) | Sobreposições no sistema e ícones na home |
| [`sprints/2026-10-31-bloco-14-kit-tema-vlc.md`](sprints/2026-10-31-bloco-14-kit-tema-vlc.md) | O kit leva sobreposições, apps desligados e marca; `pfl7560-marca.sh` e `pfl7560-vlc.sh` |
| [`sprints/2026-10-31-bloco-15-luz-na-home.md`](sprints/2026-10-31-bloco-15-luz-na-home.md) | Botão Luz na home |
| [`sprints/2026-10-31-bloco-16-tema-em-tudo.md`](sprints/2026-10-31-bloco-16-tema-em-tudo.md) | Sobreposições para o resto, descanso de tela, home sem Espelhamento |
| [`sprints/2026-10-31-bloco-17-overlays-restantes.md`](sprints/2026-10-31-bloco-17-overlays-restantes.md) | Seis sobreposições a mais |
| [`sprints/2026-10-31-bloco-18-overlays-finais.md`](sprints/2026-10-31-bloco-18-overlays-finais.md) | As últimas telas e a sobreposição do `android` v3 |
| [`sprints/2026-10-31-bloco-19-fechamento.md`](sprints/2026-10-31-bloco-19-fechamento.md) | Foco pela câmera, layouts só de cor, o teste intermitente |
| [`sprints/2026-10-31-bloco-20-revisao.md`](sprints/2026-10-31-bloco-20-revisao.md) | Revisão final do conjunto |
| [`sprints/2026-10-31-bloco-21-limpeza-bugs-bin.md`](sprints/2026-10-31-bloco-21-limpeza-bugs-bin.md) | Limpeza, bugs, leitura fácil e o `.bin` nos blocos do stock |

## Divulgação

| Doc | Conteúdo |
|---|---|
| [`disclosure/STATUS.md`](disclosure/STATUS.md) | Estado do envio, impacto no consumidor (CDC) e o que falta para publicar |
| [`disclosure/relatorio-csirt.md`](disclosure/relatorio-csirt.md) | O relatório para o CSIRT da Intelbras |
| [`disclosure/roteiro-evidencias.md`](disclosure/roteiro-evidencias.md) | Roteiro de captura de evidências |
| [`dossie-teardown.html`](dossie-teardown.html) | Dossiê visual do teardown |

## Arquivo (histórico, não é o caminho atual)

| Doc | Conteúdo |
|---|---|
| [`archive/05-ZYCustom.ini-proposto.md`](archive/05-ZYCustom.ini-proposto.md) | Rascunho de parâmetros de julho, superado pela correção em uso |
| [`archive/11-email-intelbras.md`](archive/11-email-intelbras.md) | Rascunho de e-mail, superado pelo relatório CSIRT |
| [`archive/14-estado-final-aplicado.md`](archive/14-estado-final-aplicado.md) | O aparelho em 2026-07-05, antes da escada e do MeowCast |
| [`archive/17-auditoria-e-hardening.md`](archive/17-auditoria-e-hardening.md) | Auditoria adversarial das soluções de entrega |
| [`archive/18-sprint-bin-futuro.md`](archive/18-sprint-bin-futuro.md) | Sprint do `.bin` que boota (sub-sprints BIN-S*) |
| [`archive/19-sprint-warning-tela.md`](archive/19-sprint-warning-tela.md) | Aviso na tela quando a correção não está ativa (virou a suíte) |
| [`archive/20-auditoria-integral-2026-07-06.md`](archive/20-auditoria-integral-2026-07-06.md) | Auditoria integral de 2026-07-06 |
| [`archive/21-sprint-integridade-backup.md`](archive/21-sprint-integridade-backup.md) | Integridade byte-exata do backup e restore |
| [`archive/22-sprint-sincronizacao-docs.md`](archive/22-sprint-sincronizacao-docs.md) | Sincronização da documentação |
| [`archive/23-sprint-robustez-scripts.md`](archive/23-sprint-robustez-scripts.md) | Atomicidade e robustez dos instaladores |
| [`archive/24-sprint-perfis-seguros.md`](archive/24-sprint-perfis-seguros.md) | Perfis seguros |
| [`archive/25-sprint-acentuacao.md`](archive/25-sprint-acentuacao.md) | Acentuação pt-BR |
| [`archive/29-roadmap-troca-lcd.md`](archive/29-roadmap-troca-lcd.md) | Roadmap da troca de LCD (LCD-S1 a S7), já executado |
| [`archive/30-sprint-validacao-repositorio.md`](archive/30-sprint-validacao-repositorio.md) | Higiene do repositório de julho (o REPO-S2 foi para `disclosure/STATUS.md`) |
| [`archive/31-plano-mestre-bin-final.md`](archive/31-plano-mestre-bin-final.md) | Plano do `.bin` de julho (o que vale está no doc 47 §11) |
| [`archive/relatorio.html`](archive/relatorio.html) | "O Sensor Cego", laudo térmico visual de julho |

## Fora de `docs/`

| Onde | O que tem |
|---|---|
| [`../artifacts/README.md`](../artifacts/README.md) | Mapa de `artifacts/`: arquivos de referência com md5 e o README de cada pasta (app, home, tema, overlay, tela, camcheck, lcd-color-fix, bin-build, re-termico) |
| [`../tests/README.md`](../tests/README.md) | Os quatro alvos do `make`, o que cada teste prova e as fixtures |
| [`../media/README.md`](../media/README.md) | Fotos do aparelho aberto e a auditoria de privacidade |
| [`../firmware/README.md`](../firmware/README.md) | Firmwares de fábrica e builds |
| [`../pendrive-autorun/LEIA-ME.txt`](../pendrive-autorun/LEIA-ME.txt) | O resumo que vai no pendrive (ASCII) |
