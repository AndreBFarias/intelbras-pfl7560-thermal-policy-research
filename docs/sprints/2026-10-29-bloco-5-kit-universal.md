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
(e) PNG em `/data/local/tmp/kit/` aberto pela galeria com `am start ... VIEW`. **Este item decide a
OPT-S13:** em 2026-09-03 essa via abriu a galeria com tela preta
([doc 39](../research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3), e o `cor.sh` mostra as telas
do teste de cor por ela.
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

## E3b - Endurecimento de segurança (revisão automática de 2026-10-29)

A revisão de segurança dos commits do E3 apontou, em `pendrive-autorun/cor.sh`:
1. **ALTO:** o kit e o gancho de boot executam como root `cor.sh` a partir de `/data/local/tmp/pfl7560-kit`,
   pasta gravável pelo usuário `shell` (escalada de privilégio shell→root).
2. **ALTO:** `lvdsctl` é executado como root sem conferência de md5 no momento do uso.
3. **MÉDIO:** `dd` de backup/restauração numa pasta gravável por outros permite desvio por link simbólico.

Cura: pasta de trabalho só do root (ex.: `/data/vendor/pfl7560-kit`, `0700 root:root`), criada e
verificada a cada uso (diretório real, não link; dono root); recusar qualquer arquivo nela que seja link
ou de outro dono; conferir o md5 embutido de `cor.sh` e `lvdsctl` **imediatamente antes de cada execução**
(fluxo normal, `--restaurar` e gancho); guardar o md5 do backup no journal e conferir antes de restaurar.
Prova: casos novos no harness (pasta com link, arquivo trocado depois da cópia, backup adulterado), todos
abortando sem escrever na `panelparam`.

## E2b - Padrão com vários pares (achado de 2026-10-30)

> **Substituída pelo [bloco 7](2026-10-30-bloco-7-cor-automatica.md) (C2).** Medido depois: nem 7 pares
> dividem no formato errado. Em vez de pares, o kit usa uma escada de 16 cinzas (ordem de brilho).

- **Medido:** em VESA errado, a faixa 63|64 saiu uniforme (ciano) e só a 127|128 dividiu (doc 41 §8).
- **Causa:** gamma/DCI/balanço de branco mudam o valor antes do LVDS; um par só não garante cair numa
  fronteira de bit da saída.
- **Cura:** `metades-1`/`metades-2` com 4 a 6 pares em níveis diferentes (ex.: 31|32, 63|64, 95|96,
  127|128, 159|160, 191|192); a pergunta continua "alguma faixa tem metades diferentes?".
- **Prova:** no aparelho, em cada formato, pela câmera e pela foto: no errado pelo menos 2 faixas dividem;
  no certo nenhuma. Simulação em `tests/` com a curva de saída medida.

## E3d - Troca de tela no kit (achado de 2026-10-30)

> **Feita em código no [bloco 7](2026-10-30-bloco-7-cor-automatica.md) (C3);** a prova no aparelho é do
> coordenador.

- **Medido:** um 2º `am start ... VIEW` com a galeria aberta não troca a imagem
  (`com.hisilicon.higallery`, "delivered to currently running top-most instance"); `am start -S` falha
  ("does not match any activities"); `am force-stop com.hisilicon.higallery` antes resolve.
- **Cura:** `mostrar()` do `cor.sh` faz `force-stop` do pacote que resolve o VIEW antes de cada tela;
  atualizar o md5 embutido no `newlink_update.sh` e o harness (stub de `am` passa a exigir o
  `force-stop`).
- **Prova:** `make check-kit` verde e, no aparelho, a sequência `aguarde` → `metades-1` → `metades-2`
  conferida pela câmera.

## E4 - Bancada no aparelho (painel atual: JEIDA desde 2026-10-30; os braços que iam a JEIDA e voltavam passam a ir a VESA e voltar)

md5 da `panelparam` antes e depois de cada braço: (1) sem tecla: idêntico; (2) tecla + timeout: vai a
JEIDA, volta a VESA, idêntico; (3) tecla e tirar da tomada na 2ª tela: o gancho restaura no boot;
(4) repetir (1) com sala acesa e lente desfocada. **Requer pendrive FAT32.**

## E5 - Câmera (portão do modo automático)

> **Substituída pelo [bloco 7](2026-10-30-bloco-7-cor-automatica.md) (C1 a C4).** O critério deixou de ser
> a razão das metades: o `nl_camcheck` mede a ordem de brilho da escada (`faixas` e `niveis`) e o modo
> automático liga por padrão. Falta só a prova no aparelho (coordenador).

Instalar o NDK (o mesmo do `lvdsctl`, r27, `armv7a-linux-androideabi24-clang`). Compilar `nl_camcheck`
(só `QUERYCAP`/`ENUM_FMT`/`STREAMON`/`DQBUF`): luma média das metades em N quadros. Portão: em 3
distâncias, sala clara e escura, m(certo) < 0,1, m(errado) > 0,4 e razão > 4. Só então a bandeira do
modo automático liga (desligada por padrão).

## E6 - Prova de leigo

Uma terceira pessoa, só com o LEIA-ME novo, num PFL7560 de fábrica (e num com painel trocado, se houver):
termina em até 5 passos sem perguntar nada; o md5 da `panelparam` só muda onde o formato estava errado.

## Estado (2026-10-30)

| Etapa | Estado |
|---|---|
| E1 (roteiro no aparelho) | **PARCIAL (2026-10-30)** — (a), (b), (e) e (f) feitos ([doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md) §8); (g) também (`ZYCustom.ini` `252ab7a7`, `/atv/ini` sem `ZYCustom`); faltam (c) e (d) |
| E2 (padrões e matemática) | **FEITA** (`d49f2f7`) |
| E2b (vários pares) | **SUBSTITUÍDA** pelo bloco 7 (C2): escada de 16 cinzas, **feita em código** (`make check-kit`) |
| E3 (script do kit) | **FEITA** (`5c68064` e correções seguintes), provada só em simulação (`make check-kit`) |
| E3b (endurecimento) | **FEITA** (`a9e7832`, `c5b63da`, `a771cdc`) |
| E3c (instaladores copiam o kit v2 e conferem o md5) | **FEITA** (`3c7682b`): `install.sh --pendrive` provado no harness; a opção 5 do `install.bat` só **conferida por texto** (não há cmd.exe aqui) |
| E3d (troca de tela com `force-stop`) | **FEITA em código** (bloco 7, C3), harness exige o `force-stop` antes de cada `am start`; **pendente no aparelho** (conferir a sequência pela câmera) |
| E4 (bancada no aparelho) | **ABERTA** — requer pendrive FAT32 |
| E5 (câmera) | **SUBSTITUÍDA** pelo bloco 7 (C1 a C4): `nl_camcheck faixas/niveis` provado sobre quadros reais no PC; modo automático ligado por padrão no `cor.sh`, provado com stubs; **pendente no aparelho** (coordenador: `cor.sh` real a partir de JEIDA e de VESA, `cmp -l` e câmera) |
| E6 (prova de leigo) | **ABERTA** |

O bloco 6 estendeu o kit aos dois modelos (V1.0.0.9 e V1.0.0.1 sem USB-C), também só em simulação.
