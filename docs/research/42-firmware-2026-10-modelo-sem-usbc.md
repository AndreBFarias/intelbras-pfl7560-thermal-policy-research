# 42 - Firmware de 2026-10-20 ("a partir de 25/08/2026"): é o modelo sem USB-C, e a térmica não mudou

Gerado em 2026-10-29. O repositório não foi alterado. Nenhum binário do firmware foi executado. Todo o Python que leu esses dados rodou com `-I`. Única exceção: uma **cópia** do `build_fix_bin.py` do repo, no scratchpad e sem `-I`, para conseguir importar o `sparse.py` que estava ao lado (ver §2.3).

Abreviações de caminho usadas abaixo:

- `$A` = `(área de trabalho da análise)/analise`
- `$OLD` = `(área de trabalho da pesquisa do doc 41)/pesquisa-auto`
- NOVO = `.../fw-2026-10/zip/PFL7560.bin` (md5 `89f82720067779fdaae5fc51c1c1ea4e`, 1393802428 B)
- ANTIGO = `$OLD/fw/PFL7560.bin` (md5 `28a2f280eee313a4b115567926b2ba4f`, 1393758396 B)
- Scripts de análise em `.../fw-2026-10/scripts/` (`extract.py`, `brange.py`, `bootimg.py`, `zimg.py`, `cpio.py`, `elf.py`, `panel.py`, `zipdiff.py`, `chk1.py`, `reccrc.py`)

## Conferência (adversarial, 2026-10-30)

**Placar: 26 confirmados · 7 refutados · 10 acrescentados.** Nenhuma refutação muda as conclusões, que se mantêm:

- é outro SKU (NOTYPEC, V1.0.0.1, build de 08/08);
- a térmica é idêntica e o bug do mux continua;
- o painel 69 é idêntico e o índice continua 69;
- não há trava técnica, mas aplicar no aparelho do dono não é recomendado.

Método: refiz tudo de forma independente, com meus próprios parsers e sem usar os scripts nem os manifestos do analista.

- **Container:** reli a tabela LOAD nos dois `.bin`; calculei o CRC-32/MPEG-2 e o md5 de todos os 19 records e o checksum1.
- **Vendor e system:** reexpandi o vendor NOVO (md5 do raw bate com `new14.raw`) e o system NOVO a partir do `.bin`; extraí os dois lados com `debugfs rdump` e comparei a listagem completa: tipo, alvo de symlink, tamanho e md5, além de mode, uid/gid e `security.selinux` via `debugfs stat`/`ea_list`.
- **Painel, ELF e apps:** comparei byte a byte a panelparam e a deviceinfo, as seções ELF e as entradas dos APKs, e desmontei os apps que leem `custom.style`.
- **Builder:** rodei de novo o builder corrigido.

Usei Python sempre com `-I`. Nenhum binário do firmware foi executado. Os dados que extraí ficaram em `fw-2026-10/conferente/` (fora de `analise/`) e **já foram apagados**; ficaram só os scripts e as listagens.

**Confirmados (26).** Por grupo:

- **Identidade e builds:**
  1. identidade (§1: versão, data, projectname, update_url, fingerprint, `ro.build.date`, `recovery_id`);
  2. datas de kernel, U-Boot e ATF.
- **Container e builder:**
  3. checksum1 `0x738ebd09`/`0x0e15accc`, conferido;
  4. tabela com os 19 offsets, tamanhos e CRCs, e mudam exatamente os records 2, 3, 4, 7, 9, 10 e 13 a 18;
  5. o CRC do record 5 não confere da mesma forma nas duas versões;
  6. vendor em `0x4b0b1d54` → `0x4b0bc954`, com o mesmo tamanho de 80593044 B;
  7. o builder do repo lê o tamanho 3631910283 e o magic `0xdf6d12ea` e para no assert antes de gravar;
  8. o builder corrigido dá o CRC vendor `0xd47c4f60` e checksum1 OK. **Reproduzido**: os outros 18 records ficaram com md5 idêntico ao stock e o cabeçalho ficou byte-idêntico. O `.bin` de teste foi apagado.
- **Térmica:**
  9. `ZYCustom.ini` `29d8ba36` → `ed3f314c`, com o diff de 1 linha (`CONFIG_MODEL`);
  10. `HW_VIRTUAL_CHANNEL = 0` nos dois termistores (l.150 e l.171), `HW_LSADC_CHANNEL = 1`, `SW_CLASS = 3` e o mux `GPIO4_4`/`BL1551B`;
  11. a curva dos ventiladores, a escada de brilho, 43/45 °C, o typo `825. 925` e 0 chaves de sense;
  12. `libhitvservice.so` com o mesmo md5, `4ce86979`;
  13. `init.bigfish.rc` com o mesmo md5, xiriservice sem `disabled` e `wifi_disconnect_on_boot=1`;
  14. o diff do `/vendor/build.prop`, sem `zysys.typec_count` e `zysys.source.typec1` e com o `is_named_usb` só movido.
- **Bibliotecas e apps:**
  15. 10 arquivos mudados no vendor e 10 no system, nenhum adicionado nem removido (712 e 2435 entradas);
  16. `libhwui`, `busybox` e `adbd` só com build-id e datas;
  17. `HiTvService` só muda `volume_dialog_row_pt.xml` (e o reassinado com a mesma chave);
  18. `NLProvision` `2.11.30.00.23.16` → `.19`, com o fluxo PL no smali (com a correção abaixo).
- **Painel e deviceinfo:**
  19. panelparam com 83 → 87 perfis, sendo os 0 a 82 byte-idênticos;
  20. o perfil 69 com os mesmos valores (`bw = 1`, `fmt = 0`, link `[0,1,2,3]`, clk 134400000) e os perfis 83 a 86 como na tabela;
  21. `deviceinfo` byte-idêntica, com `0x45` em `+0x3000`.
- **Demais partições:**
  22. atv com conteúdo idêntico; securestore, log e cache só com `lost+found`; userdata com os mesmos 2 arquivos;
  23. `misc` idêntico (`--wipe_data`).
- **Câmera, datasheet, kit e boot:**
  24. `AutoFocus3` e `camera.bigfish.so` inalterados, e o datasheet de 14/05/2025 com "USB-C x1";
  25. as constantes do `pfl7560-fix.sh` (l.38-41) e o fallback para o artefato versionado;
  26. o ramdisk do boot só muda `file_contexts.bin`, e o da recovery muda os 4 arquivos citados.

**Refutados (7), todos de detalhe:**

