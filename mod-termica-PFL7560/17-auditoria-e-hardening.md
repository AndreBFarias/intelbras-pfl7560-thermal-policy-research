# 17 - Auditoria adversarial e hardening das soluções de entrega

Data: 2026-07-06. Antes de tratar a correção como "distribuível", submetemos as **soluções de entrega** (o
autorun por pendrive e o `pfl7560-fix.sh`) a uma auditoria adversarial. Objetivo: achar todo caminho de brick,
de perda de recuperabilidade e de **falso-sucesso** (declarar "APLICADO" sem ter aplicado). Este doc registra o
método, o veredito e os 15 achados confirmados com sua correção — para que a lição de engenharia de entrega
**não se perca**.

## O método

- **28 agentes** varrendo **4 dimensões** independentes: (1) a config (`ZYCustom.ini`), (2) o autorun
  (`newlink_update.sh`), (3) o `pfl7560-fix.sh`, e (4) segurança/recuperação (backup, revert, brick, docs).
- **Cada achado foi verificado de forma independente** para refutar falso-positivo: um achado só entra na lista
  depois de um segundo agente reproduzir/confirmar o defeito no código ou na doc reais. Suspeitas que não se
  sustentaram foram descartadas (ver o caso da config abaixo).

## Veredito

**A CONFIG térmica está perfeita e segura.** O `ZYCustom.ini` bate **byte-a-byte** com o spec (md5
`1ad641ed`), com **zero mudanças colaterais** — só os parâmetros pretendidos (2º sensor, fans, brilho,
shutdown) mudaram em relação ao stock. A suspeita das "**3 linhas de `DEFAULT_PWM_DUTY`**" (medo de ter mexido
numa curva a mais) foi **refutada**: a 3ª ocorrência é do bloco `[Backlight]`, que **já vinha `=1000` no
stock** — não é mudança nossa. Ou seja, a parte científica do fix passou.

**O problema estava na engenharia de entrega e na documentação**, não na física da correção. As duas soluções
de entrega tinham defeitos que as tornavam não-confiáveis para terceiros: documentação dessincronizada (que
podia levar a um brick), recuperabilidade frágil (backups que podiam "envenenar-se") e aplicação-parcial
silenciosa (wifi/xiri falhando sem log, com mensagem de "SUCESSO" mentirosa). A boa notícia: o **fix térmico
crítico já era fail-safe** em ambas as soluções — se a gravação do `.ini` falha, não há reboot nem
falso-sucesso do térmico —, então os scripts nunca ofereceram risco de brick térmico; o único caminho de brick
era o `.bin` documentado erroneamente.

## Os 15 achados confirmados (e como foram corrigidos)

### Crítico (1)

1. **Doc mandava flashar o `.bin` que brica.** README (Método 4) e a doc15 instruíam flashar o
   `PFL7560-FIX.bin`, que a doc16 (mais recente, e na época sequer commitada) registra como causador de brick
   por falta de rótulo SELinux. **Correção:** sincronizar toda a documentação antes de qualquer publicação — o
   Método 4 do README virou um **aviso de quarentena**, a doc15 foi rotulada como quarentena, o índice foi
   corrigido, a **doc16 foi commitada**, e o binário foi **posto em quarentena** (renomeado para
   `firmware/PFL7560-FIX.NAO-USAR-brica-SELinux.bin`) até os rótulos SELinux serem corrigidos e testados em
   hardware.

### Alto (2)

2. **Backup sem anti-envenenamento (envenenamento do stock).** O autorun não salvava o stock; e o 1º backup do
   `fix.sh` podia capturar arquivos **já modificados** como `.STOCK` — fazendo o `revert` restaurar a versão
   modificada silenciosamente. **Correção:** no autorun, salvar o stock **uma vez** antes de sobrescrever cada
   arquivo (`[ -f ....STOCK ] || cp ...`); no `fix.sh`, validar que o `ZYCustom.ini` puxado tem o **md5 do
   stock conhecido** (`29d8ba36`) antes de confiar no backup, recusando/abortando se divergir.
