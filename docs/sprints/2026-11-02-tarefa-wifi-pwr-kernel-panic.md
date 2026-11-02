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

## Cura na origem

- O kit recusa `wifi_pwr ligar` (aplicar e boot): registra no log que a medida derruba o kernel e grava 0. A
  escolha 1 que estiver no `chaves.escolhas` vira 0 no boot. Posição na prop fica (`-`/0).
- Doc 49 (hardware): o autosuspend do AIC8800 é inseguro neste driver; prova = o trecho do ramoops.

## Como se prova (no PC)

- `tests/test-chaves.sh`: `aplicar wifi_pwr ligar` recusa e não escreve `auto`; boot com `wifi_pwr=1` grava 0 e
  escreve `on`.
