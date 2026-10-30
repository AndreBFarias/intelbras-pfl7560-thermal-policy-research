# Bloco 5 - kit universal de pendrive: térmica + cor, idempotente, para leigo (2026-10-29)

Substitui a T1.1 do bloco 1. Desenho e evidências no
[doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md). Arquivos: `pendrive-autorun/`
(ASCII puro, byte-exatos), padrões PNG novos, harness de teste em `tests/`.

## E1 - Roteiro de confirmação no aparelho (só leitura, precisa do projetor na rede)

(a) `cat /proc/msp/panel`: `lvds_fmt vesa`, `cut_idx 69`.
(b) `dd` da `panelparam` para `/data/local/tmp/pp-now.img`, `pull`, e
`cmp -l private/panelparam-2026-10-29-antes-swap.img pp-now.img`: esperado **uma** linha (`53253 1 0`),
provando que a API grava só o byte `0x5c`, sem checksum, o que libera o plano B por `dd`.
(c) `ls -la /data/local/nlsu`: esperado inexistente.
(d) `getevent -ql` apertando OK, setas e Voltar: dispositivo e códigos das teclas.
(e) PNG em `/data/local/tmp/kit/` aberto pela galeria com `am start ... VIEW`.
(f) Câmera: `ls -l /dev/video*`; `readlink /sys/class/video4linux/*/device/driver` terminando em
`uvcvideo`; `getprop | grep -iE 'camera|focus'`.
(g) `md5sum /vendor/etc/ZYCustom.ini`; `ls -l /atv/ini/`.
Prova: saídas coladas no doc 41.

## E2 - Padrões e matemática (offline)

PNG 1920x1080: metades 63|64 em cima, 127|128 embaixo; textos só em branco/preto puros; telas
PRONTO/ERRO/AGUARDE. Prova: `python3 -I` simula as duas rotações e mostra |L−R|/(L+R) < 0,01 no certo
e > 0,6 nos dois errados.

## E3 - Script do kit (offline, com stubs)

`newlink_update.sh` v2 (ASCII) + `cor.sh` separado: térmica por md5, cor destacada do `exec` do init,
journal, gancho de recuperação, plano B por `dd`. Harness com stubs de `getprop`/`dd`/`getevent`/`am`/
`lvdsctl` cobrindo: sem tecla = nenhuma escrita; tecla + timeout = reverte; tecla + tecla = grava e relê;
journal no boot = restaura; md5 de `.ini` desconhecido = recusa; `/atv/ini` = avisa; 2ª execução = nada;
arquivo do kit adulterado = aborta antes de escrever. `grep -P '[^\x00-\x7F]'` vazio.

## E4 - Bancada no aparelho (painel atual, VESA)

md5 da `panelparam` antes e depois de cada braço: (1) sem tecla: idêntico; (2) tecla + timeout: vai a
JEIDA, volta a VESA, idêntico; (3) tecla e tirar da tomada na 2ª tela: o gancho restaura no boot;
(4) repetir (1) com sala acesa e lente desfocada. **Requer pendrive FAT32.**

## E5 - Câmera (portão do modo automático)

Instalar o NDK (o mesmo do `lvdsctl`, r27, `armv7a-linux-androideabi24-clang`). Compilar `nl_camcheck`
(só `QUERYCAP`/`ENUM_FMT`/`STREAMON`/`DQBUF`): luma média das metades em N quadros. Portão: em 3
distâncias, sala clara e escura, m(certo) < 0,1, m(errado) > 0,4 e razão > 4. Só então a bandeira do
modo automático liga (desligada por padrão).

## E6 - Prova de leigo

Uma terceira pessoa, só com o LEIA-ME novo, num PFL7560 de fábrica (e num com painel trocado, se houver):
termina em até 5 passos sem perguntar nada; o md5 da `panelparam` só muda onde o formato estava errado.
