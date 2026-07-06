# bin-build - reconstruir o PFL7560.bin com a correção embutida

Gera um firmware `.bin` flashável com os fixes já no default, editando **apenas a partição vendor** e
mantendo o tamanho do payload — assim o `checksum1` do container continua válido e só o CRC da partição é
recalculado. Fundamentação completa em [`../../15-bin-definitivo.md`](../../15-bin-definitivo.md).

## Requisitos
- `python3`, `debugfs`, `e2fsck` (pacote e2fsprogs). Em Debian/Ubuntu/Pop!_OS: `sudo apt install e2fsprogs`.
- `sparse.py` (neste diretório) ao lado do script.

## Uso
```bash
python3 build_fix_bin.py  <stock_PFL7560.bin>  <ZYCustom.ini_modificado>  <saida.bin>
```
- `stock_PFL7560.bin` — firmware de fábrica V1.0.0.9 (extraia do `Software PFL7560.zip` oficial).
- `ZYCustom.ini_modificado` — o config da build (`../ZYCustom_390.ini`, md5 `1ad641ed`).
- `saida.bin` — o `.bin` corrigido.

O `build.prop` (`wifi_disconnect_on_boot=0`) e o `init.bigfish.rc` (`xiriservice disabled`) são derivados do
próprio stock dentro da imagem, então o script é robusto à versão exata do vendor.

## O que ele faz (resumo)
1. extrai o payload vendor (record 14, prefixo `@0x4b0b1d54`);
2. expande o Android sparse → ext4 raw;
3. troca os 3 arquivos via `debugfs` (mantendo a contagem de blocos);
4. reescreve só os blocos alterados no sparse original (patch in-place) → **tamanho idêntico**;
5. recalcula o CRC-32/MPEG-2 da partição e grava no prefixo;
6. confirma que o `checksum1 @0x04` ficou inalterado (`0x738ebd09`).

## Resultado esperado
`saida.bin` com md5 `f5ff89c95f6ff9e622a9097d14b0c222` (a partir do stock de referência). O build é
**byte-reproduzível** — o script fixa os timestamps dos inodes e do superbloco (`s_wtime`/`s_lastcheck`)
que o `debugfs`/`e2fsck` carimbariam com a hora atual, então rodar 2× dá o mesmo md5. Ele aborta se algum
bloco alterado cair fora de um chunk RAW (o que mudaria o tamanho) — nesse caso seria preciso um
re-empacotamento completo com atualização da tabela.

## Verificação / flash
Ver [`../../15-bin-definitivo.md`](../../15-bin-definitivo.md). Flashar é opcional e por sua conta e risco;
o `.bin` está verificado internamente mas não testado em hardware. Recuperação: o `.bin` de fábrica.