- **R1, §5:** o contador de perfis da panelparam fica em `@0x58`, não em `@0x5a`.
- **R2, §3.6:** o fluxo PL não está em `onThermalWarningOverheat`. Ele roda só em erro de termistor, e o superaquecimento só ganhou texto novo de diálogo.
- **R3, §2.4:** a recovery tem 30915 trechos diferentes, não ~7700, e o deslocamento é de -0x54 no `.rodata`, antes do initramfs. A causa apontada (initramfs) está errada.
- **R4, §2.2:** o loader tem 19 B diferentes em 13 trechos, não 65 B.
- **R5, §4:** o `adbd` tem 26 B em 4 trechos, não 30 B em 3.
- **R6, §8:** o loader também tem `check_upgrd_partition_cfg` e uma leitura de projectid, mas as duas passam porque o mapa de flash e a `deviceinfo` são idênticos.
- **R7:** o datasheet não vem no zip. Além disso, no resumo do item 4 da mensagem do analista, "o system ganhou o /vendor/build.prop" deve ler-se: o **vendor** perdeu as 2 linhas de USB-C (o §3.5 está certo).

**Acrescentados (10).** Por grupo:

- **Metadados e arquivos:**
  - **A1.** Os metadados dos 712 itens do vendor e dos 2435 do system são idênticos: mode, uid/gid, contexto SELinux e alvos de symlink. Só mudam os tamanhos dos arquivos já citados. O system tem a mesma geometria: 471808 blocos e 118080 inodes.
  - **A2.** Nos 7 `rtl*.ko`, só mudam o build-id e `.rodata.str1.4`. Passam de INFERIDO a CONFIRMADO.
  - **A3.** O `sbin/recovery` tem `.text` idêntico, sem mudança de código.
- **`custom.style` e o fluxo PL:**
  - **A4.** O `NLScreenSaver` também lê `custom.style`. Ninguém grava essa prop nos apps desmontados. No aparelho real, o `getprop` não a tem, então o fluxo PL fica dormente.
- **Modelo e projeto:**
  - **A5.** `CONFIG_MODEL` só aparece no INI e na `libhitvservice.so`, que não tem nenhuma string `KJM…`/`INTELBRAS` para comparar. O modo térmico é escolhido por `THERMAL_MODE` (doc 34), que continua `0x1001`. Isso reforça que a troca de `CONFIG_MODEL` não muda a térmica (os símbolos `RunKJMFanMode` e `RunKJMBacklightMode` existem, mas pertencem ao modo `0x1003`).
  - **A6.** `ro.newlink.projectname` só é lido pelo `NewLinkService` (`MyServices`, que monta uma entidade junto com contadores de inicialização). Esse APK não mudou, e não encontrei nenhum desvio de comportamento por nome de projeto.
- **Container e risco do flash:**
  - **A7.** As 19 entradas da tabela têm o mesmo mapa de flash (`+0x00..0x13`), e só tamanho e offset mudam. O pendrive grava as mesmas partições nos mesmos endereços.
  - **A8.** A `deviceinfo` que o `.bin` grava traz projectid 390 em `+0x8000` e um bloco de PWM dos ventiladores em `+0x7000`, iguais aos do V1.0.0.9. Não é risco novo, mas o flash sobrescreve a `deviceinfo` inteira, inclusive o índice de painel 69.
  - **A9.** O kernel do boot também tem a nota GNU build-id alterada (`0xee3434`). O último perfil da panelparam (86 no NOVO, 82 no ANTIGO) tem 732 B, sem o pad de 36 B, o que confirma o formato "36 + 732".
- **Kit do repo:**
  - **A10.** O `RC_STOCK_MD5 = 0fe1b8fb` do `pfl7560-fix.sh` **não** casa com o `init.bigfish.rc` de nenhum dos dois `.bin` (`8f7e02b2`, que difere só pelo `\n` final). Num aparelho recém-flashado (com qualquer das duas versões), o kit cai no artefato versionado, e um `revert` regrava o arquivo com 1 byte a mais. É problema pré-existente do repo, não deste firmware. O analista viu o fato, mas não tirou a consequência.

---

**Conclusão em uma frase.** Isto **não é** uma versão mais nova do V1.0.0.9. É **outro SKU**, o `KJM_5H039_412_INTELBRAS_NOTYPEC_TP` (projetor **sem entrada USB-C**). Foi recompilado da mesma árvore em 2026-08-08, e a numeração recomeçou em `V1.0.0.1`. A térmica é **idêntica**: o bug do mux **não** foi corrigido.

---

## 1. Identidade

| Item | ANTIGO | NOVO | Fonte | Status |
|---|---|---|---|---|
| `ro.zhiying.version` | `V1.0.0.9` | **`V1.0.0.1`** | `/vendor/build.prop` (`$OLD/vendor/build.prop`, `$A/new_vendor/build.prop`) | CONFIRMADO |
| `ro.zhiying.date` | `2026-06-17` | `2026-08-08` | idem | CONFIRMADO |
| `ro.newlink.projectname` | `KJM_5H039_412_INTELBRAS_TP` | **`KJM_5H039_412_INTELBRAS_NOTYPEC_TP`** | idem | CONFIRMADO |
| `ro.zhiying.update_url` | `netupdate/KJM_5H039_412_INTELBRAS_TP_updateVer.xml` | `netupdate/KJM_5H039_412_INTELBRAS_NOTYPEC_TP_updateVer.xml` | idem | CONFIRMADO |
| `ro.zhiying.model` | `KJM_5H039_412` | `KJM_5H039_412` (igual) | idem | CONFIRMADO |
| `ro.build.fingerprint` | `HiDPT/Hi3751V553_32_DMO_2layer_1024M/Hi3751V553:9/PPR1.180610.011/eng.zhilin.20260617.153832:userdebug/dev-keys` | `.../eng.zhilin.20260808.153615:userdebug/dev-keys` | `/system/build.prop` (`$A/new_system/system/build.prop` l.42) | CONFIRMADO |
| `ro.build.display.id` | `NL5H00X-userdebug 9 PPR1.180610.011 eng.zhilin.20260617.153832 dev-keys` | `NL5H00X-userdebug 9 PPR1.180610.011 eng.zhilin.20260808.153615 dev-keys` | `/system/build.prop` l.6 | CONFIRMADO |
| `ro.build.date` | `Wed Jun 17 15:38:24 CST 2026` | `Sat Aug  8 15:36:04 CST 2026` | `/system/build.prop` l.16 | CONFIRMADO |
| Banner do kernel (boot, rec07) | `Linux version 4.9.127_s5 (zhilin@ubuntu18233) ... #4 SMP PREEMPT Wed Jun 17 15:56:40 CST 2026` | `... #4 SMP PREEMPT Sat Aug 8 16:00:02 CST 2026` | `$A/new_boot07/Image` @`0xa6513d` | CONFIRMADO |
| Banner do kernel (recovery, rec03) | `#2 ... Wed Jun 17 15:56:59 CST 2026` | `#2 ... Sat Aug 8 16:00:24 CST 2026` | `$A/new_boot03/Image` | CONFIRMADO |
| U-Boot / loader (rec02) | `U-Boot 2019.07 (Jun 17 2026 - 15:40:09 +0800)` | `U-Boot 2019.07 (Aug 08 2026 - 15:40:52 +0800)` | `$A/new_parts/rec02.img` @`0x86157` | CONFIRMADO |
| ATF (rec09) | `Built : 15:51:19, Jun 17 2026`, `v2.0(release):216de2395` | `Built : 15:54:18, Aug  8 2026`, mesmo hash `216de2395` | `rec09.img` @`0x5758` | CONFIRMADO |
| HiSilicon SDK | `HiDPTAndroidV600R001C00SPC070CP005` | igual (só mudam os "Build Time") | strings do `Image` | CONFIRMADO |
| Data do zip | — | `PFL7560.bin` de 2026-10-20 13:44 | `unzip -l` | CONFIRMADO |

