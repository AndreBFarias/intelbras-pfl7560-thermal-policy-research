# Bloco 7 - cor automática pela câmera, escada de cinzas e troca de tela (2026-10-30)

Pedido do dono, depois da 3ª troca de LCD ([doc 41](../research/41-auto-pareamento-camera-e-kit-universal.md) §8):
implementar o modo automático pela câmera, corrigir a troca de tela do kit e o padrão de teste.
Substitui as tarefas E2b, E3d e E5 do [bloco 5](2026-10-29-bloco-5-kit-universal.md).

## O que se mediu no aparelho (2026-10-30, painel da 3ª troca, JEIDA correto)

1. **Troca de tela (E3d):** com a galeria `com.hisilicon.higallery/.NetworkHiGallery` aberta, um 2º
   `am start -a android.intent.action.VIEW -d file:///sdcard/X.png -t image/png` responde "intent has been
   delivered to currently running top-most instance" e **a imagem não muda**. `am start -S` falha ("does
   not match any activities"). `am force-stop com.hisilicon.higallery` antes do `am start` resolve
   (provado pela câmera). O pacote sai de
   `cmd package resolve-activity --brief -a android.intent.action.VIEW -d file:///sdcard/X.png -t image/png`
   (última linha `com.hisilicon.higallery/.NetworkHiGallery`, rc 0).
2. **"Duas metades" não é confiável:** no formato errado, a tela `metades-1` dividiu só a faixa 127|128.
   Num padrão de 7 pares (31|32 … 223|224), **nenhuma** faixa dividiu. O pipeline de imagem (gamma, DCI,
   balanço de branco) muda os valores antes do LVDS. O que aparece sempre é que **a ordem de brilho das
   faixas embaralha** (zigue-zague), e o preto de fundo sobe.
3. **Escada (critério novo):** 16 faixas cinza, níveis `10 + 15k` (k = 0..15), cada uma com 34 px de
   altura e passo de 50 px a partir de y = 140, separadas por preto, largura total. Simulação com
   curva monótona aleatória (gamma 0,6 a 1,6, offset ±10) nos dois sentidos da rotação de 2 bits: o
   formato errado dá **no mínimo 3 inversões**; o certo dá 0.
4. **Localização sem depender do formato:** uma tela `calibracao` com faixas **brancas (255)** nas mesmas
   posições sobre preto (0). 0 e 255 não mudam entre VESA e JEIDA.
5. **Câmera:** `/dev/video0`, uvcvideo, YUYV e MJPG em 1280x720/640x480/640x360. O quadro sai girado 180°
   e só luma. Sem controle de exposição (só brilho, contraste, saturação, matiz, WB auto, gamma). Topo da
   escada satura em 235 na câmera.
6. **Fixtures reais em `tests/fixtures/camera/`** (YUYV 640x480, 614400 bytes, `grab ... 15` quadros
   descartados): `calibracao-f1.yuyv`, `escada-f1.yuyv` (JEIDA, certo), `calibracao-f0.yuyv`,
   `escada-f0.yuyv` (VESA, errado), e os dois PNG projetados (`calibracao.png`, `escada.png`, sem texto).
   Protótipo em Python sobre elas (perfil de linhas nas colunas 35 a 65 % da largura; limiar no meio de
   min e max; trechos acima do limiar = faixas; média do miolo de cada faixa, sem 1/4 de cada borda;
   inversão = queda maior que 3 % da amplitude):
   - JEIDA: 16 faixas; `235 235 235 235 235 232 222 210 197 181 164 141 114 91 72 63`;
     inversões (crescente, decrescente) = (10, 0): **monótona**.
   - VESA: 16 faixas; `235 235 235 231 192 148 105 86 220 212 156 90 185 116 195 128`; (9, 3):
     **fora de ordem**.

## Cura

### C1 - `nl_camcheck` ganha a análise (C, `artifacts/camcheck/nl_camcheck.c`)

- `faixas <dev> <N> <saida.txt> [skip]`: captura **um quadro YUYV** (640x480; se não houver, o menor
  tamanho YUYV listado), faz o perfil de linhas como no protótipo e exige **exatamente N** trechos. Grava
  uma linha `ini fim` por faixa. Sai com 0 se achou N e com 3 se não achou (imprime quantos achou).
- `niveis <dev> <faixas.txt> [skip]`: captura um quadro e imprime a média do miolo de cada faixa, uma por
  linha. Na última linha imprime `inv_cresc=X inv_decresc=Y` (margem de 3 % da amplitude).
- Modo arquivo para teste: no lugar de `<dev>`, `arquivo:<caminho.yuyv>:<L>:<A>` lê o quadro do disco,
  sem V4L2. O mesmo `.c` compila no PC (`cc`) para o harness e no NDK r27c para o aparelho
  (`~/Android/android-ndk-r27c`, `armv7a-linux-androideabi24-clang`, como o binário atual).
- Continua só leitura no V4L2 (sem `S_CTRL`). `info` e `grab` não mudam de comportamento.

### C2 - Padrões novos (`tests/gerar-padroes-kit.py`, `pendrive-autorun/kit/`)

- `calibracao.png`: só as 16 faixas brancas, sem texto.
- `escada-1.png` e `escada-2.png`: a escada da geometria acima. Texto só em branco/preto puros, nas bandas
  de cima (y < 140) e de baixo (y ≥ 940). Mantém a semântica das telas de hoje: na 1, "a escada vai do
  escuro ao claro em ordem, sem faixa fora do lugar e sem cor? SIM: não faça nada. NÃO: aperte qualquer
  tecla"; na 2, a mesma pergunta com "SIM, agora em ordem: aperte qualquer tecla para manter; sem tecla em
  30 s volta ao anterior". Texto ASCII se a fonte exigir, com o sentido igual.
