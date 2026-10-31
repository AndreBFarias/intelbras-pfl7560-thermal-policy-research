# Bloco 12 - `Build` nova com tudo (preparação offline) (2026-10-31)

Pedido do dono: "nossa nova build vai conferir isso tudo né? por default? [...] ter essas correções e o
sistema operacional todo prontinho." O dono escolheu preparar agora, em paralelo ao tema.

**Invariante:** nada é gravado no aparelho. Gravar o `.bin` é o gate BIN-S4a. Só acontece com a palavra do dono
naquele momento, com o pendrive de resgate na mão, e **nunca** no modelo sem USB-C com esta base.

## Estado

- O gerador `artifacts/bin-build/build_fix_bin.py` já carimba os metadados (modo, uid/gid, `security.selinux`)
  e aborta se um `.rc` ficar com escrita para grupo ou outros. Foi exatamente isso que causou o brick de julho:
  um `.rc` 0664 sem rótulo.
- A `build` atual (`firmware/PFL7560-FIX-escada-NAO-GRADUADO.bin`, md5 `eae3a83d...`) só troca o `ZYCustom.ini`.
  Foi aprovada no PC e nunca foi gravada. Ver o README do `firmware/` e a memória do builder.
- O JEIDA **não** entra: depende do painel de cada aparelho. Quem cuida dele é a suíte, pela câmera.
- O que o kit põe no `/vendor` hoje:
  - `etc/ZYCustom.ini` (térmico);
  - `build.prop` (`wifi_disconnect_on_boot=0`);
  - `etc/init/hw/init.bigfish.rc` (xiri `disabled`);
  - `etc/init/pfl7560-suite.rc` (0644, `vendor_configs_file`);
  - `app/PFL7560/PFL7560.apk` (0755/0644, `vendor_app_file`).
- A suíte em si mora em `/data/vendor/pfl7560-suite`, que o `.bin` não grava. Ver o doc 44.

## Trabalho

Worktree `/home/andrefarias/Desenvolvimento/pfl7560-wt/bloco-12`, branch `bloco-12/build`. Arquivos:
`artifacts/bin-build/**`, `docs/research/47-build-completa.md`, `tests/` só para testes novos do builder, e o
alvo do `Makefile` que já roda os testes do builder.

1. **Desenho no doc 47**, com recomendação. Como a `build` leva a suíte, se o `/data` não vem no `.bin`? Opções:
   - (a) a `build` leva o `.rc`, o app e os fixes, e a suíte entra uma vez pelo pendrive;
   - (b) a `build` leva também os arquivos da suíte numa pasta só de leitura do `/vendor` (por exemplo
     `/vendor/etc/pfl7560-suite/`), e o `suite-boot.sh` copia para `/data/vendor/pfl7560-suite` no 1º boot,
     conferindo md5;
   - (c) outra, se for melhor.
   Pese: o que muda no `newlink_update.sh` e no `suite-boot.sh`, o espaço livre da imagem do vendor, o risco no
   boot e a idempotência com o kit por pendrive. **Não mude** os scripts do kit: escreva no doc o que mudaria.
2. **Gerador parametrizado.** Ele lê do `pendrive-autorun/` o conjunto final de arquivos, para ser rodado de
   novo depois que o tema (bloco 10) entrar.
   - Um arquivo de manifesto (`artifacts/bin-build/conteudo.txt`): `origem destino modo uid gid rotulo` por
     linha.
   - Grava cada arquivo novo ou trocado na imagem do vendor com os metadados carimbados e conferidos
     (`verify_meta` estendido para pastas novas e APK).
   - Cria pastas com 0755 e rótulo.
   - Aborta se faltar espaço ou se algum metadado sair diferente.
   - Mantém tudo o que já existe: checksum1, CRC do record, tamanho.
3. **Provas no PC:**
   - testes com imagens sintéticas pequenas;
   - uma rodada real com o stock V1.0.0.9 (o zip LFS), gerando um `.bin` de teste e conferindo com `debugfs`
     arquivo por arquivo: modo, dono, rótulo e conteúdo. Também: só o record do vendor mudou, o checksum1 confere
     e o cabeçalho está intacto;
   - **apague o `.bin` de teste no fim**, porque são 1,3 GB. Registre o md5 no doc.
   - nada no aparelho.
4. **Relatório:** o que fica PROVISÓRIO até o gate BIN-S4a, e um roteiro de gravação seguro para o dono
   (resgate pronto, o que olhar no 1º boot, como voltar).

## Atualização (bloco 20, 2026-10-31)

A build atual é `firmware/PFL7560-COMPLETO-NAO-GRADUADO.bin` (md5 `397698b9…`: escada, wi-fi, xiri e o `.rc` da
suíte), válida no PC e **não gravada** (gate BIN-S4a); a de escada citada acima é a anterior. O kit do pendrive
leva hoje também a home, as 20 sobreposições, a prop do gerenciador de arquivos e a marca (doc 44 §15). Doc 47 e
`firmware/README.md`.