O build é de **2026-08-08**. O zip de 2026-10-20 só empacota esse build. "A partir de 25/08/2026" é a data de fabricação do SKU novo, 17 dias depois do build (INFERIDO).

---

## 2. Container "LOAD"

### 2.1 Cabeçalho

- O magic `LOAD` e os campos `0x08..0x40` são idênticos, exceto `checksum1 @0x04` e o tamanho total `@0x10`. Fonte: dump do cabeçalho de 0x40 bytes dos dois arquivos. CONFIRMADO.
  - `checksum1`: ANTIGO `0x738ebd09`, NOVO `0x0e15accc`. O valor recalculado com CRC-32/MPEG-2 sobre `[0:0x2b4]` (com `[4:8]` zerado) é `0x0e15accc` e **confere** (`scripts/chk1.py`). CONFIRMADO.
  - Tamanho `@0x10`: `0x531310bc` contra `0x5313bcbc` (= 1393802428). CONFIRMADO.
- Rodapé `@0x2b8`: `d32118cd 3e1800ea` contra `2782e497 3e1800ea`. O doc 15 diz que o loader não lê esse campo. CONFIRMADO (byte) / INFERIDO (irrelevância).
- O CRC de cada record (prefixo `[size BE][crc BE]`) confere com CRC-32/MPEG-2 nos records 2, 4, 9, 11, 12 e 16 do NOVO (`scripts/reccrc.py`). CONFIRMADO.
  - Exceção: o record 5 tem o CRC armazenado `0xffac55ca`, mas o CRC do payload dá `0xe4773bba`. O mesmo valor fixo `0xffac55ca` aparece no ANTIGO, então não é novidade. INFERIDO: o loader não confere a `deviceinfo` ou usa um CRC parcial.

### 2.2 Tabela de records (tabela em `0x40`, 19 × 32 B; tamanho em `+0x14`, offset em `+0x18`)

Os nomes das partições foram deduzidos pelo conteúdo e pela ordem do `blkdevparts` em `rec00` (INFERIDO). Offsets, tamanhos e CRCs vêm da tabela (CONFIRMADO).

| # | Conteúdo | Offset ANTIGO → NOVO | Tamanho ANTIGO → NOVO | CRC ANTIGO → NOVO | O que mudou |
|---|---|---|---|---|---|
| 0 | bootargs (env) | `0x73df4` = | 65536 = | `3e4a2df0` = | nada |
| 1 | bootargsbak | `0x83dfc` = | 65536 = | `3e4a2df0` = | nada |
| 2 | U-Boot + loader (`Slave boot startup`, `hisi_file_verify_header`) | `0x93e04` = | 662008 = | `e14b6f95`→`04a5636b` | **só 65 B**, em 3 faixas (`0x86157`, `0x870a4`, `0x8e748`), todas strings de data/hora. **REFUTADO (só a contagem, conferência):** são **19 bytes** diferentes em 13 trechos, agrupados nessas 3 regiões; a natureza (só datas de build) está certa |
| 3 | recovery (kernel + ramdisk com `sbin/recovery`) | `0x135804` = | 19972096 = | `077292b4`→`2f27ce78` | rebuild, ver §2.4 |
| 4 | **panelparam** | `0x144180c` = | **63876→66948** | `fac81a75`→`b3ad9854` | **+4 perfis de painel** (§5) |
| 5 | deviceinfo | `0x1451198`→`0x1451d98` | 2097152 = | `ffac55ca` = | byte-idêntico |
| 6 | logo | `0x16511a0`→`0x1651da0` | 106496 = | `3c73288b` = | nada |
| 7 | boot (kernel + ramdisk normal) | `0x166b1a8`→`0x166bda8` | 9494528 = | `428a4f3d`→`5eaa6edb` | rebuild, ver §2.4 |
| 8 | dtbo (`SDK_VER!` + DTB) | `0x1f791b0`→`0x1f79db0` | 15200 = | `ad8de254` = | nada |
| 9 | atf | `0x1f7cd18`→`0x1f7d918` | 39496 = | `4c077aff`→`92d9781a` | 12 B em `0x5758` (data do build) |
| 10 | securestore (ext4 vazio) | `0x1f86768`→`0x1f87368` | 57492 = | `f8583d08`→`8e0e0a7e` | só metadados ext4 (UUID, hash seed, horários), 0 arquivos |
| 11 | misc (`boot-recovery` / `--wipe_data`) | `0x1f94804`→`0x1f95404` | 2064 = | `1d403398` = | nada |
| 12 | tconparam (`tcon.bin`) | `0x1f9501c`→`0x1f95c1c` | 64564 = | `fa0b4e6f` = | nada |
| 13 | **system** (sparse) | `0x1fa4c58`→`0x1fa5858` | 1225838836→**1225879796** (+40960) | `d97d1066`→`edffd9c3` | 10 arquivos (§7) |
| 14 | **vendor** (sparse) | **`0x4b0b1d54`→`0x4b0bc954`** | 80593044 = | `dd5cdc49`→`8ffbcd74` | 10 arquivos (§3, §4) |
| 15 | atv (ext4 raw, 50 MiB) | `0x4fd8ddf0`→`0x4fd989f0` | 52428800 = | `0a6fc4c0`→`508f79ce` | **os 80 arquivos são idênticos** (`$A/old_rec15.md5` = `$A/new_rec15.md5`), só metadados ext4 |
| 16 | log (ext4 vazio) | `0x52f8ddf8`→`0x52f989f8` | 69780 = | `184f47f5`→`7ab640eb` | só metadados ext4 |
| 17 | cache (ext4 vazio) | `0x52f9ee94`→`0x52fa9a94` | 82068 = | `318c0f4e`→`3cb60f29` | só metadados ext4 |
| 18 | userdata (sparse) | `0x52fb2f30`→`0x52fbdb30` | 1565060 = | `4e2c3165`→`90a7d1e2` | os mesmos 2 arquivos `nativetest/*`, mesmos md5 |

