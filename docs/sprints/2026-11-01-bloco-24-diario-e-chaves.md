# Bloco 24 - Diário compacto + chaves na home para as curas do doc 49 (2026-11-01, depois do bloco 23)

Decisão do dono (rodada 2, 2026-11-01): **juntar** o diário e as curas num bloco só, e **"Eu quero via interface
poder fazer tudo isso e eu mesmo testar. Isso pra todas as questões que falamos aqui"**. Cada cura vira uma chave
na home, que o dono liga, testa no uso e desliga. Nenhuma é imposta pelo kit.

## 1. Chaves na home (tela nova, "Ajustes do sistema" ou dentro de uma existente)

Cada chave: estado lido do aparelho (não suposto), aplicação pelo lado root (mesmo canal de pedido da suíte),
volta pela mesma chave, e o estado escolhido sobrevive ao reboot (o kit reaplica no boot). Um arquivo no pendrive
desliga todas de uma vez (resgate).

| Chave | Faz | Volta | Padrão ao instalar |
|---|---|---|---|
| Debloat por grupo (seguros; telemetria e OTA; players e menus HiSilicon; launcher de fábrica; VLC e Office) | `pm disable-user --user 0` na lista do grupo (`2026-11-01-tarefa-curas-do-doc-49.md`) | `pm enable` | o que o dono aprovou na rodada 1: **todos ligados** |
| Silenciar o log do vplugin | `setprop log.tag.HI_VPLUGIN S` | `setprop log.tag.HI_VPLUGIN ""` | ligado (rodada 1) |
| Porta de cabo (`eth0`) | `ip link set eth0 down` | `up` | desligado (o dono testa) |
| Chip Wi-Fi dorme (AIC8800) | `echo auto > .../power/control` do dispositivo USB do AIC8800 (achar pelo id, não pelo `1-3` fixo) | `echo on` | desligado (o dono testa; pode derrubar o Wi-Fi e o adb) |
| Servidor web (:80) e `cmdsrv` | `stop boa`, `stop cmdsrv` | `start` | desligado (rodada 1: "deixar como está") |
| Mecanismo do keystone | `persist.hisi.keystone.enable=false` (vale no próximo boot) | `true` | desligado (rodada 2: "deixar ligado") |

O protetor de tela **não** entra em chave de debloat (a feature 3 do bloco 23 depende dele).

## 2. Diário compacto (o antigo bloco 24)

- No aparelho: 1 linha por minuto lida das props (nunca `gtt`, nunca logcat contínuo), em 2 arquivos de 256 KB
  que se revezam.
- No PC: timer `systemd --user` a cada 2 min que faz `adb pull` para `logs-projetor/` quando o projetor está na
  rede, corrigindo o relógio pelo uptime.
- As chaves da §1 registram no diário quando mudam (para o dono ligar o que mudou ao que sentiu).
- **Na home também** (ordem do dono: "tudo eu vou querer criado na interface"): chave liga/desliga do diário,
  tamanho atual, hora do último envio ao PC, e um botão "enviar agora" que só marca o pedido (o PC puxa).

## Regras

- Kit em ASCII puro, `sh` do Android, PATH fixo; md5 só por `bash tests/atualizar-md5-kit.sh`; `versionCode` 7.
- Nenhum agente fala com o projetor; o coordenador instala com o dono.
- Arquivos: os mesmos do bloco 23. Ordem do dono: rodar **em paralelo** com o 23. Por isso o bloco 24 trabalha
  no branch `bloco-24`, na árvore `~/Apate/Desenvolvimento/.arvores/bloco24/` (git worktree), com um commit por
  tarefa. O coordenador junta no `main` depois que o 23 for commitado; o `versionCode` e as listas de md5 são
  refeitos na integração.

## Agentes (2)

| agente | modelo | o quê |
|---|---|---|
| D1 | Sonnet, high | implementa §1 e §2, com testes |
| D2 | Opus, high | confere e corrige (segurança das chaves, resgate, regressão) |

## Estado

- [ ] D1
- [ ] D2
- [ ] o coordenador instala no aparelho com o dono
