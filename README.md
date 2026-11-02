# MeowCast para o projetor Intelbras PFL7560

Correção e sistema para o projetor **Intelbras PFL7560** (Android 9, SoC HiSilicon Hi3751V553; firmware V1.0.0.9
com USB-C ou V1.0.0.1 sem USB-C). Começou como pesquisa de um defeito térmico de fábrica e virou o **MeowCast**:
um kit de pendrive que corrige a proteção térmica e instala, por cima do Android do fabricante, uma verificação
automática da imagem, uma tela inicial nova e um tema escuro.

> Sem vínculo com a Intelbras. O kit edita `/vendor` (e, com backup, a cor na `panelparam` e o logo de boot), é
> reversível, não toca no bootloader e o aparelho continua recuperável pelo firmware de fábrica. Use por sua conta
> e risco.

## O problema original

A política térmica do aparelho é um arquivo de texto (`/vendor/etc/ZYCustom.ini`). De fábrica, os dois sensores
de temperatura estão no **mesmo canal** do multiplexador (`HW_VIRTUAL_CHANNEL=0`), então o segundo sensor, o que
fica no bloco do LED, **nunca é lido**. O aparelho age como se estivesse frio: os ventiladores aceleram tarde e o
desligamento de proteção não acompanha o calor real. O polarizador e o LCD queimam (duas trocas em 18 meses no
aparelho desta pesquisa). A proteção por ventilador travado também não funciona, e não há como ligá-la por
software. Detalhes: [doc 08](docs/research/08-por-que-fica-cego.md) e [doc 34](docs/research/34-escada-brilho-e-fanmonitor.md).
O mesmo defeito segue no firmware de outubro de 2026 ([doc 42](docs/research/42-firmware-2026-10-modelo-sem-usbc.md)).

Com a correção, a saída de ar caiu de **46,7 °C para 37,2 °C**.

## O que o kit faz

| Parte | O que muda no projetor |
|---|---|
| Térmica | o 2º sensor passa a ser lido, ventiladores a 100 %, brilho que desce sozinho entre 66 e 70 °C, desligamento a 75 °C, Wi-Fi que reconecta, sem o spam do `xiriservice` |
| Cor | confere uma escada de 16 cinzas pela câmera interna e acerta o formato do painel (VESA/JEIDA) se ele foi trocado |
| Suíte de verificação | confere cor, ângulo, foco, nitidez e temperatura e mostra um resumo; roda ao voltar da tomada, pelo pendrive e pelo ícone "Verificar projetor" |
| Home MeowCast | tela inicial nova, com o botão **Luz** |
| Tema Drácula | 20 sobreposições de cor nos apps do fabricante, mais o descanso de tela |
| Marca | logo e animação de boot MeowCast |

Cada parte, onde ela fica no aparelho e o doc dela: [`docs/README.md`](docs/README.md).

## Instalar

1. No PC: `./install.sh --pendrive /caminho/do/pendrive` (no Windows: `install.bat`, opção 5). O script copia o
   kit para um pendrive FAT32 e confere o md5 de cada arquivo.
2. Com o projetor **desligado**, plugue o pendrive e ligue o projetor.
3. A térmica e a cor valem na hora (o aparelho reinicia uma vez). A home, o tema e o ícone valem a partir do boot
   seguinte.

Sem pendrive, pelo PC (adb por Wi-Fi), só a térmica: `PFL_IP=<ip> ./pfl7560-fix.sh apply`. Passo a passo,
verificação e o que você precisa no PC: [`INSTALL.md`](INSTALL.md).

## Desfazer

- **MeowCast:** ponha um arquivo vazio `DESINSTALAR-SUITE.txt` na raiz do pendrive e ligue o projetor com ele
  plugado. Saem a suíte, a home como tela inicial, o tema e a marca, e os apps do fabricante voltam. A térmica e a
  cor ficam.
- **Térmica:** `./pfl7560-fix.sh revert`, no mesmo PC que fez o `apply` (é lá que fica o backup de fábrica).
- **Tudo:** regravar o firmware de fábrica ([guia 16](docs/guide/16-recuperacao-brick.md)). Isso apaga os dados do
  aparelho.

## Mapa de pastas