Os offsets andam **+0xc00** a partir do record 5 (a panelparam cresceu 3072 B = 4 perfis × 768) e **+0xac00** a partir do record 14 (somam-se os +40960 B do system). CONFIRMADO, pela aritmética da tabela.

### 2.3 O `build_fix_bin.py` do repo funciona com este stock?

- **Como está, NÃO.** O script fixa `PFX = 0x4b0b1d54` (`artifacts/bin-build/build_fix_bin.py`, l.26). No NOVO, o vendor está em `0x4b0bc954`.
  - Lido em `0x4b0b1d54` do NOVO, o "tamanho" vale 3631910283. O script lê até o fim do arquivo e o `sparse.parse` aborta com `AssertionError: magic 0xdf6d12ea nao e sparse`.
  - Testei uma cópia sem alteração no scratchpad, e ela falhou exatamente assim. CONFIRMADO.
  - A falha é **segura**: o script para antes de gravar qualquer `.bin` de saída.
- **Com o offset lido da tabela, SIM.** Testei uma cópia em `.../fw-2026-10/scripts/builder/build_fix_bin.py` que lê `PFX` de `0x40+32*14+0x18`. O repo não foi tocado.
  - Com o NOVO e `artifacts/ZYCustom_390.ini` (`252ab7a7`), ela gerou um `.bin` declarado VALIDO.
  - Metadados stock preservados nos 3 alvos: `ZYCustom.ini` e `init.bigfish.rc` com 0644 + `vendor_configs_file:s0`; `build.prop` com 0600 + `vendor_file:s0`.
  - Sparse pack com 80540020 B mais um pad de 53024 até 80593044. CRC do vendor novo `0xd47c4f60`. `checksum1` inalterado em `0x0e15accc`.
  - CONFIRMADO, só em software. Não houve teste de boot, e o `.bin` de teste foi apagado.
- Correção mínima sugerida (não aplicada): ler o offset do record 14 na tabela em vez de usar a constante.
  - Ressalva: o `ZYCustom_390.ini` leva `CONFIG_MODEL = KJM_5H039_412`. Num stock NOTYPEC, o certo é derivar a config do INI do próprio stock, trocando só as seções térmicas, para não rebaixar `CONFIG_MODEL` (INFERIDO, impacto provavelmente só de log, ver §3.4).

### 2.4 Kernel, recovery e ramdisks (rec03, rec07)

- **Boot (rec07).** Cabeçalho Android v0, kernel uImage `Linux-4.9.127_s5` (zImage ARM com gzip em `+0x40f3`), ramdisk embutido no kernel.
  - Imagem descomprimida: 18407424 B nas duas versões.
  - As diferenças são o banner (`0xa6513d`), strings `SDK_VERSION ... Build Time` (`0xd83668`...), três ponteiros de literal pool (`0x3ce4`, `0x4aa8`, `0x53b4`) que andam 1 byte porque `Jun 17` virou `Aug 8`, e o ramdisk comprimido (`0xf22a5e`+).
  - Ramdisk: 57 entradas, só `file_contexts.bin` muda (701 faixas de 28 B, provavelmente hashes/strings de build).
  - CONFIRMADO, por inspeção de bytes. "Código igual" é INFERIDO, porque não houve diff instrução a instrução.
- **Recovery (rec03).** Imagem de 28909568 B nas duas. Mudam 4 dos 262 arquivos do ramdisk:
  - `default.prop` (datas e fingerprint, `ro.expect.recovery_id` `0x14ed61...` → `0xea1c92...`);
  - `file_contexts.bin`;
  - `vendor/bin/busybox` (só a data de build);
  - `sbin/recovery` (1764912 → 1765064 B; as strings legíveis diferem só em `28.0.0 rc1-eng.zhilin.20260808.153615`).

  No código do kernel há ~7700 diferenças de 1 a 5 bytes. INFERIDO: deslocamento de endereços causado pelo initramfs gzip de tamanho diferente. Ver "O que não consegui verificar".

  **REFUTADO (conferência), contagem e causa.** Antes do initramfs (gzip em `0xf22a50` nas duas imagens) há **30915 trechos / 352281 B** diferentes, não ~7700. O padrão é de ponteiros de literal pool que andam **-0x54** para dentro do `.rodata`: por exemplo, `0xc0e2d963` vira `0xc0e2d90f`, e os dois apontam para a mesma string `id-sha256`. Esse `.rodata` (offset de arquivo ~`0xe25963`) fica **antes** do initramfs, então o tamanho do initramfs não explica o deslocamento. Algo no `.rodata` encolheu 0x54 B. Continua coerente com rebuild sem mudança de código, mas **não está provado**. O kernel do **boot** (rec07) não tem esse efeito: fora datas e banner, só muda também a nota GNU build-id em `0xee3434` (20 B), que o relatório não listou.
- `/system/bin/install-recovery.sh` e `/system/recovery-from-boot.p` mudam só nos SHA1/patch novos de boot e recovery. CONFIRMADO.

---

## 3. Térmica

### 3.1 `ZYCustom.ini`

- md5 NOVO: **`ed3f314ca89698cb057a74ef64dca38e`** (11899 B). ANTIGO: `29d8ba36149413e899563029df078f6d` (11878 B). Fonte: `$A/new_vendor/etc/ZYCustom.ini`. CONFIRMADO.
- **Diff completo: uma única linha**, a l.5 de `[Global]`: `CONFIG_MODEL = KJM_5H039_412;` → `CONFIG_MODEL = KJM_5H039_412_INTELBRAS_NOTYPEC_TP;`.
  - Prova: depois de remover `CONFIG_MODEL`, os dois arquivos são idênticos (`diff` vazio). CONFIRMADO.
- Nenhuma outra partição tem `ZYCustom*`. Busca por nome em `new_system`, `new_vendor` e `new_rec15` (atv): só `/vendor/etc/ZYCustom.ini`; `ZYCustomUI` e `ZYCustomer` são apps, não INI. CONFIRMADO.

### 3.2 O bug do mux dos termistores NÃO foi corrigido (CONFIRMADO)

`$A/new_vendor/etc/ZYCustom.ini`:

