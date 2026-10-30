# 10 - Guia de replicação (outros donos do PFL7560)

Aplica a correção térmica em qualquer **PFL7560** com firmware de fábrica **V1.0.0.9** (com USB-C) ou
**V1.0.0.1** (sem USB-C, fabricado a partir de 25/08/2026; neste, só provado em simulação). O bug do mux é o
mesmo nos dois ([doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md)).
Métodos por `/vendor` são **reversíveis** e **não tocam no bootloader**.

> **O que a correção faz:** ativa o 2º sensor de temperatura (desligado por defeito de configuração de fábrica),
> força os fans a 100% sempre, mantém o brilho estável em 100% e define desligamento de proteção a 75 °C.
> Resultado medido: saída de ar de 46,7 °C → 37,2 °C.

**Caminho recomendado para leigos:** use o **pendrive autorun** ou o script da raiz — veja [`../../INSTALL.md`](../../INSTALL.md).

## Método A — script `pfl7560-fix.sh` (adb)

```bash
PFL_IP=<ip> ./pfl7560-fix.sh status
PFL_IP=<ip> ./pfl7560-fix.sh apply
```

Validação esperada após reboot: fans 1000/1000; `gtt 1` bem acima de `gtt 0` (ex.: ~55–61 °C vs ~26 °C).

## Método B — pendrive autorun

Copie o kit v2 **completo** para a raiz de um FAT32 com `./install.sh --pendrive /caminho/do/pendrive`
(Windows: `install.bat`, opção 5), que confere o md5 de cada arquivo depois da cópia; plugue com o projetor
desligado e ligue. O mesmo pendrive serve a qualquer PFL7560 (sem serial, sem arquivo para editar) e
também faz o teste de cor das "duas metades". Passo a passo: [`../../INSTALL.md`](../../INSTALL.md) e
`pendrive-autorun/LEIA-ME.txt`.

## Método C — `.bin` completo

**EM QUARENTENA — NÃO USE.** Um protótipo travou o boot. Detalhes: [`16-recuperacao-brick.md`](16-recuperacao-brick.md)
e [`../research/15-bin-definitivo.md`](../research/15-bin-definitivo.md).

## Nota histórica (`/atv/ini`)

Houve um deploy experimental por override em `/atv/ini/ZYCustom_*.ini`. Foi **superado** pela edição direta de
`/vendor` (permanente e alinhada ao script/pendrive). Não use `/atv` em instalações novas.

## Reverter

```bash
PFL_IP=<ip> ./pfl7560-fix.sh revert
```

Ou reflash do firmware de fábrica (menu “Atualização local do sistema”). Segurança: [`12-seguranca-e-recuperacao.md`](12-seguranca-e-recuperacao.md).
