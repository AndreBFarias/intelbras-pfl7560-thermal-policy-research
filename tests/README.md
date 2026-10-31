# tests/ — provas no PC

Nada aqui fala com o projetor nem com a câmera: os scripts do kit e do PC rodam contra uma árvore de mentira
(`PFL_ROOT`) e comandos de mentira no `PATH` (`adb`, `getprop`, `am`, `lsblk`, `mkfs.vfat` e afins). Precisa de
`bash`, `python3`, `md5sum`, `zip`/`unzip` e um compilador C (`cc`). Rode da raiz do repositório.

## Os quatro alvos

| Alvo | Roda | O que prova | Precisa de |
|---|---|---|---|
| `make check` | `check-stock-md5.sh` | os 9 md5 de contrato: os arquivos de fábrica e a correção dos dois modelos em `artifacts/`, a cópia do kit e o `CONFIG_B64` do `pfl7560-fix.sh`, contra as constantes do próprio `pfl7560-fix.sh` (lidas por `grep`, nunca redigitadas) | — |
| `make check-kit` | os 10 passos abaixo | o kit do pendrive, a suíte, as telas, a câmera e os scripts do PC | `cc`; o NDK r27c é opcional (com ele, o binário ARM é recompilado e comparado) |
| `make check-fix` | `test-fix-modelo.sh` | o `pfl7560-fix.sh apply/revert` nos dois modelos, com um `adb` de mentira | — |
| `make check-bin` | `test-builder-bin.py` | o gerador do `.bin` em containers sintéticos pequenos: offset do vendor lido da tabela, sparse só RAW/DONTCARE, os dois modos (nos mesmos blocos e `--realocar`), o manifesto `--conteudo` e as recusas, o `verificar_bin` | `e2fsprogs` (`mke2fs`, `debugfs`, `e2fsck`). Opcional: `PFL_STOCK_ANTIGO=<PFL7560.bin V1.0.0.9>` e `PFL_STOCK_NOVO=<PFL7560.bin V1.0.0.1>` rodam também com os stocks reais (só leitura, 1,3 GB cada, alguns minutos) |

`make check-kit`, na ordem:

| Passo | Prova |
|---|---|
| `simula-padroes-kit.py` | as telas de diagnóstico de cor (`kit/*.png`) sobrevivem ao formato errado só em 0/255 e cinzas |
| `test-camcheck.sh` | o `nl_camcheck` do PC (o mesmo `.c` do ARM) sobre os quadros reais de `fixtures/camera/`, e um driver de mentira para os limites de buffer |
| `test-tela.sh` | o `nl_tela` gera os exemplos de `fixtures/tela/` (1920x1080, nada fora das margens), entradas inválidas, fontes de reserva; saída para olhar em `tests/saida/telas/` (fora do git) |
| `atualizar-md5-kit.sh --check` | as listas de md5 embutidas no kit estão em dia |
| `test-kit-pendrive.sh` | `newlink_update.sh` e `cor.sh` reais: térmica, cor, app, home, sobreposições, marca, desinstalar, instaladores |
| `test-suite.sh` | `suite.sh`, `suite-boot.sh` e `suite-pedido.sh` reais: gatilhos, etapas, vigia, descanso, luz, resumo |
| `test-preparar-pendrive.sh` | `install.sh --pendrive [--com-firmware]` e `preparar-pendrive.sh` com discos de mentira e `.bin` falsos pequenos |
| `test-processos.sh` | `pfl7560-processos.sh` com uma saída de `top` gravada (`fixtures/processos/`) |
| `test-pc-marca-vlc.sh` | `pfl7560-marca.sh` e `pfl7560-vlc.sh` (a partição `logo` vira um arquivo) |
| `test-qualidade.sh` | `pfl7560-qualidade.sh` (os ajustes de imagem num arquivo) |

Os testes imprimem `N verificacoes, 0 falha(s)` (o `make check` imprime `integridade OK`) e saem diferente de 0
se algo falhar. As contagens atuais estão em
[`docs/ESTADO.md`](../docs/ESTADO.md).

## Ferramentas que não são teste

- **`atualizar-md5-kit.sh`**: o **único** jeito de regravar as listas de md5 embutidas no kit (`SUITE_LISTA` no
  `suite.sh`, o md5 do `suite.sh` no `suite-boot.sh` e no `suite-pedido.sh`, `KIT_LISTA` e `KIT_OVERLAYS` no
  `newlink_update.sh`), nessa ordem, porque cada uma depende da anterior. Também copia para o kit os APKs de
  `artifacts/overlay/apk/` e a marca de `artifacts/tema/marca/`, e exige que `lvdsctl`, `nl_camcheck`, `nl_tela` e
  os APKs do kit sejam iguais aos de `artifacts/`. `--check` só confere.
- **`preparar-pendrive.sh`**: **formata** um pendrive (`sudo`) e roda o `install.sh --pendrive ... --com-firmware`.
  Só aceita disco removível por USB e pede para digitar o caminho do dispositivo. Confira o dispositivo duas vezes.
- **`gerar-padroes-kit.py`**: gera as telas de diagnóstico de cor (`pendrive-autorun/kit/*.png`).

## Fixtures

| Pasta | O que tem |
|---|---|
| `fixtures/camera/` | quadros crus YUYV da câmera interna (2026-10-30, painel da 3ª troca): calibração e escada, 640x480 e 1280x720, nos dois formatos (`-f0` VESA, `-f1` JEIDA) |
| `fixtures/processos/` | saída de `top` do Android 9 do aparelho |
| `fixtures/tela/` | os `campos.txt` de exemplo de cada tela da suíte, mais casos de estresse |