- `[Thermistor] SERIAL_NUM = 2;` (l.143)
- `[Thermistor_0]`: `HW_LSADC_CHANNEL = 1;`, **`HW_VIRTUAL_CHANNEL = 0;`** (l.150), `SW_CLASS = 3;` (MUX_NTC), `FW_NAME = ZL103SAF`
- `[Thermistor_1]`: `HW_LSADC_CHANNEL = 1;`, **`HW_VIRTUAL_CHANNEL = 0;`** (l.171), `SW_CLASS = 3;`
- `[Multiplexer]` (l.268-275): `HW_MUX_IN_GPIO_NUM = GPIO4_4`, `DEFAULT_SWITCH_DELAY_MS = 200`, `DEFAULT_SELECT_CHANNEL = 0`, `FW_NAME = BL1551B`, `FW_DRIVE_TABLE = 0b0, 0b1`

Os dois termistores continuam lendo o mesmo canal virtual 0, e o canal 1 do mux nunca é selecionado.

### 3.3 Demais seções: todas iguais ao V1.0.0.9 (CONFIRMADO, pelo diff de 1 linha)

- `[Thermal]` (l.78-86): `THERMAL_MODE = 0x1001`, `WARNING_VALUE = 43000`, `EMERGENCY_VALUE = 45000`, `DEFAULT_PROTECT = 2`, `DEFAULT_NOTIFY = 3`, `BACKLIGHT_EN = Y`.
- `[ThermalPolicy]` (l.115-131): `POLICY_0` e `POLICY_1` com `THRESHOLD = 25000, 27000, 29000, 31000, 33000, 35000, 36000` e `SPEED = 500, 575, 650, 725, 825, 925, 1000`.
- `[BacklightPolicy]` (l.88-100): `THRESHOLD = 27000 ... 36000` e `BRIGHTNESS = 1000, 950, 900, 850, 800, 750` nas duas políticas.
- `[CoolingFan_0]`: `FW_PWM_DUTY = 200, 350, 475, 600, 725, 850, 1000`.
- `[CoolingFan_1]`: `FW_PWM_DUTY = 325, 450, 575, 725, 875, 875, 1000`. O erro de digitação `FW_SPEED_CURVE = 500, 575, 650, 725, 825. 925, 1000` (ponto no lugar de vírgula, l.205) **continua lá**.
- Chaves `*SENSE*` do FanMonitor: **nenhuma**. `grep -aci sense` dá 0, e não há `SW_SENSE_TYPE` nem `HW_SENSE_*`. Continua como o doc 34 descreve: portão fechado, objeto de sense NULL.
- `libhitvservice.so` (que interpreta o INI, ThermalSense, FanSpeedSense) é **byte-idêntica**: md5 `4ce869799a82493799be61ff5d922be3` nas duas. CONFIRMADO.

### 3.4 `CONFIG_MODEL`

A única referência fora do INI está em `libhitvservice.so`: as strings `Global:CONFIG_MODEL` (`0x2a1377`) e `CONFIG_MODEL = %s` (`0x28e410`). INFERIDO: o valor só é lido e escrito em log, sem desvio de comportamento. Não segui as xrefs.

### 3.5 `init.bigfish.rc` e `build.prop`

- `/vendor/etc/init/hw/init.bigfish.rc` é **idêntico** (md5 `8f7e02b2f382ceed65cf058e56c0c302` nas duas). O `service xiriservice /system/bin/xiriservice` continua sem `disabled` (l.251-254). CONFIRMADO.
- `vendor.newlink.wifi_disconnect_on_boot=1` continua em `/vendor/build.prop` l.70. CONFIRMADO.
- Diff de `/vendor/build.prop` (md5 `fd8406c4...` → `f5b24c1db546dcfb4340f485bf841c8e`). CONFIRMADO:
  - datas e fingerprint;
  - **removidas** `zysys.typec_count=1` e `zysys.source.typec1=9`;
  - `vendor.newlink.is_named_usb=true` só mudou de lugar no arquivo;
  - `ro.zhiying.version`, `ro.zhiying.date`, `ro.newlink.projectname` e `ro.zhiying.update_url` conforme §1.

### 3.6 Mudança térmica na camada de app: `NLProvision.apk`

`/system/priv-app/NLProvision/NLProvision.apk` foi de `2.11.30.00.23.16` para `2.11.30.00.23.19`. Desmontagem com apktool em `$A/apk/{old,new}_NLProvision`. O `TempService` ganhou um fluxo "PL" (provavelmente power limit) para erro de termistor e superaquecimento. CONFIRMADO no smali:

- **Antes** (`TempService$16.smali`, `onThermalErrorThermistor(IILjava/lang/String;)`): se `vendor.newlink.setting.custom.style == 1`, mostra "设备温度过高，即将休眠保护" ("temperatura alta, vai hibernar") e dispara `mShutDownDiaThread` em 500 ms.
- **Agora** (`TempService$18.smali`, métodos `onThermalErrorThermistor` ×2 e `onThermalWarningOverheat`), se `vendor.newlink.setting.custom.style == 1`:
  - **REFUTADO em parte (conferência):** o fluxo PL (guardar o registrador, escrever `5`, timers de 180/600 s) está **só** em `onThermalErrorThermistor(IILjava/lang/String;)` e `onThermalErrorThermistor(ILjava/lang/String;)`. Em `onThermalInfoTemperature` fica só o cancelamento. `onThermalWarningOverheat` (as duas sobrecargas) **não lê** `custom.style` e chama as mesmas funções que antes, mudando só a alocação de registradores. A única mudança que chega a ele é o **texto** do diálogo em `QUtils.showTempDialog` no ramo `custom.style == 1`: antes "设备温度过高，即将休眠保护", agora "当前环境温度过高，机器已调整为低功耗模式…". Portanto o modo de baixo consumo é a resposta a **erro de termistor**, não a superaquecimento (WARNING).
  1. Guarda o registrador `REGISTER_ADDRESS_WORK_MODE` em `persist.nl.pl.temperr.status`.
  2. Escreve **`5`** nesse registrador, via `PictureQualityAdjustManager.writeDataForRegisterAddress`. INFERIDO: modo de baixo consumo.
  3. Mostra "当前环境温度过高，机器已调整为低功耗模式，请检查机器通风是否正常" ("ambiente quente, máquina em modo de baixo consumo, verifique a ventilação").
  4. Agenda `plThreeMinuteShutdownRunnable` para `vendor.newlink.thermal.shutdowntime` s (padrão `0xb4` = 180 s). Esse runnable mostra "当前机器温度过高，10秒后启动休眠模式" ("vai hibernar em 10 s") e chama `mShutDownDiaThread`.
  5. Agenda `plTenMinuteStatusRunnable` para `vendor.newlink.thermal.shutdowntime.one` s (padrão `0x258` = 600 s). Esse runnable restaura o modo salvo e zera a prop para `-1`.
  6. `onThermalInfoTemperature` cancela o runnable de 3 minutos ("PL three minute shutdown runnable cancelled").
  7. No boot, `MainActivity.initConfig` restaura o modo se a prop for `> 0` ("initConfig: reset workMode").
