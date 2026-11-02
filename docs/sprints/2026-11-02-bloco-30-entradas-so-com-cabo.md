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

## Notas do E1 (2026-11-02)

- **Sinal achado:** o estado das entradas de TV do `TvInputManager`. É API pública, sem permissão e sem root, e
  avisa sozinha pelo `TvInputCallback.onInputStateChanged`.
  - O `system_server` (`TvInputHardwareManager`) marca a entrada `.../HiHdmiTvInputService/HDMI0000C<porta>` com
    0 quando há cabo e 1 quando não há, a partir do hotplug do `HdmiControlService`.
  - A porta é a fonte − 8: C3 = HDMI 1, C2 = HDMI 2, C1 = USB-C.
  - O teste de fábrica (`NLAutoTest`) usa exatamente essa conta e `getInputState(id) == 0`.
  - Prova e descartados (broadcast só para o `com.zhiying.settings`, `HdmiControlManager` com `HDMI_CEC`): doc 45 §14.
- **Sem prop nova nem vigia:** a suíte não muda.
- **Decisões:**
  - Um botão por porta com cabo, na ordem HDMI 1, HDMI 2, USB-C.
  - Falha aberta: sem leitura, ou com a porta ausente entre as entradas de TV, o botão aparece.
  - Um cabo novo nunca puxa o foco, salvo na primeira leitura, se o dono ainda não mexeu.
- **Falta medir no aparelho (doc 45 §14.4):** `dumpsys tv_input | grep -E 'HDMI0000C[0-9]+: '`, sem cabo e com
  cabo em cada porta.
  - Esperado: `state: 1` sem cabo e `state: 0` com cabo.
  - O risco maior é o USB-C (C1).

## Medições no aparelho (2026-11-02, coordenador, só leitura)

`dumpsys tv_input`, entrada `.../HiHdmiTvInputService/HDMI0000C<n>` (0 = conectado, 1 = sem cabo):

| cabos ligados | C1 | C2 | C3 | hdmirx `OffLineDetStatus` | `vendor.nl.setting.hdmi.state` |
|---|---|---|---|---|---|
| HDMI 1 e HDMI 2 (USB-C vazio) | 0 | 0 | 0 | port0/1/2 On, port3 Off | 3 |
| nenhum | 0 | 1 | 1 | port0 On, port1/2/3 Off | 0 |
| só HDMI 1 | 0 | 1 | 0 | - | - |

- **Mapeamento confirmado:** C3 = HDMI 1, C2 = HDMI 2 (o que o código já faz: fonte − 8). O HDMI pelo
  `TvInputManager` funciona.
- **USB-C:** nunca teve nada ligado e o C1 sempre lê 0 ("conectado"); o port0 do hdmirx também fica sempre On.
  O `TvInputManager` **não** serve para o USB-C, e a falha aberta mostraria o USB-C sempre, o contrário do pedido.
  Falta achar outro sinal; se não houver um confiável, a decisão (mostrar sempre ou esconder) é do dono, pelo
  coordenador. O E1 não decide sozinho.
- `zysys.source.*` não muda com o cabo.

## Pedido novo do dono (2026-11-02)

- Tirar da home o texto do contador de apps ("2 apps").
- Pôr "MeowCast" no canto inferior direito da home.
- Atualizar as prévias da home.

## Estado (E1, 2026-11-02, depois do reset)

- Feito e commitado na `bloco-30`: home com HDMI só com cabo (C3 = HDMI 1, C2 = HDMI 2, já era a conta do
  código); contador de apps fora e "MeowCast" no canto inferior direito; prévias; doc 45 §14.4 e §14.5; APK
  versionCode 10 no kit (md5 `f25b21910bb164c408af36c7e1258406`).
- Provas verdes: `gerar-previas.sh` (navegação, entradas, ajustes), `make check`, `make check-kit` (todos os
  `tests/test-*.sh` do kit, md5 do kit em dia), `test-fix-modelo.sh`, `test-builder-bin.py`,
  `shellcheck -S warning` nos `.sh` tocados.
- **USB-C decidido (dono, 2026-11-02): sempre visível**, HDMI 1/2 só com cabo. Medição com notebook ligado no
  USB-C, sem trocar de entrada: `tv_input`, `OffLineDetStatus` do hdmirx, `/sys/bus/usb/devices` e `getprop`
  idênticos ao vazio; só o `dmesg` mudou (reconexão do port2, HDMI 1). Doc 45 §14.4.
- Feito: `Entradas.comCabo` recebe só "o firmware tem USB-C"; teste de modelo (sem cabo HDMI, só o USB-C; ligar e
  tirar HDMI com o foco nele cai no USB-C); prévias `home-sem-cabo`/`home-cabo-hdmi2` no estado novo; APK e md5.
- Provas depois da decisão: `gerar-previas.sh`, `make check`, `make check-kit`, `test-fix-modelo.sh`,
  `test-builder-bin.py` verdes (16 suítes, 0 falha); o `test-suite.sh` falhou uma vez em "luz: a verificação
  continua funcionando" e passou nas três rodadas seguintes (intermitente, fora da home).
- Próximo: E2 confere; o dono confere na mão pelo pendrive do kit.
