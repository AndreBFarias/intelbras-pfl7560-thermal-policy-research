# Glossário

Uma linha por termo, com o doc que explica. Para o estado de cada pendência, veja o [`ESTADO.md`](ESTADO.md).

## Aparelho e firmware

| Termo | O que é | Doc |
|---|---|---|
| V1.0.0.9 / V1.0.0.1 | as duas versões de firmware: a do modelo **com** USB-C (`Software PFL7560.zip`) e a do modelo **sem** USB-C (`Firmware PFL7560.zip`, de 2026-10-20). Uma não serve no outro | [42](research/42-firmware-2026-10-modelo-sem-usbc.md) |
| NOTYPEC | o modelo sem USB-C (`KJM_5H039_412_INTELBRAS_NOTYPEC_TP`); sufixo dos arquivos de referência dele | [42](research/42-firmware-2026-10-modelo-sem-usbc.md) |
| `ZYCustom.ini` | `/vendor/etc/ZYCustom.ini`, o arquivo de texto com a política térmica (ventiladores, sensores, brilho, limiares) | [02](research/02-sistema-termico-atual.md) |
| `/vendor` | partição sem dm-verity onde ficam os 3 fixes; sobrevive a reset de fábrica | [26](research/26-persistencia-do-fix.md) |
| container LOAD | o formato do `.bin` de firmware (cabeçalho, 19 records, CRC-32/MPEG-2); o vendor é o record 14 | [15](research/15-bin-definitivo.md) |
| BIN-S4a / BIN-S4b | os dois gates de gravação do nosso `.bin`: o de 3 fixes nos blocos do stock e o completo, realocado | [47](research/47-build-completa.md) §11 |
| loader / power-hold | ligar segurando o power com `usb_update.bin` na raiz de um pendrive regrava o firmware; é o resgate | [guia 16](guide/16-recuperacao-brick.md) |
| `hidebug` | `/vendor/bin/hidebug`, console do fabricante que lê comandos do stdin (temperatura, brilho, foco) | [06](research/06-acesso-adb-e-comandos.md) |
| `gtt 0` / `gtt 1` | leitura dos dois sensores pelo `hidebug`. O `gtt1` (`zysys.env_temp`) é um NTC no topo do dissipador do LED, não na óptica | [37](research/37-mecanismo-lsadc-defasagem-dos-aneis.md), [40](research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3 |
| `optica_C` | nome antigo da coluna do `gtt1` nos logs; rótulo errado, ele mede o bloco do LED | [40](research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3 |
| LSADC | o conversor analógico-digital que lê os termistores; "LSADC Error" é leitura inválida | [35](research/35-sessao-2026-08-17-lsadc-espontaneo-e-pecas.md), [37](research/37-mecanismo-lsadc-defasagem-dos-aneis.md) |
| mux / `HW_VIRTUAL_CHANNEL` | o multiplexador que alterna os dois termistores no mesmo canal. De fábrica os dois estão no canal 0, então o 2º sensor nunca é lido: o defeito central | [08](research/08-por-que-fica-cego.md) |
| escada de brilho | `[BacklightPolicy]` da correção: o brilho desce de 1000 a 850 entre 66 e 70 °C e volta sozinho | [34](research/34-escada-brilho-e-fanmonitor.md) |
| FanMonitor | a proteção por ventilador travado do firmware; inarmável por software neste aparelho (ventiladores de 2 fios, sem tacômetro) | [34](research/34-escada-brilho-e-fanmonitor.md) |
| `gfc` | número de ventiladores que a política controla (2); o aparelho tem 3 | [07](research/07-hardware-upgrade.md) |
| `sbl` / `gbl` | grava / lê o nível de luz do LED pelo `hidebug` (o botão Luz da home usa os dois) | [44](research/44-suite-de-boot.md) §13 |
| `sbri` | brilho pelo `hidebug`; o firmware não deixa passar de 750 para baixo | [39](research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.2 |
| `gfd` / `gfdr` / `sfd` | lê a posição do motor de foco / lê a faixa / vai a uma posição | [44](research/44-suite-de-boot.md) §16, [46](research/46-foco-e-qualidade.md) |
| RRO | sobreposição de recursos do Android (Runtime Resource Overlay): pinta os apps do fabricante sem mexer neles | [48](research/48-tema-no-sistema.md) |

## Painel e cor

| Termo | O que é | Doc |
|---|---|---|
| `panelparam` | partição de 8 MiB com 83 perfis de painel de 768 bytes; o do aparelho é o 69 | [28](research/28-troca-painel-rx058b-diagnostico-cor.md) |
| byte `0x5c` | o byte do perfil 69 que guarda o formato LVDS: 0 = VESA, 1 = JEIDA | [28](research/28-troca-painel-rx058b-diagnostico-cor.md) |
| VESA / JEIDA | os dois formatos de bits do LVDS. Com o formato errado, as cores puras saem certas e os cinzas saem tingidos. Não se deduz do nome do painel | [33](research/33-matriz-paineis.md) |
| escada de 16 cinzas | a tela de teste de cor (níveis `10 + 15k`) que a câmera interna lê para decidir o formato | [41](research/41-auto-pareamento-camera-e-kit-universal.md) |
| `lvdsctl` | nosso binário que lê e grava o formato na `panelparam`, com backup | [`artifacts/lcd-color-fix/`](../artifacts/lcd-color-fix/README.md) |

## O que este projeto instala

| Termo | O que é | Doc |
|---|---|---|
| MeowCast | o nome do sistema: kit, suíte, home, tema e marca por cima do Android do fabricante | [README](../README.md) |
| kit | o conteúdo de `pendrive-autorun/`: roda sozinho quando o pendrive é plugado com o projetor ligado | [44](research/44-suite-de-boot.md) |
| suíte | a verificação automática (cor, câmera, ângulo, nitidez, foco, temperatura, resumo) | [44](research/44-suite-de-boot.md) |
| vigia | a parte da suíte que espera, no boot, o pedido do ícone e os sinais do descanso de tela | [44](research/44-suite-de-boot.md) |
| descanso | o descanso de tela MeowCast; põe a luz a 10 % enquanto está na tela e devolve o nível de antes | [44](research/44-suite-de-boot.md) §14 |
| `nl_tela` / `nl_camcheck` | os binários ARM que desenham as telas da suíte e leem a câmera | [`artifacts/`](../artifacts/README.md) |

## Prefixos de ID

| Prefixo | Assunto | Doc dono |
|---|---|---|
| OPT-S | óptica, ventiladores e sensor (`OPT-S5` a `S7`, `S13` fechados) | [39](research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §6, [40](research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) |
| LSADC-S | leituras inválidas do conversor dos sensores | [37](research/37-mecanismo-lsadc-defasagem-dos-aneis.md) §11 |
| FAN-S | proteção por ventilador travado | [34](research/34-escada-brilho-e-fanmonitor.md) |
| BIN-S | o `.bin` de firmware | [47](research/47-build-completa.md) |
| LCD-S | troca de painel e cor | [29](archive/29-roadmap-troca-lcd.md) (arquivado), [guia 32](guide/32-guia-troca-painel-lcd.md) |
| WARN-S | o antigo vigia de tela (sprint 19), hoje a suíte | [19](archive/19-sprint-warning-tela.md) (arquivado), [44](research/44-suite-de-boot.md) |
| REPO-S | higiene e publicação do repositório | [`disclosure/STATUS.md`](disclosure/STATUS.md) |
| INT-S | integridade dos arquivos byte-exatos | [34](research/34-escada-brilho-e-fanmonitor.md) |