- **No PFL7560 isso está dormente** (INFERIDO). `vendor.newlink.setting.custom.style` não aparece em nenhum `build.prop`, `default.prop` ou `.rc` do firmware, e o padrão no código é 0.
  - A string aparece em `NewLinkService.apk`, `ZYSpeakerModel.vdex` e `NLSourcePlayer.vdex`, que não mudaram. Não verifiquei se algum deles grava a prop em tempo de execução.
  - **ACRESCENTADO (conferência):** a lista estava incompleta: o `NLScreenSaver.apk` também usa a prop (`MainActivity`, `ScreenService` e `PictureQualityAdjustManager`). Desmontei com apktool o `NewLinkService`, o `ZYSpeakerModel` e o `NLScreenSaver`, e todos os usos são **leitura** (`SystemProperties.get`/`getInt`); não há `set` dessa prop. Só o `NLSourcePlayer` (só vdex) ficou sem desmontar. Há também uma prova em tempo de execução: o `getprop` do aparelho real (`artifacts/diagnostico/audit-logs/getprop.txt`, V1.0.0.9) **não tem** `vendor.newlink.setting.custom.style`, com os mesmos apps de leitura. Conclusão: a prop está **ausente em tempo de execução no aparelho** (CONFIRMADO no V1.0.0.9). No NOVO, o fluxo PL dormente continua INFERIDO, mas agora com evidência forte.
  - O caminho padrão (sem `custom.style`) não mudou: `thermistor_error_tip` / `thermistor_error_shutdown`, toast e desligamento em 5 s.
- Os demais `.smali` diferentes são renumeração de classes internas e lambdas. Fora isso, `MainActivity` ganhou só `startBootFactoryVideo(Intent)`, que chama `com.newlink.service.activity.VideoActivity` (refatoração da abertura do vídeo de fábrica; INFERIDO).

---

## 4. Bibliotecas e binários de vendor e system que mudaram

Comparação por md5 de **todos** os arquivos: system 1927 arquivos e vendor 518, sem nenhum adicionado ou removido. Manifestos em `$A/{old,new}_{system,vendor}.md5`. CONFIRMADO.

| Arquivo | md5 ANTIGO → NOVO | Natureza (método) | Status |
|---|---|---|---|
| `/vendor/etc/ZYCustom.ini` | `29d8ba36` → `ed3f314c` | 1 linha (`CONFIG_MODEL`) | CONFIRMADO |
| `/vendor/build.prop` | `fd8406c4` → `f5b24c1d` | §3.5 | CONFIRMADO |
| `/vendor/bin/busybox` | `e46a0c7b` → `3c87ad3a` | só a data de build nas strings | CONFIRMADO |
| `/vendor/lib/modules/rtl8188gtv, rtl8723bu, rtl8723du, rtl8731au, rtl8821cu, rtl8822bu, rtl8822cu .ko` | todos diferentes | Seções `.text`, `.data`, `.rodata` e `.symtab` idênticas (md5 por seção, `scripts/elf.py`); mudam só `.note.gnu.build-id` e `.rodata.str1.4` (`__DATE__`/`__TIME__`). Verificado a fundo em 8188gtv e 8821cu; nos outros, INFERIDO pelo mesmo padrão. **Conferência:** md5 por seção nos **7** módulos, e em todos só mudam `.note.gnu.build-id` e `.rodata.str1.4` (`__TIME__`/`__DATE__`) | **CONFIRMADO** (os 7) |
| `/system/lib/libhwui.so` | `3341d448` → `52cf665b` | `.text`, `.rodata`, `.data`, `.dynsym` idênticas; mudam `build-id` e `.gnu_debugdata` (308520 → 307852 B); 4683 símbolos dinâmicos, 0 com tamanho alterado | CONFIRMADO |
| `/system/bin/adbd` | `b7b59b7f` → `fce3d6ee` | 30 bytes em 3 faixas: build-id e versão `28.0.0 rc1-eng.zhilin.20260808...`. **REFUTADO (só a contagem, conferência):** são 26 B em 4 trechos: build-id, versão (`.rodata`) e o CRC do `.gnu_debuglink`. A natureza está certa | CONFIRMADO |
| `/system/app/HiTvService/HiTvService.apk` | `3da90786` → `819b8ef2` | só `res/layout/volume_dialog_row_pt.xml`: o `SeekBar` passou a ter altura fixa de 16dip (`layout_height`, `minHeight`, `maxHeight`). Ajuste cosmético da barra de volume | CONFIRMADO |
| `/system/priv-app/NLProvision/*` (apk, odex, vdex) | — | §3.6 | CONFIRMADO |
| `/system/build.prop`, `/system/etc/prop.default`, `install-recovery.sh`, `recovery-from-boot.p` | — | datas, fingerprint, `recovery_id`, hashes | CONFIRMADO |

Não mudou nenhuma biblioteca de térmica, painel ou ventilador. Ficaram byte-idênticas: `libhitvservice.so` e o restante de `/vendor/lib` e `/system/lib` (tudo fora `libhwui.so`). Por isso não houve o que desmontar com capstone. CONFIRMADO.

---

## 5. Painel: panelparam (record 4)

Formato: cada perfil ocupa 768 B (cabeçalho `indexN` de 36 B + struct de 732 B). O nome fica em `168 + 768·k`, e o mesmo índice aparece no doc 28. Script: `scripts/panel.py`.

- ANTIGO: 63876 B, **83 perfis** (0-82). NOVO: 66948 B, **87 perfis** (0-86). CONFIRMADO.
- **Perfis 0-82: os 732 B são byte-idênticos** nas duas versões (nomes, `bit_width` em `0x4c`, `lvds_fmt` em `0x5c`, link map, timing). CONFIRMADO.
- **Perfil 69 sem mudança**: `RX058B_4300_5010E_1080P_M`, 1920×1080, `bw(0x4c)=1` (8BIT), `fmt(0x5c)=0` (VESA), link `[0,1,2,3]`, clk 134400000. CONFIRMADO.
- **Perfis novos**. CONFIRMADO (bytes); a interpretação de fornecedor e painel é INFERIDA:

| idx | Nome | Resolução | bw (0x4c) | lvds_fmt (0x5c) | link map | clk |
|---|---|---|---|---|---|---|
| 83 | `Z501080P_V02_AMC8603_1080P_ALLS_BL250` | 1920×1080 | 1 (8BIT) | 0 (VESA) | `[1,0,2,3]` | 134400000 |
| 84 | `Z501080P_V02_AMC8603_1080P_ALLS` | 1920×1080 | 1 | 0 | `[1,0,2,3]` | 134400000 |
| 85 | `Z501080P_V07_AMC8603_1080P_FM` | 1920×1080 | 1 | 0 | `[0,1,2,3]` | 134400000 |
| 86 | `C445XFH129D_FL5892_1080P_F` | 1920×1080 | 1 | 0 | `[0,1,2,3]` | 135600000 |

