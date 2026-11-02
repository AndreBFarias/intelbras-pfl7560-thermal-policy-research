# Bloco 22 - Debloat e hardware não usado (pesquisa, 2026-11-01)

Pedido do dono (2026-11-01): com o Bluetooth e o Wi-Fi desligados o projetor fica ~5 °C mais frio. A build de
fábrica deixava rodando coisa que não servia (câmera ligada sem uso, sensor de calor sem leitura, imagem esticada).
Quer uma análise minuciosa, no estilo do Universal Android Debloater, do que roda em segundo plano, e saber se há
mais hardware que o software não usa.

Uso declarado pelo dono: **só Wi-Fi** (e mesmo ele fica desligado pela home quase sempre). Não usa Bluetooth,
USB-C, espelhamento de tela (já não existe), VLC nem o pacote Office.

## Saída

`docs/research/49-debloat-e-hardware.md`, com:

1. **Inventário do que roda:** processos (`ps -A`), serviços nativos (`init.svc.*`), apps habilitados, serviços
   Android ativos, receivers de boot, alarmes, wakelocks (`dumpsys power`), jobs, uso de CPU (`top -n 1`,
   `dumpsys cpuinfo`), memória. Cada item com: o que é, quem precisa, risco de desligar, classificação
   (manter / desligar seguro / desligar com cuidado / não mexer) e como desligar de forma reversível
   (`pm disable-user --user 0`, `svc`, `settings`, prop).
2. **Rádios e periféricos:** Bluetooth, Wi-Fi, USB-C (controlador e alimentação), câmera, mic: o que fica ligado
   mesmo sem uso, o que consome, como desligar de forma reversível.
3. **Hardware não usado pelo software:** device tree (`artifacts/firmware-extraido/full_dts.txt`), drivers
   carregados, `/sys`, i2c, GPIOs, sensores, e as chaves do `ZYCustom.ini` que o firmware aceita e a fábrica nunca
   configurou (o doc 34 já achou o sensor de RPM dos ventiladores, `SW_SENSE_TYPE`). Para cada achado: evidência,
   o que daria para ganhar, risco.
4. **Respostas que o bloco 23 precisa** (estático, pelo doc 34, `artifacts/re-termico` e o `libhitvservice.so`
   puxado do aparelho):
   - a política do firmware reescreve o `sfs` por cima? de quanto em quanto tempo? sem `stp -1`;
   - `sbri` ao vivo briga com a escada da `BacklightPolicy`? e a relação entre `sbl` (botão Luz) e `sbri`;
   - a semântica exata de `FW_SPEED_CURVE` e dos degraus da `BacklightPolicy` no `.ini`;
   - o que o botão POWER do controle faz (standby) e como disparar o mesmo pelo shell.
5. **Roteiro de medida** pronto para o coordenador rodar com o dono: um gravador no próprio aparelho que guarda
   a temperatura (pelas props, nunca `gtt`) num arquivo enquanto o Wi-Fi/BT/apps são desligados um a um, porque
   desligar o Wi-Fi derruba o adb. E os experimentos de `sfs`/`sbri` ao vivo, se o estático não fechar.

## Regras

- No aparelho (192.168.1.5:5555), **só leitura**: `getprop`, `dumpsys`, `ps`, `top`, `cat`, `ls`, `logcat -d`,
  `pm list`, `adb pull`. Proibido: `gtt` (cega a proteção, doc 37), `sfs`, `sbri`, `sbl`, `stp`, `setprop`,
  `settings put`, `svc`, `pm disable/enable/uninstall`, `install`, `reboot`, `input`, `am start`, desligar rádio.
  O dono usa o projetor como monitor do PC agora: nada pode mudar a imagem, o som nem o ventilador.
- Não editar arquivo fora de `docs/research/49-*.md` e de `artifacts/re-termico/` (só acrescentar).
- Afirmação com evidência (comando e saída, ou endereço no binário); inferência marcada como INFERIDO.

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| P1 | Opus, high | pesquisa e escreve o doc 49 |
| P2 | Opus, high | confere cada afirmação do doc 49 contra o aparelho e o binário, e corrige |

## Estado

- [x] P1 (doc 49 escrito)
- [x] P2 (doc 49 corrigido em 11 pontos, §7)
- [ ] o coordenador roda o roteiro de medida com o dono
