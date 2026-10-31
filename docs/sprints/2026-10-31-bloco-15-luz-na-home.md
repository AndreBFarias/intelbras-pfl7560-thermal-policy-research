# Bloco 15 - Botão de luz na home (2026-10-31)

Pedido do dono: "controlamos a iluminação travando ela no 100%, não conseguimos um botão na interface pra
controlar isso abaixando ela?"

## Medido no aparelho (2026-10-31)

- `printf 'picture\nsbl N\nquit\n' | /vendor/bin/hidebug` (N de 0 a 100) baixa **a luz do LED de verdade**. Com
  N=30 o dono confirmou "Escureceu bem". A leitura é `printf 'picture\ngbl\nquit\n' | /vendor/bin/hidebug`, que
  devolve a linha `backlight:N`.
- O `sbl` não mexe no `backlight brightness` do módulo custom (continua 1000), que é onde a proteção térmica
  age (1000 → 850 entre 66 e 70 °C). Os dois convivem: a térmica continua podendo baixar.
- A gravação do `sbl` pelo fabricante é **atrasada e não confiável**: com 60 aplicado e reboot logo depois, voltou
  o valor anterior (30). Por isso o valor escolhido é guardado por nós e reaplicado em todo boot.
- O `hidebug` só roda como root. A home é um app comum (UID de app), então a ponte é a mesma do pedido de
  verificação: um arquivo na pasta privada do app, lido pelo vigia root (`inotifyd` com a máscara `:wwy`,
  conferência de que o dono do arquivo é o dono da pasta e é UID de app). Ver `suite-pedido.sh` e o doc 44.

## Trabalho

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-15`, branch `bloco-15/luz`. Arquivos:
`artifacts/home/**`, `pendrive-autorun/suite-pedido.sh`, `pendrive-autorun/suite-boot.sh`, `tests/test-suite.sh` e
os docs 44 e 45 (uma seção cada).

1. **Home** (`com.pfl7560.home`, versionCode 3, mesma chave e mesmo `build.sh`):
   - um atalho **"Luz"** na fileira Atalhos, com ícone desenhado no traço da home (sol ou lâmpada) e o valor
     atual por baixo ("100%");
   - OK abre um painel no tema "Luz do projetor", com 5 níveis: 100, 80, 60, 40 e 25 (este marcado
     "Econômico"). Setas para escolher, OK aplica, BACK fecha. O nível atual fica marcado;
   - aplicar = gravar o número (texto ASCII, só dígitos) no arquivo `luz` de `getDataDir()`, com
     `FileOutputStream`;
   - o valor atual vem do arquivo `luz-atual` de `getDataDir()`, que o root escreve. Sem ele, mostra "100%";
   - prévias novas: o atalho e o painel aberto, abertas com Read e conferidas.
2. **Vigia** (`suite-pedido.sh`), no molde do pedido de verificação:
   - aceita também o nome `luz`, com o mesmo evento (`w`/`y`) e a mesma conferência de origem
     (`pedido_do_app`, generalizada para o nome do arquivo);
   - lê **só** dígitos (no máximo 3), exige 10..100 e recusa o resto com log;
   - grava em `$SUITE/luz` (root, 0600);
   - aplica pelo `hidebug` (`picture` / `sbl N`) e confere lendo `gbl`;
   - escreve `luz-atual` na pasta do app, com dono = UID do app e 0600 (por `chown`, sem seguir link);
   - apaga o pedido. Não usa a proteção de 10 min. Não roda enquanto a suíte estiver com a trava (rampa no
     meio); nesse caso guarda em `$SUITE/luz` e o fim da suíte ou o próximo boot aplica.
3. **Boot** (`suite-boot.sh`): se `$SUITE/luz` existe e vale 10..100, aplica no boot, antes de ligar o vigia, e
   atualiza o `luz-atual`. Vale com qualquer `gatilho`, porque é escolha do dono. Sem o arquivo, não mexe.
4. **Testes** no `tests/test-suite.sh` (o stub do `hidebug` já registra o que entra):
   - pedido de luz válido;
   - inválidos: `abc`, `5`, `200`, vazio, link, dono errado pelo UID mínimo;
   - boot reaplica;
   - `luz-atual` escrito;
   - nenhum `gtt` chega ao `hidebug`;
   - a verificação continua funcionando.
   Depois, `bash tests/atualizar-md5-kit.sh`, `make check`, `make check-kit` e `make check-fix` verdes, e
   `shellcheck` sem aviso novo.
5. Copie o APK novo para `pendrive-autorun/pfl7560-home.apk` e rode o script de md5.

## Restrições

Nada de adb nem projetor. Stage só por caminho explícito; commits pequenos sem linha de atribuição; push do
branch. Kit em ASCII puro. Relatório no schema: feito, provas, commits, provisorio, desvios, pendente.
