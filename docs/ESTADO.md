# Estado do projeto

Atualizado em 2026-10-31, no bloco 21. Este é o único lugar com o que está provado, o que falta e o que é
provisório; os outros docs apontam para cá. O histórico de cada bloco está em [`sprints/`](sprints/).

## Provas no PC

Bateria verde depois do bloco 21, em verificações sem falha:

| `make check-kit` | `make check-fix` | `make check-bin` |
|---|---|---|
| 197 / 94 / 690 / 569 / 97 / 35 / 72 / 42 | 50 | 324 (444 com os dois stocks reais) |

A ordem do `check-kit`: `test-camcheck`, `test-tela`, `test-kit-pendrive`, `test-suite`, `test-preparar-pendrive`,
`test-processos`, `test-pc-marca-vlc`, `test-qualidade`. Com a S4a local em `firmware/`, o `test-preparar-pendrive`
dá 94: pula os 3 casos que copiariam 1,4 GB. O `make check` também passa. Como rodar: [`tests/README.md`](../tests/README.md).

## No projetor do dono (192.168.1.5), provado

- **Correção térmica** em `/vendor` (2º sensor lido, ventiladores a 100 %, escada de brilho, Wi-Fi, xiri).
- **Cor:** painel da 3ª troca em JEIDA, corrigido pela câmera interna e persistente no reboot (bloco 8;
  [matriz de painéis](research/33-matriz-paineis.md)).
- **Suíte:**
  - roda pelo boot, pelo ícone "Verificar projetor" e pelo pendrive. O ícone foi provado em 2026-10-31,
    disparado pelo vigia do boot, depois do PATH fixo com `/system/bin`;
  - etapas: cor, câmera, ângulo, nitidez 3x3, varredura fina de foco (só com foco ruim), temperatura, rampa e
    resumo;
  - avisos do sistema fechados antes da câmera: temperatura com o OK do controle (DPAD_CENTER), os outros com
    BACK.
- **Botão Luz** na home (`sbl`, reaplicado no boot).
- **Descanso de tela MeowCast.**
- **Home MeowCast** v4, tela inicial pela prop `vendor.newlink.launcher.package`.
- **Tema Drácula:**
  - 20 sobreposições ligadas pelo boot, a do `android` (v4, com imagens) por último;
  - layouts só com cor: os cartões do gerenciador, o Wi-Fi, o player e o pareamento;
  - gerenciador direto na lista.
- **Marca MeowCast** no carregador (partição `logo`, backup em `evidencias/logo-fabrica/`), no `logo.jpg` e no
  `bootanimation.zip`.
- **Apps:** Office, iOSCast e Espelhamento desligados; VLC 3.7.1 em `/vendor/app/VLC`.

## O que o bloco 21 mudou

Nada disto rodou no aparelho ainda; entra com o pendrive novo.

- **Kit:** o descanso de tela volta ao nível de luz de antes (não mais a 100 %); abertura e resumo seguem o motivo
  do boot; o `--desinstalar` apaga os sinais do descanso e a trava da suíte; `sync` antes de cada `mv` sobre
  arquivo de boot no `/vendor`; o `newlink_update.sh` com o `PATH` fixo; app e home com `versionCode` 5 (pedidos
  do descanso em ordem; home sem o cartão USB-C no modelo sem USB-C) e o `nl_camcheck` que limita os buffers.
- **Código sem comentário** (shell, Python, C, Java, Makefile): o porquê foi para [`codigo/`](codigo/) e o mapa
  para [`MAPA.md`](MAPA.md). Provado sem mudança de comando: árvore do `bash` igual antes e depois nos 36 scripts,
  `ast` igual nos 17 Python, objetos C e `.class` iguais. Os APKs foram refeitos (mesmo bytecode, só a tabela de
  linhas muda), então o kit os reinstala por cima, com o mesmo `versionCode` 5.
- **Pendrive:** o nosso `.bin` (S4a) na raiz como `usb_update.bin`; o oficial em `resgate-oficial/`; recusa
  pendrive com `DESINSTALAR-SUITE.txt` ou com `usb_update.bin` sem `--com-firmware`.
- **Gerador do `.bin`:** nos mesmos blocos do stock por padrão, sparse só RAW e DONTCARE, `verificar_bin` antes de
  a saída ganhar o nome, e `--realocar` para a build com app, home e sobreposições (doc 47 §10).
- **Docs:** um dono por fato (ESTADO aqui, ventiladores no doc 07, painéis no doc 33, `.bin` no doc 47),
  [`glossario.md`](glossario.md), [`../CONTRIBUTING.md`](../CONTRIBUTING.md) e o índice [`README.md`](README.md).

## Pendrive

Layout decidido pelo dono em 2026-10-31 (bloco 21), gerado por `./install.sh --pendrive <ponto> --com-firmware`:

- o kit completo na raiz, com o md5 de cada arquivo conferido depois da cópia;
- `usb_update.bin` na raiz = **o nosso** `PFL7560-S4a-NAO-GRADUADO.bin` (md5 `a6e5da14…`), nunca gravado no
  aparelho. Ligar **segurando o POWER** com o pendrive plugado grava esse firmware;
- `resgate-oficial/PFL7560.bin` = o oficial V1.0.0.9 (md5 `28a2f280…`), com um `LEIA-ME.txt`. Para o resgate,
  ele vai para a raiz de outro pendrive como `usb_update.bin` ([guia 16](guide/16-recuperacao-brick.md)).