- Cabeçalho da panelparam:
  - tamanho total `@0x04`: `0xf984` → `0x10584`;
  - contador `@0x5a`: `0x53` (83) → `0x57` (87). **REFUTADO (offset, conferência):** o contador fica em **`@0x58`**, e em `0x56..0x57` está `5a 5a`. Logo, "campos `@0x54..0x59` sem mudança" também está errado, porque o `0x58` muda. Fora do cabeçalho, os dois payloads são idênticos em todo o comprimento comum (63876 B): só diferem os 5 bytes `0x05`, `0x06`, `0x58`, `0x81`, `0x82`;
  - tamanho do corpo `@0x80`: `0xf900` → `0x10500`;
  - campos `@0x4c`, `@0x50` e `@0x54..0x59` sem mudança.

  CONFIRMADO.
- **Índice padrão: sem mudança.** A `deviceinfo` (record 5, byte-idêntica entre as versões) tem `0x45` = **69** em `+0x3000`. CONFIRMADO (byte). INFERIDO: que esse é o campo lido por `hi_drv_custom_get_panel_index` (doc 41 §2); o valor casa com o perfil de fábrica.
- Leitura: os 4 perfis novos (controladores `AMC8603` e `FL5892`) sugerem fornecedores de painel adicionados para a produção nova. Mas o índice que vem no container continua sendo 69. Se as unidades novas usam outro painel, o índice é gravado na fábrica, fora deste `.bin` (INFERIDO).

---

## 6. Câmera, autofoco e OTA

- `AutoFocus3.apk` (`d30a2637...`), odex e vdex, além de `/vendor/lib/hw/camera.bigfish.so` (`0ff3a471...`): **idênticos**. CONFIRMADO.
- `NewLinkService.apk`, `RGTPLauncher.apk` e `ZYSetting.apk`: idênticos. CONFIRMADO.
- OTA: o código é o mesmo, mas o canal mudou. `ro.zhiying.update_url` agora aponta para `KJM_5H039_412_INTELBRAS_NOTYPEC_TP_updateVer.xml` (servidor `http://www.newlinksz.com/zyftp/ZYUpdate/default_5hxx/`, igual), e a versão local é `V1.0.0.1`. CONFIRMADO. O conteúdo dos XML no servidor não foi consultado.
- `misc` (record 11) continua com `boot-recovery` / `recovery` / `--wipe_data` / `--locale=en-US`. Isso é igual ao V1.0.0.9 (byte-idêntico). Ou seja, gravar o `.bin` também **apaga os dados do usuário** (INFERIDO pelo conteúdo; o comportamento é o do V1.0.0.9).

---

## 7. Apps e system: mudanças prováveis

- APKs: 66 nas duas versões, nenhum adicionado ou removido. Mudaram só `HiTvService.apk` (layout do volume) e `NLProvision.apk` (fluxo PL). CONFIRMADO.
- Changelog provável (INFERIDO):
  1. Novo SKU **sem USB-C**: `zysys.typec_count` e `zysys.source.typec1=9` removidos; nome de projeto e canal OTA `NOTYPEC`. Quem lê essas props: `RGTPLauncher.vdex`, `ZYSetting.vdex`, `NLSourcePlayer.vdex` e `HiTvService.vdex`, segundo um grep de strings. CONFIRMADO que contêm a string.
  2. 4 perfis de painel novos (§5).
  3. NLProvision: modo de baixo consumo antes de desligar por temperatura, só nos SKUs com `custom.style=1`.
  4. Barra de volume com altura fixa.
  5. Rebuild completo (kernel, U-Boot, ATF, módulos) **sem mudança funcional detectada**.

---

## 8. Compatibilidade: o que restringe a "fabricação a partir de 25/08/2026"

- **Não há trava técnica no container.**
  - Os campos do cabeçalho LOAD são os mesmos. CONFIRMADO.
  - O loader do record 2 é o mesmo binário; só strings de data mudaram (65 B). CONFIRMADO.
  - As strings do loader não mostram checagem de placa, produto, versão de hardware, DDR ou eMMC. Só `magic check failed` e `header crc mismatch`. INFERIDO, por strings e não por fluxo de controle.
    - **REFUTADO em parte (conferência):** além dessas, há `check_upgrd_partition_cfg(this)` e `custom_get_projectid` / `HI_DRV_PDM_GetDevInfo get projectid`. Elas não travam este caso, por dois motivos:
      - os bytes `0x00..0x13` de **todas** as 19 entradas da tabela (endereços e faixas de flash) são **idênticos** nas duas versões, então o mapa de partições é o mesmo;
      - a `deviceinfo` (byte-idêntica) carrega o projectid `0x186` = 390 em `+0x8000`, o mesmo do `androidboot.projectid=390` do aparelho.
  - DTBO idêntico, mesmo SDK, mesmos módulos.
  - Também não achei asserção de dispositivo no recovery, mas esse caminho não é o do pendrive.
- **A restrição é de SKU e de hardware externo.** A única diferença funcional ligada a hardware é a **ausência da entrada USB-C**. (**REFUTADO, detalhe, conferência:** o zip só tem `Firmware PFL7560/PFL7560.bin`; o datasheet é outro download.) O datasheet que acompanha o pacote (`Datasheet PFL7560.pdf`, criado em 2025-05-14) ainda lista "HDMI x2 / USB 2.0 x2 / USB-C x1". INFERIDO: a produção a partir de 25/08/2026 saiu sem USB-C, e o aviso existe para que donos de unidades com USB-C não percam a entrada.
- **Riscos concretos de aplicar no aparelho do dono** (placa NL-5H039-MAIN, painel RX058B-4300, perfil 69):
  1. **Perde a entrada USB-C no menu de fontes.** As props `zysys.typec_count` e `zysys.source.typec1` somem (INFERIDO; o hardware continua lá).
     - Daria para reverter recolocando as 2 linhas no `/vendor/build.prop` pelo método `/vendor` do repo. Não testado.
  2. **Canal OTA trocado e versão "menor"** (`V1.0.0.1` < `V1.0.0.9`). A partir daí o aparelho seguiria o canal NOTYPEC (INFERIDO). Voltar ao V1.0.0.9 por pendrive deve funcionar, porque o loader é o mesmo e não há anti-rollback visível. INFERIDO.
  3. **Apaga a correção térmica do /vendor e os dados do usuário.** O record 14 é regravado e o `misc` pede `--wipe_data`.
     - O kit `pfl7560-fix.sh` não reconheceria o INI stock: `INI_STOCK_MD5 = 29d8ba36` contra `ed3f314c`, e o mesmo vale para `BP_STOCK_MD5`.
     - Ele cairia no backup versionado do repo (V1.0.0.9). Um `revert` posterior regravaria o `build.prop` do V1.0.0.9, o que mistura SKU e canal OTA.
     - CONFIRMADO no código (`pfl7560-fix.sh` l.38-40 e `backup_stock` l.82-102). O efeito é INFERIDO.
  4. **Painel: risco igual ao do V1.0.0.9.** O perfil 69 é idêntico (`0x5c = 0`, VESA) e a deviceinfo traz o índice 69. Para o -4300 (VESA), que o doc 40 diz estar instalado agora, isso é inócuo. Para um painel JEIDA, o reflash desfaria o `0x5c = 1` (doc 41 §3). CONFIRMADO (bytes) / INFERIDO (efeito).
  5. **Risco de brick: baixo e igual ao do V1.0.0.9.** Mesmo kernel funcional, mesmo DTBO, mesmo U-Boot. INFERIDO.
