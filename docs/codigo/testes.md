# Notas do código: testes (`tests/`)

O porquê do desenho dos harnesses. Os alvos do `make`, o que cada teste prova e as fixtures:
[`tests/README.md`](../../tests/README.md). Mapa geral: [`../MAPA.md`](../MAPA.md).

## Regras comuns

- **Nada fala com o projetor.** Os scripts reais rodam contra uma árvore de mentira (`PFL_ROOT`) e stubs num `PATH`
  temporário; os ganchos `PFL_*` só valem com `PFL_TESTE=1`, e o dono exigido nas pastas é o usuário que roda o
  harness (no aparelho é o root).
- **`afirma` avalia a condição depois, com `eval`:** por isso as condições vão entre aspas simples e as variáveis
  usadas só dentro delas levam `# shellcheck disable=SC2034`. O `afirma` usa `$1`: nada de parâmetros posicionais
  nas funções de caso.
- **dash, não busybox:** os cenários do kit e da suíte rodam sob `dash` (POSIX estrito; o mksh do Android 9 não está
  na máquina). O busybox `ash` só entra no `sh -n`: ele embute `mount`, `sleep` e `reboot` como applets, que passam
  por cima dos stubs.

## `atualizar-md5-kit.sh`

- Ordem fixa, cada lista depende da anterior: 0) regrava `pendrive-autorun/overlay/` (uma cópia de cada APK de
  `artifacts/overlay/apk/`, sem lista fixa: um APK novo entra sozinho) e `pendrive-autorun/marca/`; 1)
  `SUITE_LISTA` no `suite.sh`; 2) o md5 do `suite.sh` novo no `suite-boot.sh` e no `suite-pedido.sh` (e o do
  `suite-pedido.sh` no `suite-boot.sh`); 3) `KIT_OVERLAYS` (a do `android` sempre por último) e `KIT_LISTA` no
  `newlink_update.sh`.
- Troca só o miolo entre as linhas `# NOME_INICIO` e `# NOME_FIM`. `LC_ALL=C` para a ordem do glob ser igual em
  qualquer máquina. Grava com `cat` para preservar modo e atributos.
- Exige `lvdsctl` (md5 `178d8128…`), `nl_camcheck`, `nl_tela` e os APKs do kit iguais aos de `artifacts/`.

## `check-stock-md5.sh` (`make check`)

- Lê as constantes do próprio `pfl7560-fix.sh` com `grep`, nunca redigitadas, para o teste não envelhecer. O
  extrator corta na aspa de fechamento porque o `CONFIG_B64` termina em `=` (padding) logo antes dela, e um `sed`
  guloso comeria o valor todo.

## `test-kit-pendrive.sh` e `test-suite.sh`

- O `nl_camcheck` de mentira lê o byte `lvds_fmt` da `panelparam` de mentira e devolve a escada em ordem ou
  embaralhada; o de verdade é provado à parte (`test-camcheck.sh`). O `lvdsctl` de mentira persiste o byte como o
  `SetLvdsFormat` real.
- Byte `lvdsctl_fmt` do perfil 69: `168 + 69 * 768 + 92` = 53252 (0-based; 53253 no `cmp -l`).
- A "queda de energia" mata só o `cor.sh` **deste** cenário (o caminho passa por `$T`): um `pkill` pelo nome
  matava o de outra rodada do harness na mesma máquina, que falhava sem motivo (bloco 19C). `/dev` é tmpfs: o lock
  some com a queda.
- O `md5sum` de mentira troca, uma vez, o `cor.sh` da pasta de trabalho depois da cópia conferida e antes de
  executar: prova que a conferência na hora pega.
- O `hidebug` de mentira registra argumentos **e** a entrada (o `gtt` chegaria por ela). Testes estáticos: nenhuma
  linha executável cita `gtt`; o override só como `71000` literal, nunca `75000`; nenhum `exit !(...)` (o `awk` do
  Android 9 recusa).
- O `install.bat` só é testado como texto (não há Windows aqui).

## `test-camcheck.sh` e `test-tela.sh`

- Rodam o `nl_camcheck` e o `nl_tela` do host (o mesmo `.c` do binário ARM) sobre os quadros reais de
  `tests/fixtures/camera/` (2026-10-30) e os exemplos do contrato C-tela. Valores medidos com a janela de 47 a 53 %
  (bloco 8), tolerância de 2.
- Com o NDK na máquina, recompilam o binário ARM e comparam com o versionado. Compile da raiz, com o caminho
  relativo, como no README: o `assert` da `stb_truetype` grava o caminho no binário.
- Quadros sintéticos de geometria conhecida (16 faixas 230 sobre 20, borda em rampa de R px com 10 a 90 % = 0,8 R,
  inclinação A, pilha T vezes mais alta na borda direita): com T = 1,1 nas janelas de 18 % e 82 %, a razão das
  alturas é 1,082/1,018 = +6,3 %.
- O driver de mentira (open/ioctl trocados no link) devolve mais buffers que o pedido, nenhum buffer, e a saída em
  `/dev/full` (gravação incompleta tem de dar erro).

## `test-builder-bin.py` (`make check-bin`)

- Containers LOAD sintéticos e pequenos (ext4 de 4 MiB com os 3 arquivos, empacotado em sparse, com o record 14 em
  offsets diferentes) e o gerador real contra eles. O layout do container é escrito no teste, de propósito, e não
  importado do gerador.
- Com os stocks de verdade (só leitura): `PFL_STOCK_ANTIGO` (V1.0.0.9) tem de sair com md5 `eae3a83d` e
  `PFL_STOCK_NOVO` (V1.0.0.1, com o `ZYCustom_390.NOTYPEC.ini`) com `0d294cb3`, CRC do vendor `0xe2cad2f5`.
- O manifesto é conferido por fora, com `debugfs`, entrada por entrada, e as recusas uma a uma.

## `preparar-pendrive.sh` e `test-preparar-pendrive.sh`

- Só aceita disco removível (`RM=1`) por USB (`TRAN=usb`), sem nada do sistema montado, informado como disco inteiro
  ou partição dele; mapeado (crypt, lvm), loop ou raid também têm pai, mas não são o pendrive que o `mkfs.vfat` deve
  apagar. Pede para digitar o caminho.
- As origens do firmware são conferidas **antes** de formatar (`install.sh --conferir-firmware`): sem isso um md5
  errado só apareceria com o pendrive já apagado.
- O teste usa `lsblk`, `mkfs.vfat`, `mount`, `umount` e `df` de mentira e `.bin` falsos pequenos; o firmware de
  verdade (1,3 GB) não é lido.

## `gerar-padroes-kit.py` e `simula-padroes-kit.py`

- VESA e JEIDA diferem por uma rotação de 2 bits igual em R, G e B. O pipeline de imagem (gamma, DCI, balanço de
  branco) muda os valores antes do LVDS, então "duas metades iguais" não é confiável; o que sempre aparece é a
  **ordem de brilho**. A escada: 16 faixas cinza, níveis `10 + 15k`, 34 px de altura, passo de 50 px a partir de
  y = 140, separadas por preto. A calibração tem as mesmas faixas em branco 255 sobre 0 (0 e 255 não mudam entre os
  formatos). Texto só em bandas de preto e branco puros, acima de y = 140 e a partir de y = 940.
- O md5 dos PNG depende da fonte instalada na máquina: os PNG versionados valem; o gerador existe para reproduzir.
- O simulador aplica as duas rotações e uma curva monótona aleatória (gamma 0,6 a 1,6, offset −10 a +10) e exige 0
  inversões no formato certo e no mínimo 3 no errado, com o critério do `nl_camcheck`.
