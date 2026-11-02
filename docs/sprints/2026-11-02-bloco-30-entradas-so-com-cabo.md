# Bloco 30 - HDMI e USB-C na home só com cabo ligado (2026-11-02)

Pedido do dono (2026-11-02, depois do flash da S5 dar certo): "se conseguirmos fazer com que do hdmi só apareça a
opção pra clicar na tela e o usb c só apareça na tela da home caso tenha de fato um dispositivo conectado na porta
seria perfeito". Decisão pelo AskUserQuestion: **os dois só com cabo**: os botões HDMI e USB-C só aparecem na home
quando há um aparelho ligado na porta; sem cabo, nenhum aparece. (Revê o bloco 27, que tirou o USB-C de Entradas.)

## O que se mediu (aparelho, só leitura, ~11:30, sem cabo nenhum)

- Props: `zysys.hdmi_count=2`, `zysys.source.hdmi1=11`, `zysys.source.hdmi2=10`, `zysys.typec_count=1`,
  `zysys.source.typec1=9`, `zysys.usb_signal_enable=0`, `vendor.nl.setting.hdmi.state=3`,
  `persist.newlink.blhdmi=2`, `vendor.newlink.hisi.hdmiisdialog=0` (pop-up desligado pelo `pop_disp`).
- Sem `/sys/class/typec`, `extcon` nem `switch`. Serviço `hipluginserver` rodando.
- O pop-up "Dispositivo conectado" é do `com.zhiying.settings` (HDMIService): ele já recebe o evento de cabo
  ligado/desligado de algum lugar - achar de onde (dumps e APKs decompilados no repositório).

## Cura na origem

1. Achar, nos dumps/APKs já guardados, o sinal de "cabo presente" por porta (HDMI1, HDMI2, USB-C) que um
   `untrusted_app` consegue ler sem root (broadcast, prop, API do `HitvManager`/`TvSourceManager`, provider). Se
   só root lê, a suíte (`suite-boot`/vigia) publica uma prop `vendor.pfl7560.*` legível pela home, no mesmo
   modelo das outras.
2. A home mostra o botão da entrada só enquanto o cabo está presente e reage ao ligar/desligar sem precisar
   reabrir (sem I/O no thread principal, sem engolir tecla, foco não pula para lugar errado quando o botão some).
3. O pop-up continua desligado (`pop_disp`); o botão na home é o único caminho.

## Como se prova

- No PC: teste de modelo (com/sem cabo em cada porta, botão some com o foco nele), prévias da home nos 2 estados,
  `tests/test-*.sh`, `make check`, `shellcheck`, md5 do kit.
- No aparelho (coordenador, com o dono plugando e tirando um cabo): ler o sinal escolhido nos dois estados.
- Entrega pelo pendrive do kit (não precisa de flash).

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| E1 | Opus, high | acha o sinal e implementa (avulso: pode pedir medição no aparelho ao coordenador) |
| E2 | Opus, high | confere, corrige, regressão |