- **O que se ganharia: praticamente nada.** A térmica é idêntica, a `libhitvservice` também, e o fluxo PL fica dormente sem `custom.style=1`. O ganho real é a barra de volume.

---

## Resumo para o dono

1. **Não é atualização do seu firmware.** É o firmware de outro modelo de produção, o `NOTYPEC` (sem USB-C), versão `V1.0.0.1` de 08/08/2026, compilado da mesma base do seu V1.0.0.9.
2. **A térmica é idêntica.** O `ZYCustom.ini` muda só o nome do modelo. O bug do mux (`HW_VIRTUAL_CHANNEL = 0` nos dois termistores), a curva dos ventiladores, a escada de brilho, 43/45 °C e o FanMonitor sem sense continuam iguais. A `libhitvservice.so` é byte-idêntica.
3. **No seu aparelho, você perderia a entrada USB-C no menu** e passaria para o canal de atualização do modelo sem USB-C, sem ganhar nada. Além disso, o pendrive apaga dados e a correção do /vendor. **Recomendação: não aplicar.**
4. **O painel não muda.** O perfil 69 (RX058B-4300, VESA) é idêntico e o índice gravado continua 69. A Intelbras só adicionou 4 perfis novos (83-86) para outros fornecedores.
5. **O builder do repo quebra com este `.bin`**, porque o offset do vendor mudou para `0x4b0bc954`. Ele falha de forma segura, por assert. Lendo o offset da tabela, o build funcionou em software. Vale corrigir isso antes de usar este stock em algum momento.

## O que não consegui verificar

- Diff instrução a instrução do kernel da recovery (rec03): ~7700 bytes diferentes, atribuídos (INFERIDO) ao deslocamento causado pelo initramfs de outro tamanho. Não reconstruí kallsyms para comparar função por função.
- O código de `sbin/recovery` (+152 B) além das strings. **Resolvido na conferência:** por md5 de seção ELF, o `.text` é idêntico. Mudam só `.gnu_debugdata` (114992 → 115144 B, os +152), `.note.gnu.build-id` e `.rodata` (string de versão). Não houve mudança de código.
- Os rtl*.ko além de 8188gtv e 8821cu foram checados só por md5 do arquivo; seção por seção, não. **Resolvido na conferência:** foram checados os 7, ver §4.
- Se `vendor.newlink.setting.custom.style` é gravada em tempo de execução por `NewLinkService`, `NLSourcePlayer` ou `ZYSpeakerModel`. Isso decide se o fluxo PL do NLProvision fica ativo no PFL7560.
- Que o byte `0x45` em `deviceinfo+0x3000` é o índice lido pelo bootloader. Casa com o 69, mas não segui `hi_drv_custom_get_panel_index` até esse offset. Também não sei por que o CRC armazenado do record 5 (`0xffac55ca`) não confere.
- Se o hardware USB-C (DP-alt) das unidades antigas continua funcional sem as props. E se a ausência de USB-C nas unidades novas é física, já que o datasheet de 2025 ainda lista USB-C.
- O conteúdo dos XML de OTA no servidor da Newlink (nenhum acesso de rede foi feito) e a regra de comparação de versão do cliente OTA.
- Boot real do `.bin` gerado pelo builder corrigido. O teste foi só em software, e o arquivo foi apagado.
- Observação à parte, fora do escopo: o artefato `artifacts/init.bigfish.rc.STOCK` do repo (md5 `0fe1b8fb`) difere do stock extraído (`8f7e02b2`, igual nas duas versões) só pela quebra de linha final.

---

## Lições para o nosso fix (2026-10-30)

O firmware novo serviu de gabarito da fabricante. O que ele ensina:

1. **O bug de fábrica continua em toda a linha.** O modelo novo sai com o mesmo `HW_VIRTUAL_CHANNEL = 0`
   nos dois termistores: a correção térmica do projeto vale também para os aparelhos fabricados a partir
   de 25/08/2026. Isso reforça o relato à Intelbras ([doc 11](11-email-intelbras.md)) e o
   [relatório CSIRT](../disclosure/relatorio-csirt.md): o defeito não foi corrigido em outubro.
2. **O kit precisa reconhecer os dois stocks.** O `ZYCustom.ini` de fábrica do modelo novo tem md5
   `ed3f314ca89698cb057a74ef64dca38e` (o antigo, `29d8ba36…`). Hoje o kit recusaria esse aparelho.
   Melhor que trocar o arquivo inteiro: **aplicar só as seções térmicas sobre o `.ini` do próprio
   aparelho**, preservando o `CONFIG_MODEL` (`KJM_5H039_412` ou `KJM_5H039_412_INTELBRAS_NOTYPEC_TP`).
3. **O builder do `.bin` deve ler o offset do vendor da tabela**, não usar `0x4b0b1d54` fixo; a cópia
   corrigida na análise gerou um `.bin` válido em software a partir do stock novo.
4. **O revert do `build.prop` não pode ser universal:** o do modelo novo não tem as linhas
   `zysys.typec*` e aponta para outro canal de OTA. Reverter com o `build.prop.STOCK` do V1.0.0.9 num
   aparelho novo daria a ele USB-C fantasma e o canal de atualização errado.
5. **Painéis:** os perfis 83 a 86 (`Z501080P_*_AMC8603`, `C445XFH129D_FL5892`) entram na matriz do
   [doc 33](33-matriz-paineis.md). Todos VESA, 8 bits; o perfil 69 é byte-idêntico.
6. **Higiene:** `artifacts/init.bigfish.rc.STOCK` difere do stock real só pela quebra de linha final.

Tarefas no [bloco 6](../sprints/2026-10-30-bloco-6-licoes-do-firmware-novo.md).