3. **Doc12 ensinava um revert obsoleto e errado.** A referência de segurança linkada pelo README mandava
   reverter por `/atv/ini/ZYCustom_390.ini` — caminho que **não reverte nada** no método `/vendor`.
   **Correção:** reescrever a doc12 alinhada ao `/vendor` (revert correto = `./pfl7560-fix.sh revert`, que
   restaura `backups-projetor/*.STOCK`), remover toda referência a `/atv/ini/...`, e corrigir o cenário do
   reset de fábrica (a correção em `/vendor` **sobrevive** ao reset — o reset não reverte ao stock).

### Médio (7)

4. **`apply` gravava `/vendor` sem garantir backup válido do stock.** Dois applies com um pull transiente
   falho podiam "envenenar" o backup. **Correção:** tornar o backup **fatal e validado** antes de tocar no
   `/vendor` (exigir arquivo não-vazio com `-s`, abortar em falha; recusar salvar como `.STOCK` qualquer
   `ZYCustom.ini` cujo md5 == `1ad641ed`, que é a versão já aplicada).
5. **`apply` declarava "APLICADO" e reiniciava sem reler wifi/xiri.** Falso-sucesso de aplicação parcial.
   **Correção:** após cada fix, **reler do device e validar** antes de declarar sucesso/reiniciar
   (`grep -q wifi_disconnect_on_boot=0` e `xiriservice ... disabled`); só imprimir APLICADO com os 3
   confirmados. Bug adjacente corrigido junto: se o pull do `init.bigfish.rc` falhasse, o `else` empurrava um
   RC **vazio** por cima do original (podia impedir o boot) — agora há guard `[ -s "$tmp" ]` antes do push.
6. **`revert` só verificava o backup do `.ini`.** Faltando `build.prop.STOCK` ou `init.bigfish.rc.STOCK`,
   restaurava parcialmente e ainda reportava "REVERTIDO ao /vendor de fábrica". **Correção:** exigir que os
   **três** `.STOCK` existam e sejam não-vazios (`-s`) antes de reverter, abortando com erro claro se algum
   faltar; verificar o retorno de cada `push`.
7. **Autorun: idempotência só testava o marcador térmico.** O early-exit olhava só `HW_VIRTUAL_CHANNEL=1`;
   uma falha parcial em wifi/xiri nunca era re-tentada, e ainda imprimia "SUCESSO". **Correção:** checar os
   **três** estados-alvo (`HW_VIRTUAL_CHANNEL=1` **e** `wifi_disconnect_on_boot=0` **e** `xiriservice
   disabled`); considerar "aplicado" só com os três ok, reaplicando o que faltar a cada boot.
8. **Falhas dos `sed` (wifi/xiri) eram silenciosas.** `fix1` tinha ramo de erro; `fix2`/`fix3` não.
   **Correção:** adicionar ramo `else` com `LOG '[ERRO]'` e um contador `FAIL`; só logar "SUCESSO" quando
   `CHG=1` **e** `FAIL=0`, senão "[PARCIAL] N fix(es) falharam — reexecute o pendrive".
9. **Risco de reboot-loop.** O reboot era condicionado ao sucesso do `cp`, sem verificar que o destino passou
   a conter o marcador (dispararia se um `.ini` errado/stock fosse copiado). **Correção:** após o `cp`,
   verificar explicitamente que `/vendor/etc/ZYCustom.ini` contém `HW_VIRTUAL_CHANNEL = 1` **antes** de setar
   `CHG=1`; senão logar erro e **não** reiniciar.
