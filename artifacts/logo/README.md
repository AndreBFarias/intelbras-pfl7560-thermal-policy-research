# nl_logo - logo do boot regerado no aparelho (bloco 25)

Programa ARM (32 bits, NDK r27c) que faz no projetor a mesma conta do `artifacts/tema/gerar-marca.py`:
distorce a arte reta do logo (`artifacts/tema/marca/logo.jpg`, 1920x1080) pelos 4 cantos da correção de
4 pontos (`persist.sys.keystone.lt/rt/lb/rb`), com o bicúbico do Pillow e fundo preto, e grava JPEG qualidade 95,
4:4:4. Também confere e monta a partição `logo` (`LOGO_TABLE`, JPEG no byte 8192, `LOGO_KEY_LEN` em 0x78), como o
`pfl7560-marca.sh` faz no PC. Quem chama é o `pendrive-autorun/suite-logo.sh` (doc 44 §18).

Fonte: `nl_logo.c` (C, um arquivo) + `terceiros/stb_image.h` (v2.30, só o decodificador JPEG) e
`terceiros/stb_image_write.h` (v1.16), de `nothings/stb`, domínio público ou MIT, sem alteração (só um bloco de
origem no topo). Binário do aparelho: `nl_logo` (esta pasta) e a mesma cópia em `pendrive-autorun/nl_logo` (md5 na
`KIT_LISTA` e no bloco `LOGO_MD5` do `suite-logo.sh`).

## Compilar

    # aparelho (ARM): so libc, libm e libdl do Android. Da RAIZ do repositorio
    ~/Android/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang \
        -O2 -Wall -ffp-contract=off -o artifacts/logo/nl_logo artifacts/logo/nl_logo.c -lm
    cp artifacts/logo/nl_logo pendrive-autorun/nl_logo
    bash tests/atualizar-md5-kit.sh      # regrava NL_LOGO_MD5, LOGO_MD5 e a KIT_LISTA

    # PC (harness): o MESMO .c
    cc -O2 -Wall -Wextra -ffp-contract=off -o nl_logo artifacts/logo/nl_logo.c -lm

`-ffp-contract=off` é obrigatório nos dois: sem ele o clang funde multiplicação e soma (FMA) e a conta da
perspectiva sai diferente da do Python em alguns pixels. `STBI_NO_SIMD` pelo mesmo motivo (o IDCT em SIMD do ARM
e o do PC não dão os mesmos bytes). A compilação é reprodutível; o `tests/test-logo.sh` recompila com o NDK, se
houver, e exige o binário versionado.

## Uso

    nl_logo cantos <lt> <rt> <lb> <rb>
    nl_logo gerar <arte.jpg|entrada.ppm> <lt> <rt> <lb> <rb> <saida.jpg|saida.ppm>
    nl_logo cabecalho <particao.img>
    nl_logo extrair <particao.img> <saida.jpg>
    nl_logo montar <base.img> <novo.jpg> <saida.img> <keylen.bin>

Cada canto é `x,y` em pixels, como nas props (y para cima: `lt` reto é `0,1080`). Sai 0 ok; 1 erro; 2 uso errado;
3 recusa. Em erro ou recusa não deixa arquivo de saída.

| modo | o que faz |
| --- | --- |
| `cantos` | imprime `ok` ou o motivo da recusa (sai 3): `formato`, `fora_da_tela`, `nao_convexo`, `canto_trocado`, `area_pequena` |
| `gerar` | confere os cantos, lê a arte (JPEG pelo `stb_image`, ou PPM `P6 1920 1080 255` exato, para o teste) e escreve o JPEG (ou PPM cru). Cantos retos com arte JPEG = cópia byte a byte da arte |
| `cabecalho` | confere a partição: 41943040 bytes, os 120 bytes conhecidos do `LOGO_TABLE`, zeros até o 8192, `LOGO_KEY_LEN` entre 4 e o resto da partição, `FFD8` no 8192 e `FFD9` no fim; imprime o `LOGO_KEY_LEN` |
| `extrair` | `cabecalho` e copia o JPEG |
| `montar` | copia a base trocando só o JPEG no 8192 e o `LOGO_KEY_LEN`, escreve o `keylen.bin` (4 bytes LE) e confere a saída com o `cabecalho` |

Decisões:

- **Recusas dos cantos.** Quadrilátero convexo (os 4 produtos vetoriais de lt→rt→rb→lb com o mesmo sinal), cada
  canto no seu quadrante em volta do centro da tela (um canto trocado com outro também forma um convexo, mas
  espelha a imagem), dentro de 0..1920 x 0..1080 e área de pelo menos 25 % da tela. PROVISÓRIO: a regra do
  quadrante e os 25 % são escolha desta implementação, não medição.
- **A conta é a do Pillow.** Coeficientes por Gauss-Jordan 8x8 com pivô parcial (o primeiro máximo, como o
  `gerar-marca.py`), centro do pixel em (x+0,5, y+0,5) e o `bicubic_filter32RGB` do Pillow (a = -1, recorte e
  truncamento iguais). A saída crua é idêntica byte a byte à do `gerar-marca.py` (provado em 5 conjuntos de
  cantos); o JPEG difere só pelo codificador (média de 0,03 por canal, máximo 15).
- **Cabeçalho do JPEG igual ao do Pillow.** O `stb_image_write` junta as 2 tabelas de quantização num DQT e as 4
  de Huffman num DHT; o Pillow escreve um segmento por tabela, o arranjo que o carregador já leu. As tabelas são
  as mesmas (q95, Huffman padrão); o `separar_tabelas` reescreve o cabeçalho com um segmento por tabela. Do SOI ao
  SOS o JPEG do `nl_logo` é byte a byte o do `gerar-marca.py` (o `test-logo.sh` confere).
- **`MAX_JPEG` de 256 KiB.** O JPEG gerado tem 86 a 100 KiB; acima disso algo saiu errado e o `gerar` recusa.
  PROVISÓRIO: o limite do que o bootloader lê não foi medido; os dois logos reais tinham 44 e 95 KB.
- **`MAX_ENTRADA` de 8 MiB** para a arte e para o JPEG extraído da partição.
