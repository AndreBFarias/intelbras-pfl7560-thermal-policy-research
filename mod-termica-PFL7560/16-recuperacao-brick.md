# 16 - Recuperação de brick (o método que não existe na net) + a lição do .bin

Data: 2026-07-06. Registro da noite em que o `PFL7560-FIX.bin` travou o boot e como recuperamos
**sem assistência, sem abrir o aparelho** — puramente pelo loader.

## 1. O que aconteceu

Flashamos o `PFL7560-FIX.bin` pela "Atualização local do sistema". O flash **completou** (formatou o
`/data`, gravou), mas o aparelho passou a **travar na logo do Android** a cada boot (2 tentativas, ~10 min
cada). O menu ficou inacessível (Android não sobe) → o caminho normal de recuperação (reflashar pelo menu)
**não funciona mais**.

## 2. Por que travou (diagnóstico)

**A CONFIG estava certa — o problema foi o metadado dos arquivos.** Pista decisiva: mesmo travado na logo,
**o brilho estava no máximo e as ventoinhas no talo**. Isso prova que a HAL térmica (`ZYThermalManager`) e o
driver de painel/LED subiram cedo e **aplicaram o nosso `ZYCustom.ini` com sucesso** — ou seja, os valores da
build funcionam. O boot travou **depois** disso, num estágio mais tardio do init.

Causa provável: ao reconstruir a partição vendor, os 3 arquivos foram reescritos via `debugfs write`, que
**não define o rótulo SELinux** (`security.selinux` xattr) nem preserva modo/owner exatos. No método `/vendor`
por adb, os arquivos mantêm o rótulo (o FS já tinha o contexto); no `.bin`, ficaram **sem rótulo**. Em algum
ponto do init isso trava o boot. (O método `/vendor` por adb nunca teve esse problema — por isso ele sempre
funcionou.)

> **Lição para um `.bin` futuro seguro:** depois de escrever cada arquivo no ext4, **setar o contexto SELinux
> e o modo/owner corretos** (via `debugfs -R "ea_set <arq> security.selinux <contexto>"` + `sif ... mode/uid`),
> copiando os do arquivo stock original. Sem isso, o `.bin` embutido brica. **Enquanto isso não for feito e
> testado, NÃO use o `PFL7560-FIX.bin`.** Use o método `/vendor` (autorun/adb), que é seguro.

## 3. A RECUPERAÇÃO — power-hold + `usb_update.bin` (FUNCIONA)

O bootloader HiSilicon tem um **modo de upgrade USB próprio**, independente do Android. Revertendo o loader
(partição rec2 do `.bin`, funções `usb_check_device()` → `usb_check_file(...)`) achamos que ele procura um
arquivo de nome fixo — a constante `USB_UPDATE_FILE_NAME` = **`usb_update.bin`** — numa porta USB. Mas ele só
faz esse check em **modo upgrade**, que o OS normalmente ativa. Sem o OS, o gatilho é **por hardware: ligar
segurando o botão de power.**

### Passo a passo (testado e aprovado)

1. Num pendrive **FAT32 MBR**, ponha na raiz o firmware **de fábrica** renomeado para **`usb_update.bin`**.
   (Pode ter outros arquivos junto; o loader procura por esse nome.)
2. **Tire o cabo de energia** do projetor (desliga total — o botão não desliga com o Android travado).
3. Plugue o pendrive numa **porta USB** do projetor.
4. **Pressione e SEGURE o botão de power** e, segurando, **plugue a energia de volta.** Continue segurando
   **~10-15 s**.
5. O loader entra em modo upgrade, acha o `usb_update.bin` e **regrava o firmware** (aparece tela de
   progresso, não a logo do Android). **Não desligue durante a gravação.**
6. Ao terminar e reiniciar, **remova o pendrive** (pra não regravar de novo). Sobe no firmware de fábrica.

Por que funciona: o flash **só toca as partições do firmware**, e o **bootloader/loader nunca é alterado**
(nem pela nossa build, nem pelo flash) — então o modo de upgrade USB está sempre disponível. É o mesmo motor
que a "Atualização local" usa, só que disparado pelo hardware em vez do menu.

## 4. Plano B — recuperação por UART/serial (se o power-hold falhar)

O loader expõe um **console U-Boot na UART** (`baudrate=115200`, 8N1). Com um adaptador USB-TTL (CH340/CP2102,
~R$10) nos pinos de serial da placa (abrir o aparelho), dá pra interromper o boot e recuperar na mão:

```
usb start
fatload usb 0 0x<addr> usb_update.bin      # carrega o firmware do pendrive p/ a RAM
# e então disparar o upgrade / mmc write conforme o fluxo do loader
```
Comandos disponíveis no console: `usb start`, `fatload`, `mmc read/write/erase`, `erase`, `reset`, etc.
(Pinout exato da UART: identificar TX/RX/GND na placa — 3 pads/pinos perto do SoC; TX do adaptador → RX da
placa e vice-versa, GND comum, **não** ligar VCC.) Método que a própria assistência usaria (HiTool/UART).

## 5. Resumo (a regra de ouro atualizada)

- **Aplicar a correção:** método `/vendor` (autorun `newlink_update.sh` ou `pfl7560-fix.sh`). **Seguro, nunca
  bricou.**
- **`PFL7560-FIX.bin`:** só depois de corrigir os rótulos SELinux e **testar**. Por ora, **não usar**.
- **Recuperar de qualquer brick:** `usb_update.bin` (stock) na raiz + **power-hold ao ligar**. Sempre
  disponível porque o bootloader é intocável.
- **Último caso:** UART 115200 (console U-Boot).