10. **Doc16/LEIA-ME não avisava do efeito destrutivo do resgate.** O power-hold com `usb_update.bin` reflasha
    o stock, apaga o fix e formata o `/data`. **Correção:** avisar que o pendrive de resgate deve ficar
    **fisicamente separado** e desconectado no uso normal, que o power-hold reflasha o stock (apaga fix +
    `/data`), e que `usb_update.bin` deve **sempre** ser o firmware de fábrica (nunca renomear o `.bin` da
    correção, que bricaria via power-hold).

### Baixo (5)

11. **Retorno do remount rw de `/vendor` (autorun) não era verificado.** Mensagem final enganosa ("arquivos
    ausentes?") quando a causa era read-only. **Correção:** `if ! mount -o rw,remount /vendor; then LOG '[ERRO]
    não remontei rw...'; exit 1; fi` e corrigir a mensagem final.
12. **Autorun remontava `/vendor` rw antes de checar a presença do `.ini`.** No abort, `/vendor` ficava
    gravável. **Correção:** validar a existência de `$MP/ZYCustom.ini` e do mountpoint **antes** do remount, ou
    `trap 'mount -o ro,remount /vendor' EXIT` para restaurar read-only ao abortar.
13. **`fix.sh`: push do `.ini` não era atômico nem tinha rollback.** Uma queda de adb no meio do push deixava
    o `ZYCustom.ini` truncado no `/vendor`. **Correção:** push para `$INI.new`, validar o md5 do temporário e
    só então `mv` atômico + `chmod`; em md5 divergente, `rm $INI.new` sem tocar no original. Mesma correção
    para o `init.bigfish.rc` e para os pushes do revert.
14. **`fix.sh`: a trava de modelo/IP usava `exit 1` preso no subshell `$(...)`.** Não abortava
    `apply`/`status`/`revert` cedo. **Correção:** `d="$(connect)" || exit 1` nas três funções + validar
    `[ -n "$d" ] || exit 1` antes de prosseguir.
15. **`menu.sh` opção 3: precedência `||`/`&&` imprimia "cancelado" mesmo com o revert rodando.**
    **Correção:** trocar por `if` explícito (`if [ "$c" = s ] || [ "$c" = S ]; then "$FIX" revert; else echo
    ' cancelado.'; fi`).

## Os princípios de engenharia de entrega (a parte que não se perde)

Cada achado acima é uma instância de um princípio geral. Estes são os invariantes que passaram a reger os
scripts de entrega:

1. **Nunca declarar sucesso sem RE-LER o estado do device/arquivo.** "Executei o comando" ≠ "o estado mudou".
   Sucesso é `grep` no arquivo real depois de escrever, não o retorno do `sed`.
2. **Idempotência por-fix.** Cada um dos 3 fixes tem **seu próprio teste de estado** (não um marcador único).
   O que já está aplicado é pulado; o que falta é reaplicado — a cada boot, sem duplicar.
3. **Backups validados por md5 contra o stock conhecido (anti-envenenamento).** Um `.STOCK` só é aceito se
   casar com o md5 de fábrica (`29d8ba36`); nunca se salva como stock um arquivo já modificado (`1ad641ed`).
4. **Gravações atômicas** (`.new` → confere md5 → `mv`). Nada meio-escrito sobrevive a uma queda; o original
   fica intacto até o novo estar validado.
5. **Nunca sobrescrever um arquivo de init com conteúdo vazio** (boot-crítico). Guard `[ -s ... ]` antes de
   qualquer push/mv sobre `init.bigfish.rc`.
6. **O fix térmico crítico é fail-safe.** Se a gravação do `ZYCustom.ini` falha: sem marcador, sem reboot, sem
   falso-sucesso. Nenhum caminho de falha deixa o aparelho pior do que estava.

## Resultado

Os **15 achados foram endereçados**. As duas soluções de entrega — o autorun por pendrive e o
`pfl7560-fix.sh` — estão **robustas para distribuição**. O único caminho de brick que restava (o `.bin`) foi
posto em quarentena; o plano para trazê-lo de volta com segurança está em
[`18-sprint-bin-futuro.md`](18-sprint-bin-futuro.md).
