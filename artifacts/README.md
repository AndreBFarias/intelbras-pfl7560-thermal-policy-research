# artifacts/ — código, binários e arquivos de referência

Os arquivos soltos aqui são **contrato**: scripts e testes leem cada um pelo caminho e conferem o md5. Não edite,
não renomeie e não deixe o editor mexer em espaço de fim de linha (`.gitattributes` marca todos como
`-text byte-exact`; motivo em [`CONTRIBUTING.md`](../CONTRIBUTING.md)).

## Arquivos de referência

| Arquivo | O que é | md5 | Quem lê |
|---|---|---|---|
| `ZYCustom.ini.ORIGINAL` | `/vendor/etc/ZYCustom.ini` de fábrica, V1.0.0.9 (com USB-C) | `29d8ba36149413e899563029df078f6d` | `pfl7560-fix.sh` (`INI_STOCK_MD5`), `make check`, testes |
| `ZYCustom_390.ini` | a correção térmica do modelo com USB-C (a mesma do `pendrive-autorun/ZYCustom.ini` e do `CONFIG_B64` do `pfl7560-fix.sh`) | `252ab7a72a007a8b79b3fc86bd5c0d19` | `build_fix_bin.py`, `make check`, scripts de medição |
| `ZYCustom.ini.NOTYPEC.STOCK` | `ZYCustom.ini` de fábrica do modelo sem USB-C (V1.0.0.1) | `ed3f314ca89698cb057a74ef64dca38e` | `pfl7560-fix.sh`, `make check`, testes |
| `ZYCustom_390.NOTYPEC.ini` | a correção do modelo sem USB-C (seções térmicas sobre o de fábrica dele) | `bdf5c4640596d1b2f2fb7f62fbadd6e3` | `pfl7560-fix.sh`, `newlink_update.sh`, `build_fix_bin.py`, `make check` |
| `ZYCustom_390.PREV-211927.ini` | uma versão anterior nossa que já foi para o aparelho; o kit a reconhece e atualiza | `bbf82dd17d4523b7df8a86bec0e850ce` | `newlink_update.sh`, `test-kit-pendrive.sh` |
| `build.prop.STOCK` | `/vendor/build.prop` de fábrica, V1.0.0.9 | `fd8406c494c201e468a0401fa082027c` | `pfl7560-fix.sh` (`BP_STOCK_MD5`), `install.bat`, `make check` |
| `build.prop.NOTYPEC.STOCK` | `/vendor/build.prop` de fábrica, V1.0.0.1 | `f5b24c1db546dcfb4340f485bf841c8e` | `pfl7560-fix.sh`, `make check` |
| `init.bigfish.rc.STOCK` | `/vendor/etc/init/hw/init.bigfish.rc` de fábrica | `8f7e02b2f382ceed65cf058e56c0c302` | `pfl7560-fix.sh` (`RC_STOCK_MD5`), `install.bat`, `make check` |

## Pastas

| Pasta | O que tem |
|---|---|
| [`app/`](app/README.md) | o app "Verificar projetor" (ícone que pede a suíte, descanso de tela) |
| [`home/`](home/README.md) | a home MeowCast (tela inicial com o botão Luz) |
| [`tema/`](tema/README.md) | a paleta Drácula (`dracula.txt`), o plano de fundo e a marca (logo e animação de boot) |
| [`overlay/`](overlay/README.md) | as 20 sobreposições (RRO) que pintam os apps do fabricante |
| [`tela/`](tela/README.md) | `nl_tela`, que desenha as telas da suíte no aparelho |
| [`camcheck/`](camcheck/README.md) | `nl_camcheck`, que lê a câmera interna (cor, ângulo, nitidez) |
| [`lcd-color-fix/`](lcd-color-fix/README.md) | `lvdsctl` (formato VESA/JEIDA do painel) e as imagens de teste de cor |
| [`bin-build/`](bin-build/README.md) | o gerador do `.bin` (`build_fix_bin.py`) e o manifesto `conteudo.txt` |
| [`re-termico/`](re-termico/README.md) | como refazer o disassembly do laço térmico (doc 37); a lib fica fora do git |
| `historico/` | versões antigas do `.ini` e do `.rc` e os perfis experimentais ([`perfis/`](historico/perfis/README.md), não aplicar); nenhum script lê |
| `firmware-extraido/` | o que se extraiu do firmware na pesquisa: `board.dtb`, `full_dts.txt` (doc 01), trechos da config térmica; nenhum script lê |