| Pasta | O que tem |
|---|---|
| `pendrive-autorun/` | o kit que roda no projetor (vai para a raiz do pendrive) |
| `artifacts/` | código e binários: app, home, tema, câmera, telas, gerador do `.bin` e arquivos de fábrica de referência ([mapa](artifacts/README.md)) |
| `docs/` | documentação; o índice é o [`docs/README.md`](docs/README.md) |
| `tests/` | testes que simulam o aparelho, sem projetor ([como rodar](tests/README.md)) |
| `firmware/` | firmwares oficiais (Git LFS) e as nossas builds (só locais) ([tabela](firmware/README.md)) |
| `media/` | fotos do aparelho aberto |
| raiz | `install.sh`/`install.bat`/`install-firmware-pendrive.ps1` e os comandos `pfl7560-*.sh` |

Cada arquivo de código, quem o chama, o teste que o cobre, o fluxo de dados no aparelho e onde ficam as medições:
[`docs/MAPA.md`](docs/MAPA.md).

## Onde está cada coisa

| Quero... | Vá em |
|---|---|
| saber o que está provado e o que falta | [`docs/ESTADO.md`](docs/ESTADO.md) |
| instalar, verificar ou reverter | [`INSTALL.md`](INSTALL.md) |
| entender uma sigla (gtt1, LSADC, VESA/JEIDA, BIN-S4a...) | [`docs/glossario.md`](docs/glossario.md) |
| trocar o painel LCD e acertar a cor | [guia 32](docs/guide/32-guia-troca-painel-lcd.md) e [doc 33](docs/research/33-matriz-paineis.md) |
| recuperar um aparelho que não liga | [guia 16](docs/guide/16-recuperacao-brick.md) |
| entender por que a proteção cega | [doc 37](docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md) |
| a build `.bin` | [doc 47](docs/research/47-build-completa.md) e [`firmware/README.md`](firmware/README.md) |
| a divulgação à fabricante | [`docs/disclosure/STATUS.md`](docs/disclosure/STATUS.md) |
| mexer no código | [`CONTRIBUTING.md`](CONTRIBUTING.md) e o [mapa](docs/MAPA.md) |

Comandos do PC (todos por adb no Wi-Fi, com `PFL_IP=<ip>`):

| Comando | Faz |
|---|---|
| `pfl7560-fix.sh` | aplica, mostra ou desfaz a correção térmica (`apply`, `status`, `revert`) |
| `pfl7560-saude.sh` | 12 checagens sem escrever nada; `--vivacidade` testa se a proteção reage |
| `pfl7560-lcd-color.sh` | cor depois da troca do painel (VESA/JEIDA), com backup |
| `pfl7560-menu.sh` | menu com as opções acima (ou `PFL7560-Corrigir.desktop`) |
| `pfl7560-vigia-lsadc.sh`, `pfl7560-monitor-props.sh` | acompanham a proteção durante o uso, sem sondar |
| `pfl7560-monitor-termico.sh`, `pfl7560-autocaptura.sh`, `pfl7560-teste-brilho.sh` | medições pontuais que sondam o sensor |
| `pfl7560-processos.sh`, `pfl7560-qualidade.sh` | CPU em segundo plano; ajustes de imagem |
| `pfl7560-marca.sh`, `pfl7560-vlc.sh` | marca na partição `logo`; VLC como app do sistema |
| `pfl7560-evidencias.sh` | captura de evidências do defeito |

## Testes

Precisa de `bash`, `python3` e um compilador C; nada fala com o projetor.

```bash
make check       # md5 dos arquivos de fábrica e da correção
make check-kit   # kit do pendrive, suíte, telas, câmera e scripts do PC, com aparelho de mentira
make check-fix   # pfl7560-fix.sh nos dois modelos
make check-bin   # gerador do .bin em containers sintéticos
```

## Estado

Em uso no projetor do dono desde 2026-10-31. **Provisório:** tirar da tomada com o projetor ligado, a varredura
fina de foco (desligada até ganhar passo relativo, doc 46 §11), algumas telas que ainda faltam olhar com o controle e o modelo sem
USB-C (só testado em simulação). A build `.bin` (`PFL7560-S4a`, os 3 fixes nos mesmos blocos do stock) passa nas
provas do PC e **nunca foi gravada**; o `install.sh --com-firmware` a põe na raiz do pendrive, e gravá-la é o gate
BIN-S4a ([doc 47](docs/research/47-build-completa.md)). Lista completa e atualizada: [`docs/ESTADO.md`](docs/ESTADO.md).

O relatório para o CSIRT da Intelbras está pronto e ainda não foi enviado
([`docs/disclosure/STATUS.md`](docs/disclosure/STATUS.md)). Este repositório é privado até a divulgação.

## Licença

[GPLv3](LICENSE). Sem garantia. Marcas, firmware e manuais da Intelbras pertencem à Intelbras e estão aqui só para
reparo e interoperabilidade.
