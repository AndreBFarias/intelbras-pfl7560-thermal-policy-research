# Estado em 2026-10-31 (fim da sessão longa dos blocos 9 a 19)

Branch de integração: `sessao/2026-09-03-optica-e-revisao-scripts`, enviado ao origin. Os worktrees dos blocos já
juntados foram removidos (os branches seguem no origin).

Bateria verde, em verificações sem falha (contada de novo na revisão do bloco 20):

| `make check-kit` | `make check-fix` | `make check-bin` |
|---|---|---|
| 192 / 94 / 689 / 550 / 86 / 35 / 72 / 42 | 48 | 124 |

A ordem do `check-kit`: `test-camcheck`, `test-tela`, `test-kit-pendrive`, `test-suite`, `test-preparar-pendrive`,
`test-processos`, `test-pc-marca-vlc`, `test-qualidade`.

O `make check` também passa.

## No projetor do dono (192.168.1.5), provado

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

## Pendrive (`sda`, Cruzer Fit, FAT32 "PFL7560")

Kit completo (49 arquivos conferidos), `usb_update.bin` oficial V1.0.0.9 na raiz e o nosso `.bin` antigo em
`firmware-nosso-NAO-GRADUADO/`. Ligar segurando POWER com ele plugado regrava o firmware.

## Build

`firmware/PFL7560-COMPLETO-NAO-GRADUADO.bin` (local, md5 `397698b9…`): escada, wi-fi, xiri e o `.rc` da suíte.
Válida no PC. **Não gravada**: o gate BIN-S4a só roda com a palavra do dono e o resgate à mão. Depois de gravar,
o pendrive do kit é obrigatório (apps, home, tema e suíte não cabem no slot).

## Só com o dono no projetor

1. Tirar da tomada **com o projetor ligado** e religar: a suíte roda sozinha, com o motivo `queda_de_energia`
   (doc 44 §12, passo 7).
2. Olhar com o controle o teclado na tela, o pareamento do controle, o menu de imagem de uma entrada HDMI, a
   contagem de desligar e a página de cartões do gerenciador.
3. Foco ruim de propósito (girar a lente): ver a varredura fina mexer o motor e voltar. A unidade do `gfd`/`sfd`
   e os passos estão marcados como PROVISÓRIO (doc 44 §16).
4. `pfl7560-qualidade.sh` no aparelho: ler os ajustes de imagem e decidir com o dono o que aplicar.
5. Se quiser: gravar a build nova (gate BIN-S4a) com o resgate à mão.

Fica de fora do tema, por decisão: o branco global do Android (`@android:color/white`), porque trocá-lo muda
todo branco do sistema. Doc 48 §13.4.

## Revisão do bloco 20 (conferente final, 2026-10-31)

Branch `bloco-20/revisao`. Sem adb e sem projetor.

- **Código root:** o laço do vigia sem `inotifyd` não tratava o descanso de tela (só o `inotifyd` entregava
  `descanso-inicio`/`descanso-fim`). Corrigido no `suite-boot.sh`, com um caso novo no `test-suite.sh` que
  falhava antes (2 falhas) e passa depois. O aparelho do dono tem `inotifyd`, então ali nada mudava.
- **Docs sem contradição:** doc 44 (estado de uso, vigia nas duas pastas, ícone sempre roda, aviso de
  temperatura com `DPAD_CENTER`, luz pela prop, PATH dos serviços), doc 45 e o README da home (home pela prop
  `vendor.newlink.launcher.package`), doc 48, `INSTALL.md`, `LEIA-ME.txt`, guia 32, `firmware/README.md`,
  READMEs do app e do tema, a seção de estado dos blocos 9 a 19, o índice `docs/README.md` e a seção MeowCast do
  `README.md`.
