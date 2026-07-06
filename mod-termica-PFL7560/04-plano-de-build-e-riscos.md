# 04 - Plano de build, riscos e recuperação

A meta é "nossa build": ventilação mais agressiva + brilho mais baixo + desligamento de segurança calibrado.
Abaixo, os caminhos de deploy do MENOS ao MAIS arriscado. Escolhemos o menos arriscado que resolve.

## Os 3 tiers de deploy

### Tier 1 - Runtime, não persistente (MAIS SEGURO, reversível, sem gravar nada)
Via `adb root` (se disponível), usar a HAL `cus` para, na sessão atual:
- ler NTCs ao vivo (`gtt`), forçar fans a 100% (`sfs 0 1000; sfs 1 1000`), reduzir brilho (`sbl ...`).
- Zero escrita em disco; reboot volta ao stock. **Risco: baixíssimo (não brica).**
- Limitação: reseta a cada boot; precisa reaplicar (ou achar um hook de autostart).
- **Uso primário: DIAGNOSTICO** — medir o efeito real de cada alavanca antes de fixar a build.

### Tier 2 - Edição persistente do `ZYCustom.ini` (RISCO MEDIO, sem reflash da imagem inteira)
Editar o arquivo de texto na partição `vendor` e reiniciar. Requer:
- `adb root` + `/vendor` remontável rw (ou `adb disable-verity` + `adb remount`, típico em build userdebug).
- **Bloqueio possível: dm-verity/AVB.** Se a `vendor` for verificada por verity, editar 1 byte quebra o hash e o boot falha
  -> seria preciso desabilitar verity (possível em userdebug). Se não há verity, é só remontar e editar.
- **Este é o alvo ideal:** muda só um `.ini`, efeito permanente, sem tocar no bootloader/assinatura.

### Tier 3 - Rebuild + reflash da imagem completa (MAIS ARRISCADO - "a build" de fato)
Reempacotar o `PFL7560.bin` com a `vendor` modificada e gravar via "Atualização local do sistema" (pendrive).
- **Bloqueio possível: assinatura/CRC do container `LOAD`** e verificação do updater on-device.
- **Brick real** se o container tiver checagem que não soubermos reproduzir, ou se o updater exigir assinatura.
- Só faz sentido se Tier 2 não for viável, e SOMENTE com caminho de recuperação confirmado.

## Viabilidade RESOLVIDA (workflow wq31yy1uy) - todos os gates verdes

1. **adb root: SIM, trivial, sem reflash.** Build `userdebug`, `ro.debuggable=1`, `persist.sys.usb.config=adb`,
   `ro.adb.secure` ausente (sem prompt RSA). adb-over-USB na porta **USB-C** (as USB-A são host-only) e
   adb-over-rede na **TCP 5555** (Ethernet prioritária). `adb root` -> uid 0. Detalhes/rotas no `06`.
2. **dm-verity/AVB em /vendor: NAO existe** (`fsmgr_flags="wait"` apenas; sem vbmeta). Editar o `.ini` NAO quebra o boot.
   O `.ini` é lido AO VIVO a cada boot (sem cache/versionamento). **Precedência:**
   `/atv/ini/ZYCustom_<projectid>.ini` -> `/atv/ini/ZYCustom.ini` -> `/vendor/etc/ZYCustom.ini` (o primeiro que existir vence).
   Há ainda API de runtime (`SetThermalPolicy`/`setFanSpeed`) via HIDL, e a velocidade de fan escolhida persiste em
   `/atv/db/ZYCustom.db` e é reaplicada no boot ("Restore Thermal Fan Speed").
3. **Container só-CRC, SEM assinatura.** É CRC-32/MPEG-2 (verificado byte-a-byte). Cada payload tem prefixo
   `[u32 size BE][u32 CRC BE]`. O updater "Atualização local do sistema" valida só checksum (chega a `source` scripts
   não assinados do pendrive). **Repack é viável.** Recuperação de brick: **UART bootrom do Hi3751** via HiTool/HiBurn
   ou OpenIPC/burn — sobrevive até bootloader apagada, se houver header UART na placa. Risco MODERATE, gerenciável.
4. **Comandos `cus`: via `/vendor/bin/hidebug`** (REPL stdin -> middleware). Tabela completa e receitas no `06`.

**Conclusão dos gates:** Tier 1 (runtime) e Tier 2 (override em `/atv`, reversível) são de risco baixo/nulo e já liberados.
Tier 3 (reflash) é viável e recuperável se só editarmos vendor/system e nunca a bootloader/recovery.

## Sequência segura (gates - não pular etapas)

1. **[GATE A] Recuperação primeiro.** Confirmar como desbrickar (Tier 3) OU confirmar que ficaremos em Tier 1/2
   (que não bricam). Sem isso, nada é gravado.
2. **[GATE B] Acesso.** Obter `adb root` (ou o método de acesso que a pesquisa indicar).
3. **[GATE C] Diagnóstico.** Rodar `gtt` em loop por ~15 min de uso real, registrando temperatura vs tempo, em 3 cenários:
   (a) stock; (b) fans forçados 100%; (c) brilho reduzido (~70-80%). Guardar os logs em `artefatos/diagnostico/`.
   Isso calibra os limiares reais (principalmente o de desligamento) e mostra o ganho de cada alavanca.
4. **[GATE D] Aplicar no menor tier viável.** Preferência: Tier 2 (editar `.ini`). Aplicar a proposta calibrada
   (ver `05-ZYCustom.ini-proposto.md`), reiniciar, e **medir de novo** o mesmo teste de 15 min.
5. **[GATE E] Validar e iterar.** Comparar antes/depois. Ajustar. Só considerar Tier 3 se for necessário e recuperável.

## Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Brick por reflash de imagem sem entender assinatura | Não fazer Tier 3 sem recuperação confirmada; preferir Tier 2. |
| Boot quebra por verity após editar `.ini` | Só editar se `disable-verity`/`remount` funcionar; ter backup do `.ini` original. |
| Nuisance shutdown (desligar no meio do filme) por limiar baixo demais | Calibrar `EMERGENCY_VALUE` com dados do `gtt`, não chute. |
| Imagem visivelmente escura demais | Ajustar teto de brilho de forma incremental (começar em ~85%). |
| Perda de garantia | Já assumida (troca de peças recorrente); documentar mesmo assim. |
| Scratchpad limpo perde extrações | Artefatos-chave já copiados para `artefatos/`. `PFL7560.bin` está no `.zip` original. |

## Backup obrigatório antes de qualquer escrita

- `ZYCustom.ini.ORIGINAL` já preservado em `artefatos/`.
- Antes de Tier 2/3, puxar via `adb pull` a `vendor` (ou ao menos o `.ini`) do próprio aparelho, para restaurar 1:1.
- Guardar o `PFL7560.bin` stock (o `.zip` original) como imagem de recuperação.