- `corrigida.png`: "COR CORRIGIDA AUTOMATICAMENTE. Se a imagem piorou, aperte qualquer tecla em 30 s
  para desfazer."
- `metades-1.png` e `metades-2.png` saem do kit e das listas de md5.
- `tests/simula-padroes-kit.py` passa a conferir a escada: nos dois sentidos de rotação, com a curva
  aleatória, mínimo de 3 inversões no errado e 0 no certo.

### C3 - `cor.sh`

1. `mostrar()`: antes de cada `am start`, `am force-stop` do pacote que o
   `cmd package resolve-activity --brief` devolve para o VIEW de PNG. Se não resolver, usa
   `com.hisilicon.higallery`. Depois do `am start`, espera `TEMPO_TELA` (3 s) antes de seguir.
2. **Modo automático, ligado por padrão** (`MODO_AUTO=1`). Desliga por `PFL_TESTE=1 PFL_MODO_AUTO=0`, na
   mesma regra dos outros overrides. `decidir_por_camera` implementado:
   - pré-condições: `$WORK/nl_camcheck` conferido por md5 **imediatamente antes de cada execução** (como
     o `lvdsctl`) e `/dev/video0` existente. Senão, cai no fluxo manual.
   - `mostrar calibracao`, `nl_camcheck faixas /dev/video0 16 $WORK/faixas.txt 15`. Se não achar 16,
     cai no manual.
   - `mostrar escada-1` e `niveis`. Se for monótona (`min(inv_cresc, inv_decresc) = 0`): o formato está
     certo, **nada é escrito**, e o kit termina em `pronto`. É o caminho idempotente.
   - Se `min ≥ 2`: backup, journal e gancho como hoje; `aplicar_vivo NOVO`; confere o byte; `mostrar
     escada-1` de novo (força a galeria) e `niveis`. Se agora `min = 0`: `mostrar corrigida`; tecla em
     `TEMPO_TECLA` desfaz (reverte e termina); sem tecla, confere com `particao_so_difere_no_fmt`, apaga o
     journal, remove o gancho e termina em `pronto`. Se não ficou monótona: reverte e cai no manual.
   - Se `min = 1`: indeciso, cai no manual sem escrever.
   - Cada medição fica no log, com os 16 valores e as inversões.
3. O fluxo manual troca `metades-*` por `escada-*`, sem outra mudança de lógica.
4. Câmera ocupada (o `AutoFocusService`): `aguardar_autofoco` já roda antes. Se o `nl_camcheck` falhar ao
   abrir o dispositivo, cai no manual.

### C4 - Ligação

- `pendrive-autorun/nl_camcheck` (cópia do binário ARM) entra no kit e na lista de md5 do
  `newlink_update.sh`, junto com `cor.sh` e os PNG novos. `tests/atualizar-md5-kit.sh` regenera e
  confere. A cópia para a pasta de trabalho root `0700` segue a regra do E3b (arquivo regular, dono root,
  sem link).
- `install.sh --pendrive` e a opção 5 do `install.bat` copiam o `nl_camcheck`.
- `pendrive-autorun/LEIA-ME.txt` (ASCII puro, byte-exato) explica em linguagem de leigo: o projetor testa
  a cor sozinho pela câmera; se não conseguir, faz a pergunta da escada.
- Doc 41 §4 e §5, bloco 5 (estado de E2b, E3d e E5) e `artifacts/camcheck/README.md` (criar se não
  existir) descrevem o comportamento novo. O que for só para o coordenador medir no aparelho fica marcado
  como pendente, não como feito.

## Restrições

- `pendrive-autorun/*` em ASCII puro (`grep -P '[^\x00-\x7F]'` vazio) e byte-exatos. As listas de md5
  são atualizadas pelo script, nunca à mão.
- **Nenhum agente fala com o projetor.** A prova no aparelho é do coordenador.
- Não mudar `newlink_update.sh` além da lista de md5 e do que a cópia do `nl_camcheck` exigir. A parte
  térmica não muda.
- Commits pequenos e temáticos no branch `bloco-7/cor-automatica`, sem linha de atribuição. Nunca
  `git add -A`, `.` ou `--all`.

## Prova

1. `make check`, `make check-kit`, `make check-bin` e `make check-fix` verdes.
2. Harness novo: o `nl_camcheck` do host sobre as 4 fixtures acha 16 faixas nas duas calibrações. Em
   `escada-f1` dá monótona e em `escada-f0` dá fora de ordem, com os valores do protótipo (±2).
3. Casos no `test-kit-pendrive.sh`, com stubs de `am`, `cmd`, `nl_camcheck` e `lvdsctl`:
   - formato certo: nada escrito;
   - formato errado que fica monótono depois da troca: grava, sem tecla mantém, e com tecla desfaz;
   - troca que não resolve: reverte e cai no manual;
   - calibração com 15 faixas: manual;
   - `nl_camcheck` adulterado: aborta antes de executar;
   - `am force-stop` chamado antes de cada `am start`;
   - `PFL_MODO_AUTO=0` sem `PFL_TESTE`: ignorado.
4. `bash -n`, `dash -n` e `shellcheck` sem aviso novo; `python3 -m py_compile` nos `.py`.
5. **Coordenador, no aparelho:** rodar o `cor.sh` real via adb nos dois formatos de partida (JEIDA e
   VESA). Esperado: a partir de JEIDA, nada escrito; a partir de VESA, termina em JEIDA sozinho. Conferir
   com `cmp -l` e com a câmera.