O pendrive físico do dono (`sda`, Cruzer Fit, FAT32 "PFL7560") estava no arranjo antigo (oficial na raiz e o
`.bin` antigo em `firmware-nosso-NAO-GRADUADO/`) e é regravado no fechamento do bloco 21. Antes de gravar, a S4a
tem de estar em `firmware/` do repositório principal (o `install.sh --com-firmware` recusa sem ela). Com a S4a na
raiz, **ligar segurando o POWER com este pendrive plugado grava a S4a**; ligar normalmente só roda o kit.

## Build

`PFL7560-S4a-NAO-GRADUADO.bin` (local, md5 `a6e5da14cb3f53b42a457eb92bd91814`, 1393758396 B, CRC do vendor
`0x883b40d6`): só os 3 fixes (escada de brilho no `ZYCustom.ini`, Wi-Fi no `build.prop`, `xiriservice` desligado no
`init.bigfish.rc`), nos mesmos blocos do stock, com o layout de chunks, o slot e o `checksum1` do stock. Regerada
no fim do bloco 21 a partir do stock V1.0.0.9 com o gerador sem comentário: o mesmo md5. É a que vai para o
pendrive. Depois dela, só se subir limpa, a `PFL7560-S4b-COMPLETO-NAO-GRADUADO.bin` (`31702b647ba9b2bca98e6da625231e69`,
CRC `0xd8e4e78b`, refeita com os APKs novos), com o `.rc` da suíte, o app, a home e as 20 sobreposições. As duas
saem iguais em duas rodadas, passam no `verificar_bin` no PC e **não foram gravadas**. Detalhes, ordem e roteiro:
[doc 47](research/47-build-completa.md) §8, §10 e §11; tabela das builds: [`firmware/README.md`](../firmware/README.md).

## Só com o dono no projetor

1. Tirar da tomada **com o projetor ligado** e religar: a suíte roda sozinha, com o motivo `queda_de_energia`
   ([doc 44](research/44-suite-de-boot.md) §12, passo 7).
2. Olhar com o controle o teclado na tela, o pareamento do controle, o menu de imagem de uma entrada HDMI, a
   contagem de desligar e a página de cartões do gerenciador.
3. Foco ruim de propósito (girar a lente): ver a varredura fina mexer o motor e voltar. A unidade do `gfd`/`sfd`
   e os passos estão marcados como PROVISÓRIO (doc 44 §16).
4. `pfl7560-qualidade.sh` no aparelho: ler os ajustes de imagem e decidir com o dono o que aplicar.
5. Tema com a luz da sala: o contraste do roxo, do rosa e do vermelho sobre o cartão (3,5 a 3,8:1) nas telas da
   suíte; se o plano de fundo for aplicado, o arco roxo de 3 px e o gradiente sem faixas
   ([`artifacts/tema/README.md`](../artifacts/tema/README.md)).
6. Do bloco 21, no 1º boot com o pendrive novo: o `newlink_update.log` com `[OK] app` e a home reinstalados por
   cima (mesmo `versionCode` 5, md5 novo) e a home ainda como tela inicial; um descanso de tela **sem** nível
   escolhido no botão Luz (a luz tem de voltar ao nível de antes); `mount | grep vendor` para saber se o `/vendor`
   tem `auto_da_alloc` ou `nodelalloc` (o `sync` antes do `mv` está no doc 44 §11).
7. Se quiser: gravar a S4a (gate BIN-S4a) com o resgate oficial pronto num **outro** pendrive, pelo roteiro do
   doc 47 §8. Só o aparelho prova que o loader grava a S4a e que o Android sobe com os 3 fixes; a S4b só depois.

Fica de fora do tema, por decisão: o branco global do Android (`@android:color/white`), porque trocá-lo muda
todo branco do sistema. Doc 48 §13.4.

## Pendências de pesquisa

| ID | O que falta | Doc |
|---|---|---|
| BIN-S4a / BIN-S4b | gravar a S4a no aparelho e, se subir limpa, a S4b | [47](research/47-build-completa.md) §11 |
| LSADC-S1 | campanha passiva de ~30 h sob uso real (aberto, despriorizado) | [37](research/37-mecanismo-lsadc-defasagem-dos-aneis.md) §11, [35](research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md) |
| LCD-S1 (c) | o fluxo completo do `pfl7560-lcd-color.sh` rodado no aparelho | [guia 32](guide/32-guia-troca-painel-lcd.md), [29](archive/29-roadmap-troca-lcd.md) (arquivado) |
| LCD-S2 | o wizard no aparelho, forçando tela preta | [29](archive/29-roadmap-troca-lcd.md) (arquivado) |
| E4 do bloco 5 | a bancada completa do pendrive e a prova com um leigo | [bloco 5](sprints/2026-10-29-bloco-5-kit-universal.md) |
| Modelo sem USB-C | kit, home (fileira sem o cartão USB-C) e build só testados em simulação | [42](research/42-firmware-2026-10-modelo-sem-usbc.md), [45](research/45-home-pfl7560.md) §13 |
| REPO-S2 | pré-requisitos para tornar o repositório público | [`disclosure/STATUS.md`](disclosure/STATUS.md) |
