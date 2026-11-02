# Tarefa - `wifi_pwr` derruba o kernel (2026-11-02)

## O que se mediu (no aparelho, só leitura, 05:08)

- O dono viu o teste rodando "sem parar": os 3 últimos boots têm `sys.boot.reason=kernel_panic,NULL`, e a suíte
  roda sozinha no modo `tomada desligamento_nao_limpo` a cada boot depois de um panic.
- `pstore/console-ramoops-0`: `Unable to handle kernel NULL pointer dereference` em `aicwf_usb_bus_start`
  (`aic8800_fdrv`, workqueue `usb_hub_wq`), aos 1526 s de uptime.
- `chaves.escolhas` tinha `wifi_pwr=1`: o chip Wi-Fi (USB `1-3`) com `power/control=auto`. O `dmesg` mostra
  suspend/resume do driver a cada ~4 s. Uma volta do resume cai no NULL do driver e derruba tudo.
- O padrão de instalação de `wifi_pwr` é 0 (`padrao_de`); não se sabe quem pôs 1 (a linha já saiu da home no
  bloco 27).

## Feito na hora (coordenador, com o pedido do dono de parar)

- `kill` da `suite.sh` em curso, `force-stop` da galeria (home na tela).
- `echo on > /sys/bus/usb/devices/1-3/power/control` e `suite-chaves.sh aplicar wifi_pwr desligar`
  (escolha gravada 0, prop `1111111010`, rede ok).

## Decisão do dono (AskUserQuestion, 2026-11-02)

"Só remove o gatilho das escolhas então já que causa isso": `wifi_pwr` deixa de ser uma escolha.

## Cura na origem

- `wifi_pwr` sai das escolhas: `aplicar`/`pedido` recusam o id, o `boot` não reaplica e apaga a linha
  `wifi_pwr=` que estiver no `chaves.escolhas`, e escreve `on` no `power/control` do chip (desfaz um `auto` velho).
- A posição na prop `chaves` fica reservada (sempre `-`) para não deslocar os outros ids; a home já não mostra a
  linha. Docs (49, MAPA) dizem por quê, com o trecho do ramoops.

## Como se prova (no PC)

- `tests/test-chaves.sh`: `aplicar wifi_pwr ligar` recusa e não escreve `auto`; boot com `wifi_pwr=1` no arquivo
  apaga a linha e escreve `on`; a prop mostra `-` na posição 8. Vai no bloco 29, junto com a tarefa dos testes.

## Feito (T1, bloco 29)

- `suite-chaves.sh`: `RETIRADOS="wifi_pwr"`; `estado_de wifi_pwr` = `-` sempre; `aplicar`/`pedido` recusam (rc 2,
  "nao e mais uma escolha" no `chaves.log`); `gravar_escolha` nunca grava o id; `boot` e `resgate` chamam
  `wifi_acordado` (acha o chip por `a69c:8d80/8d81`, escreve `on` se não estiver `on`, registra a troca) e
  `apagar_retirados` (tira a linha `wifi_pwr=` do `chaves.escolhas`, 600, sem tocar as outras). O `boot` faz o
  `wifi_acordado` antes de tudo, mesmo se a pasta da suíte não estiver segura.
- `tests/test-chaves.sh`: estados com `-` na posição 8; `c_wifi_retirado` (aplicar/pedido/home recusam e nada escreve
  `auto`; boot com `wifi_pwr=1` e chip em `auto` apaga a linha e escreve `on`, achando o chip pelo id em `2-1`; id
  errado não é tocado; sem chip não quebra); o resgate não grava escolha do id e acorda o chip.
- Doc 49 §2.2.1 com o trecho do ramoops; §0.1 e §5.2 apontam para ela. `docs/codigo/kit.md` (linhas da
  `suite-chaves.sh`) ainda descreve o `wifi_pwr` antigo: fica para quem atualiza a documentação.
