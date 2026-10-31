# 01 - Teardown técnico do firmware PFL7560 V1.0.0.9

Fonte: `Software PFL7560.zip` -> `PFL7560.bin` (1.393.758.396 bytes, SHA-256 `8b99c33f...516698`).
Versão `V1.0.0.9`, build `2026-06-17` (confirmado em `ro.zhiying.version` / `ro.zhiying.date` e no banner do kernel).

## Identidade do hardware

| Item | Valor | Evidência |
|---|---|---|
| SoC | HiSilicon Hi3751 V553 (marca `HS352`), quad-core ARM Cortex-A53 em modo 32-bit, GPU Mali-450 | `ro.vendor.chip_name=HS352`; DTB `compatible="hisilicon,hi3751"` |
| Plataforma | "bigfish" (SDK HiSilicon de TV/projetor), Android 9 (HiDPT) | `ro.board.platform=bigfish`; fingerprint `Hi3751V553...:9` |
| Kernel | Linux 4.9.127 (`4.9.127_s5`), compilado 2026-06-17 15:56 | banner `Linux version 4.9.127_s5 ... Jun 17 ... 2026` |
| ODM / projeto | Newlink; device `NL5H00X`; projeto `KJM_5H039_412_INTELBRAS_TP` | `ro.product.brand=Newlink` |
| Tipo de build | `eng ... userdebug / dev-keys` (build de engenharia, depurável) | fingerprint - relevante para adb/root |

Observação sobre motor óptico: o datasheet Intelbras diz **LCD TFT** (tem polarizador, coerente com a falha relatada).
O firmware, por ser da plataforma genérica "bigfish", também carrega chaves de DLP/DMD (`zysys.dlp_setting=2`).
Não dá para cravar o motor óptico só pelo firmware; adotamos **LCD** conforme a especificação oficial.

## Formato do container `.bin`

Container proprietário big-endian com magic `LOAD` em `0x00`. Em `0x10` fica o tamanho total
(`0x531310BC` = 1.393.758.396, confere). A partir de `0x40` há uma tabela de partições (registros de 32 bytes:
`flashOffset@+8`, `size@+0x14`, `fileOffset@+0x18`). 19 registros. As maiores:

| idx | flashOffset | tamanho | conteúdo |
|---|---|---|---|
| 3 | 0x00c00000 | ~19,9 MB | boot image (kernel uImage) |
| 7 | 0x06600000 | ~9,5 MB | recovery image |
| 8 | 0x08e00000 | ~15 KB | **DTB (device tree)** |
| 13 | 0x10900000 | ~1169 MB | **super** (Android-sparse -> ext4 `/` 1,8 GB, inclui `/system`) |
| 14 | 0x84000000 | ~77 MB | **vendor** (Android-sparse -> ext4 `vendor`, contém `ZYCustom.ini`) |
| 15/16/17/18 | ... | log / cache / securestore / userdata | |

Integridade do container: há campos tipo-CRC no footer da tabela (ex.: `d321 18cd` / `3e18 00ea` ~`0x2b0`).
Se são CRC32 simples ou assinatura criptográfica está sendo determinado na pesquisa de viabilidade (workflow em curso).
**Isso decide se dá para reempacotar uma imagem modificada.**

## Como o firmware foi aberto (trilha de RE)

Ferramentas presentes: `debugfs`, `unsquashfs`, `7z`, `xz`, `gzip`, `cpio`, `python3`, `objdump`, `readelf`, `strings`.
Ausentes (contornados): `binwalk`, `dtc`, `simg2img`, `lz4`.

1. **DTB**: carve em `0x01f793b8` (14.688 B) -> parser FDT próprio em Python -> `artifacts/firmware-extraido/full_dts.txt`.
   Resultado: o DTB NAO tem framework thermal (zero `thermal-zones`, `pwm-fan`, `tsadc`, `cooling-maps`).
2. **Kernel**: boot images `ANDROID!` -> payload uImage (`27051956`) -> zImage -> `vmlinux` gzip -> `strings`.
   Kernel 4.9.127; driver de throttling de CPU `hi3751-cpufreq` (mexe em tensão/clock por temperatura da CPU);
   **sem** framework thermal do Linux, **sem** driver de fan (`pwm-fan`), **sem** `cpufreq-cooling`, **sem** TSHUT/OTP impresso.
3. **Rootfs**: os 8 "hsqs" eram falsos-positivos (não há squashfs). As partições são **ext4 dentro de containers Android-sparse**.
   Escrevi um decoder de sparse em Python, de-sparsei `super` e `vendor`, extraí com `7z`/`debugfs`.
   Achado central: toda a lógica térmica está em `/vendor/etc/ZYCustom.ini` + `/vendor/lib/libhitvservice.so`.

## Onde vive o controle térmico (3 camadas)

1. **Config (texto):** `/vendor/etc/ZYCustom.ini` — curvas de fan, dimming, limiares de proteção. **É o que vamos editar.**
2. **HAL nativo:** `/vendor/lib/libhitvservice.so` (classes C++ `ZYThermalManager`, `Thermistor`, `CoolingFan`, `Backlight`),
   dentro do serviço `vendor.hisilicon.hardware.hwtvmw@1.0-service`. Lê NTC via `HI_UNF_LSADC_GetValue` (`/dev/hi_lsadc`),
   dirige fans/luz via `HI_UNF_PWM_*`, e aplica proteção (`RunProtect` -> `HiSystem::Shutdown`).
3. **Java:** `NewLinkService` + `PowerService` (eventos de UI: `onThermalWarningOverheat`, `Get/SetThermalPolicy`).

Detalhes dos valores atuais: ver `02-sistema-termico-atual.md`.
