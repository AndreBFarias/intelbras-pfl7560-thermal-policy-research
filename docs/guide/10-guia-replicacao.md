# 10 - Guia de replicação (outros donos do PFL7560)

Aplica a correção térmica em qualquer **PFL7560** com firmware **V1.0.0.9**.
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

Copie `pendrive-autorun/newlink_update.sh` + `pendrive-autorun/ZYCustom.ini` para a raiz de um FAT32,
plugue com o projetor desligado e ligue. Ver `pendrive-autorun/LEIA-ME.txt`.

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
