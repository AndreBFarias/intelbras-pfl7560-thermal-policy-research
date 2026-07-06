# Projeto: Build térmica melhorada — Intelbras PFL7560

Objetivo: **reduzir o superaquecimento que está queimando o polarizador/LCD** (já trocados 2x em 18 meses),
via alteração de software, sem brickar o aparelho.

## Status (atualizado em 2026-07-06)

| Etapa | Estado |
|---|---|
| Teardown do firmware V1.0.0.9 (4 agentes) | CONCLUIDO |
| Verificação manual dos valores térmicos (`ZYCustom.ini`) | CONFERIDO |
| Pesquisa de viabilidade/segurança (adb, verity, container, recuperação de brick) | CONCLUIDO - todos os gates VERDES (ver 06) |
| Diagnóstico ao vivo (ler NTC via `gtt` enquanto esquenta) | CONCLUIDO - 2º sensor ativado, `gtt1` lê ~61 °C reais; fans 1000/1000 e brilho 100% medidos pós-reboot. Ver 14 |
| Definir tier de deploy (runtime / edição persistente / reflash) | DEFINIDO - override em /atv/ini (reversível); ver 04/06 |
| Config proposto (`ZYCustom.ini` agressivo) | DEFINITIVO - `artefatos/ZYCustom_390.ini` |
| **Descoberta**: conserto da cegueira | ATIVAR 2o NTC (`Thermistor_1 HW_VIRTUAL_CHANNEL=1`) → `gtt1` lê 59 C real |
| Gravar a build | **GRAVADA E VALIDADA** - fans máx no boot, mux-fix ativo, brilho 100%, proteção real a 75 C, aviso sumiu |
| Entregáveis replicação | guia adb (10) + email Intelbras (11) prontos; autorun por pendrive validado (idempotente); scripts auditados e endurecidos (17); `.bin` decifrado + construído, mas **EM QUARENTENA** (brica o boot, ver 16) |

## Veredito honesto (leia antes de tudo)

1. **A política térmica é um arquivo de TEXTO** (`/vendor/etc/ZYCustom.ini`), não código compilado.
   Mudar curva de fan, dimming e temperatura de desligamento = editar parâmetros. Isso é o que torna o projeto viável.
2. **A CPU/SoC NAO é o problema.** O calor que cozinha o polarizador vem da **fonte de luz (LED)**, não do chip.
   Portanto: **undervolt de CPU não ajuda a óptica.** O "undervolt que importa" aqui é **reduzir o brilho** (drive do LED).
3. **Os fans já chegam a 100% a 36 C sensados.** Software não faz o cooler ir além de 100%. Os ganhos reais de software são:
   - (A) **Limitar/reduzir o brilho** -> corta o calor na FONTE (maior alavanca para salvar o polarizador).
   - (B) **Fans a 100% mais cedo + piso alto** -> ganho marginal, mas de graça.
   - (C) **Desligar antes** -> rede de segurança contra dano catastrófico (troca autonomia por vida útil).
4. **Limitação de hardware é real.** Se em 10 min já está "ultra quente" com airflow externo ok e fans no máximo, boa parte é
   **duto/soprador subdimensionado** — software mitiga, não cura. Reduzir brilho é o que mais aproxima de uma cura.
5. **Os sensores (NTC) medem ar/placa, não a junção do polarizador.** Por isso a proteção a 43/45 C pode nunca disparar
   enquanto a óptica já está quente. **Precisamos medir ao vivo** (`gtt`) para calibrar limiares com dados, não chute.

## Índice

- `01-teardown-tecnico.md` — o que é o aparelho, SoC, partições, como o firmware foi aberto.
- `02-sistema-termico-atual.md` — como a ventilação/proteção funcionam HOJE (valores verbatim).
- `03-causa-raiz-e-limites.md` — por que queima, teto do software, o mito do undervolt.
- `04-plano-de-build-e-riscos.md` — os 3 caminhos de deploy, riscos, ordem segura, recuperação.
- `05-ZYCustom.ini-proposto.md` — proposta de config comentada, parâmetro a parâmetro.
- `06-acesso-adb-e-comandos.md` — cookbook: adb root, `hidebug`, diagnóstico, mitigação imediata, deploy persistente.
- `07-hardware-upgrade.md` — sopradores/ventiladores de troca, dissipadores, limpeza/duto, resfriamento externo.
- `08-por-que-fica-cego.md` — a investigação da falha (mux morto + sensor desacoplado; a conta está certa).
- `09-build-final-e-resultados.md` — **a build definitiva, o diff, os resultados medidos e a descoberta central.**
- `10-guia-replicacao.md` — passo-a-passo para outros donos aplicarem (adb + `.bin`).
- `11-email-intelbras.md` — rascunho pronto do report para a Intelbras.
- `12-seguranca-e-recuperacao.md` — cenários de pânico (reset, queda de energia) e as 3 camadas de recuperação.
- `13-auditoria-outros-bugs.md` — Wi-Fi, xiri, PowerManager, postura de segurança da release.
- `14-estado-final-aplicado.md` — o que **de fato** ficou no aparelho (método `/vendor`, validado).
- `15-bin-definitivo.md` — o checksum do container decifrado e a receita do `.bin`. **AVISO: o `.bin` está em quarentena — trava o boot (rótulo SELinux ausente), não flashe. Ver doc 16.**
- `16-recuperacao-brick.md` — como o `.bin` bricou o boot e a recuperação sem assistência (power-hold + `usb_update.bin`; plano B por UART).
- `17-auditoria-e-hardening.md` — auditoria adversarial (28 agentes) das soluções de entrega e os 15 achados corrigidos; a config em si passou byte-a-byte.
- `18-sprint-bin-futuro.md` — plano em formato de sprint para produzir um `.bin` que **boota** (corrigir os rótulos SELinux), com gate de proof-of-work em hardware.
- `artefatos/` — `ZYCustom.ini.ORIGINAL` (stock), `ZYCustom_390.ini` (**a build**), `board.dtb`, `full_dts.txt`, logs, backups, `bin-build/` (receita do `.bin`).

## Regra de ouro do projeto

> **Nada é gravado no aparelho até termos (1) um caminho de recuperação de brick confirmado e
> (2) dados de temperatura reais.** A sequência segura é: diagnosticar -> escolher o tier menos arriscado que resolve ->
> garantir recuperação -> aplicar -> medir de novo.
