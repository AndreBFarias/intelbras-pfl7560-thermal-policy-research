# Bloco 9A - `nl_tela` (telas geradas no aparelho) e `nl_camcheck geometria` (2026-10-30)

Parte do [bloco 9](2026-10-30-bloco-9-suite-de-boot.md). Contratos C-tela e C-geo estão lá e são fixos.
Branch `bloco-9a/tela-e-geometria`, worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-9a`.

## O que se mediu / por que

- A suíte precisa mostrar telas com valores do momento (resumo, etapas). No aparelho não há Python; o
  `nl_camcheck` (C, NDK r27c) é o precedente. Um gerador em C com `stb_truetype.h` + `stb_image_write.h`
  (domínio público, um cabeçalho cada) e as fontes IBM Plex (OFL) escreve o PNG que a galeria abre.
- A câmera resolve ~1100 px na largura para 1920 projetados (bloco 8): a nitidez e o foco se medem pela
  largura da borda das faixas brancas da tela de calibração (já projetada pelo kit), não por listras finas.
- Quadros reais em `tests/fixtures/camera/` (bloco 8): `calibracao-hd-f1.yuyv`/`calibracao-hd-f0.yuyv`
  (1280x720, imagem inclinada pela correção de 4 pontos), `calibracao-inclinada-f1.yuyv` (640x480, mesma
  inclinação), `calibracao-f1.yuyv`/`-f0` (640x480, boot anterior, menos inclinada).

## Cura

### A1 - `artifacts/tela/nl_tela.c` (novo)

- Terceiros em `artifacts/tela/terceiros/` (`stb_truetype.h`, `stb_image_write.h`, com a versão e a licença
  no topo, baixados do repositório `nothings/stb`). Fontes em `pendrive-autorun/fontes/` (os 5 TTF do C-tela
  + `OFL.txt` da IBM Plex), baixadas do `IBM/plex` (URLs no bloco 9). São binários: entram no
  `.gitattributes` como byte-exact (siga o padrão que já existe para `*.yuyv`).
- Implementa C-tela exatamente: modos `aviso` e `resumo`, decodificação `\uXXXX` e `\n`, truncamento com
  reticências por largura medida, quebra de parágrafo no `texto` por largura, fontes com reserva, saída PNG
  1920x1080 RGB. Antisserrilhado da `stb_truetype` com mistura de cor correta (gamma simples basta).
  Valide entradas como o `nl_camcheck` faz (tamanho de arquivo, número de grupos/itens, linhas longas).
- Visual: siga o C-tela e as telas do canvas (https://claude.ai/artifact/5Tn6dpqHX2d9kiFVMQDpKT,
  quadros `Main`, `Temperatura`, `Resumo`), mais limpo: o dono pediu "bonita, agradável, organizada e limpa".
  Ritmo vertical consistente, colunas com a mesma linha de base, nada encostado em borda, nada cortado.
- Compila no PC (`cc -O2 -Wall -Wextra -lm`) e no NDK r27c (`armv7a-linux-androideabi24-clang -O2 -Wall
  -static-libstdc++` se precisar; sem dependências dinâmicas além da libc/libm do Android). Binário ARM em
  `artifacts/tela/nl_tela` e cópia em `pendrive-autorun/nl_tela`.
- `artifacts/tela/README.md` (ASCII, como o do camcheck): compilar, comandos, formato, provas.

### A2 - `nl_camcheck geometria` (em `artifacts/camcheck/nl_camcheck.c`)

- Implementa C-geo. Usa as faixas do `faixas.txt` (linhas do quadro na janela central) como guia e procura,
  em três janelas de colunas (15-21 %, 47-53 %, 79-85 %), o centro de cada faixa (média ponderada pela luma
  acima do limiar local) e a largura 10-90 % de cada borda (subida e descida). Inclinação: regressão do
  deslocamento vertical do centro das faixas entre as colunas, em graus (`atan` de px/px). Trapézio: altura
  da pilha (centro da última menos o da primeira faixa) à direita sobre a da esquerda. Contraste: (média do
  miolo das faixas - média dos vãos) / média do miolo, coluna central.
- Não muda `info`, `grab`, `faixas`, `niveis`. Continua sem `S_CTRL`.
- Recompila o ARM e copia para `pendrive-autorun/nl_camcheck`; atualiza o `NLCAM_MD5` do `cor.sh` e roda
  `tests/atualizar-md5-kit.sh` (a lista do `newlink_update.sh` tem de bater). **Não** mexa em outra parte do
  `cor.sh` nem do `newlink_update.sh`: são do 9B. Se o 9B mudar os mesmos arquivos, o coordenador integra.

### A3 - Harness

- `tests/test-tela.sh` (novo): compila no host, gera as telas de exemplo (`aviso` de abertura tomada,
  abertura pendrive, etapa de temperatura, final "pode tirar o pendrive"; `resumo` com os 19 itens do dono,
  com uma correção, com uma atenção e com pendentes), confere tamanho/formato do PNG (1920x1080, assinatura
  PNG, decodificável por `python3 -I -c` com `zlib` puro ou `file`), confere que nenhum texto passou da
  margem (o `nl_tela` pode imprimir em stderr um aviso de truncamento: o teste exige zero truncamento nos
  exemplos do dono), entrada inválida sai 1/2, campo não-ASCII cru é recusado ou escapado (decida e teste),
  fonte ausente cai na reserva ou sai 1 com mensagem. Grava os PNG de exemplo em
  `tests/saida/telas/` (no `.gitignore`) para o coordenador olhar.
- `tests/test-camcheck.sh`: casos de `geometria` sobre os quadros reais: sai 0, imprime as 7 chaves, e os
  números fazem sentido: o quadro `calibracao-hd-f1` tem inclinação de módulo maior que `calibracao-f1`
  (os valores reais vão para o README e para o relatório final, que o 9B usa para os limiares); bordas em
  px positivas e menores que o vão; quadro sem faixas sai 3.
- `make check-kit` (ou o alvo que já roda `test-camcheck.sh`) passa a rodar `test-tela.sh` também.

## Restrições

- `pendrive-autorun/*.sh` e `*.txt` ASCII puro; binários e TTF entram na lista de md5 pelo script
  (`tests/atualizar-md5-kit.sh`; se ele só lista arquivos fixos, acrescente `nl_tela` e `fontes/*` à lista
  dele e ao `KIT_LISTA` gerado; a conferência do `newlink_update.sh` passa a cobrir esses arquivos).
- Nenhum agente fala com o projetor. Nada de `git add -A`, `.` ou `--all`; commits pequenos, sem linha de
  atribuição; push do branch no fim.
- Sem refatorar o vizinho. Comentários no estilo dos arquivos vizinhos (pt-BR sem acento nos `.c`/`.sh` do
  kit, como já estão).

## Prova

1. `make check`, `make check-kit`, `make check-fix` verdes; `bash -n`/`dash -n`; `shellcheck` sem aviso novo.
2. `tests/test-tela.sh` e `tests/test-camcheck.sh` verdes; PNG de exemplo gerados.
3. `file artifacts/tela/nl_tela` = ELF 32-bit ARM; `nl_camcheck` ARM refeito e igual nas duas pastas.
4. Relatório final com: os valores de `geometria` de cada quadro real, os caminhos dos PNG de exemplo, e
   qualquer desvio do contrato (se houve, por quê).
