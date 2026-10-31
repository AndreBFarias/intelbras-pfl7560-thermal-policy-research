# Bloco 19 - Fechar o que está em aberto (2026-10-31)

Pedido do dono: concluir tudo o que estava em aberto, em paralelo para ganhar velocidade, com commit e push de tudo. A
lista vem de `docs/ESTADO.md`. Três frentes em paralelo, com arquivos separados. O
coordenador integra, regenera as listas de md5 (`bash tests/atualizar-md5-kit.sh`) e prova no aparelho.

Regras comuns:
- nenhum agente fala com o projetor;
- stage só por caminho explícito; commits pequenos em pt-BR sem acento, sem linha de atribuição; push do branch;
- kit em ASCII puro; md5 só pelo script;
- `make check`, `make check-kit` e `make check-fix` verdes; `shellcheck` sem aviso no kit;
- relatório no schema: feito, provas, commits, provisorio, desvios, pendente.

## 19A - Bloco 11: foco e nitidez medidos pela câmera

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-19a`, branch `bloco-19a/foco`. Spec de fundo:
`docs/sprints/2026-10-31-bloco-11-qualidade-e-foco.md` e a pesquisa `docs/research/46-foco-e-qualidade.md`.
Arquivos: `artifacts/camcheck/**`, `pendrive-autorun/nl_camcheck` (cópia do ARM), `pendrive-autorun/suite.sh`
(só a etapa 2), `pendrive-autorun/kit/` **não**, `tests/test-camcheck.sh`, `tests/test-suite.sh` (casos da
etapa 2), `pfl7560-qualidade.sh` (novo, PC), `tests/test-qualidade.sh` (novo), docs 44, 46 e a tarefa do bloco 11.

1. **`nl_camcheck nitidez`:** mede a largura de borda (10 a 90%) em 9 regiões (grade 3x3), achando as
   regiões pelas faixas reais do quadro e não por janelas fixas. Saída `chave=valor` estável (`nitidez_r1c1=` …
   `nitidez_r3c3=`, `quadro=`). Testes com os quadros reais de `tests/fixtures/camera/` e sintéticos de borda
   conhecida. ARM recompilado com o NDK, como no README.
2. **Varredura fina de foco** na etapa 2 da `suite.sh`, pelo `hidebug` (doc 46: `gfd` lê a posição, `gfdr` dá a
   faixa, `sfd2 <dir> <passos>` anda, `sfd <pos>` vai a uma posição absoluta):
   - parte da posição atual;
   - anda em passos pequenos para os dois lados (um limite fixo, PROVISÓRIO), medindo a borda do **centro**;
   - fica com o mínimo;
   - **volta à posição inicial** se nada melhorar, ou se o `hidebug` não responder.
   Respeite o "Motor is too hot!" (doc 46): poucos passos, pausa entre eles. Nunca `gtt`. Só roda se o foco
   estiver ruim pelos limiares que já existem. Constantes nomeadas e PROVISÓRIO.
3. **Resumo:** o item "Nitidez" mostra o pior canto e o centro ("Centro 1,9 px · Pior canto 3,1 px"), e a dica
   separa as causas. Pior só nos cantos de um lado, com os 4 pontos ligados = "zere os 4 pontos e alinhe o
   projetor de frente". Pior no centro = "foco refeito".
4. **`pfl7560-qualidade.sh` (PC, adb):** lê e mostra os ajustes de imagem do doc 46 (modo de imagem, nitidez,
   NR, MEMC, DCI, overscan, saída 1080p) comparados com o "máximo de qualidade" do doc. Só muda algo com
   `--aplicar <ajuste>` e confirmação digitada, guardando o valor antigo para `--voltar`. Harness com adb
   falso.

## 19B - O resto do tema

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-19b`, branch `bloco-19b/tema`. Arquivos:
`artifacts/overlay/**`, `docs/research/48-tema-no-sistema.md`, `pendrive-autorun/overlay/` e as listas do kit
(só pelo `tests/atualizar-md5-kit.sh`).

1. **Cores escritas em layout** (doc 48 §10.5, §11, §12: os cartões coloridos do gerenciador de arquivos, a
   lista de entradas e o que mais houver). Agora com sobreposição de **layout**, numa regra estrita: copiar o
   XML do layout do alvo **idêntico** e mudar **só** valores de atributos de cor (`textColor`, `background` com
   cor, `cardBackgroundColor`, `tint`) para cores literais do tema.
   - O `conferir.py` ganha a checagem de layout: a árvore é igual à do alvo (mesmos elementos, ids, ordem e
     atributos) e só os atributos de cor diferem.
   - Layout que referencia recurso que não existe na sobreposição fica de fora, com o motivo.
2. **Imagens do framework** que o tema não alcançou (botões de mídia e listas do HiMusic, e outras do doc 48
   §12.7): a sobreposição do `android` passa a aceitar **imagens** (`drawable` PNG ou 9-patch, recoloridas pelo
   `recolorir.py`, preservando a borda do 9-patch). Continua sem dimensão nem layout. `versionCode` + 1.
3. O branco global (`@android:color/white`) **fica**: mudar trocaria todo branco do sistema. Só registre.
4. Prévias antes e depois, `conferir.py` "TUDO OK" e `apksigner verify`.

## 19C - O teste intermitente

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-19c`, branch `bloco-19c/flaky`. Arquivos:
`tests/test-kit-pendrive.sh` e, se a causa estiver no script, `pendrive-autorun/cor.sh` (mudança mínima).

O caso `auto: fora de ordem, a troca resolve, sem tecla = mantem` falhou uma vez e passou na repetição:

```
journal ou gancho sobraram
telas: 'aguarde calibracao calibracao escada-1 escada-1 corrigida calibracao erro '
log sem a confirmacao (lvds_fmt=1 mantido, relido e a particao confere)
```

Ache a causa: rode o caso em laço (por exemplo 200 vezes, só ele) e capture uma falha com o log inteiro. Suspeitas a
conferir, sem presumir:
- corrida entre o `cor.sh` e a suíte no harness;
- `particao_so_difere_no_fmt`;
- o stub do `getevent`;
- `sleep` falso.

Corrija na origem. Se a causa for real no script, corrija o script, porque o aparelho também a teria. Prove com o
laço sem falha nenhuma.

## Estado (bloco 20, 2026-10-31)

19A, 19B e 19C integrados (merges `c8c13e9`, `5894761` e `26db6c1`). 19C: a causa estava no harness, não no
script (`7bc8b31`: a queda de energia simulada matava pelo nome o `cor.sh` de outra rodada do harness na mesma
máquina). Estado final em [ESTADO.md](../ESTADO.md).
