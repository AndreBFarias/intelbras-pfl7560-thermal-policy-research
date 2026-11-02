# 19 - Sprint: aviso na tela quando a correção NÃO estiver ativa

> **Arquivo histórico (ressalva de 2026-10-30).** O gate de viabilidade "exibir imagem por
> `am start ... VIEW`" foi **reaberto**: neste aparelho a via deu tela preta em 2026-09-03 (OPT-S13,
> [doc 39](../research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3). O hook em `/data/local/nlsu/`
> também não existe aqui (VIGIA-S1, [doc 34](../research/34-escada-brilho-e-fanmonitor.md)).

Status: **PLANEJADA (não executada)**. Desenvolve-se e valida-se **por adb, de forma reversível** — não
depende de nenhum flash. É pré-requisito da **distribuição** do `.bin` (sprint 18, gate BIN-S4b), não do
teste de boot (BIN-S4a).

## Objetivo

Mostrar um aviso VISÍVEL na tela do projetor, no boot, quando a correção térmica **não** estiver ativa
(alguém reverteu ou reflashou o stock e o `/vendor` voltou ao de fábrica), para o usuário não rodar o
aparelho superaquecendo sem perceber. Com a correção aplicada, **nenhum** aviso.

---

## STATUS (revisado 2026-07-12)

Dois pontos da spec original mudaram porque a sessão de 2026-07-10 (correção de cor LCD) já respondeu o
gate de viabilidade e revelou uma armadilha de ancoragem:

1. **O "como mostrar algo na tela sem app" JÁ ESTÁ RESOLVIDO.** O `pfl7560-lcd-color.sh` (L54-62)
   projeta uma imagem PNG na tela do projetor por shell puro:
   ```
   adb push X.png /sdcard/lcdtest.png
   am force-stop com.hisilicon.higallery
   am start -a android.intent.action.VIEW -d file:///sdcard/lcdtest.png -t image/png
   ```
   Isso foi usado e comprovado nos testes de cor. Portanto a WARN-S1 **não** precisa redescobrir o
   método nem cair no caminho APK por engano. Falta só validar o **disparo em contexto de boot**.
2. **O vigia NÃO pode morar no `init.bigfish.rc`.** O `./pfl7560-fix.sh revert` (L171-191) restaura o
   `init.bigfish.rc` **stock** a partir do backup — então um vigia ancorado como serviço **dentro** do
   `init.bigfish.rc` seria **apagado pelo próprio revert que deveria dispará-lo**. O proof-of-work
   "revert → aviso aparece" falharia por construção. **Solução: arquivo `.rc` NOVO e separado em
   `/vendor/etc/init/` (parse isolado, nunca tocado pelo revert).**

---

## Contexto técnico (o que já sabemos — não recomeçar do zero)

- **`cmd notification post` NÃO existe** neste Android 9 (testado: "Unknown command: post"). Toast por
  shell puro não sai de graça — por isso o caminho validado é `am start ... VIEW` de uma imagem PNG.
- **Método visual comprovado:** `am start -a android.intent.action.VIEW -d file://<png>` renderizado pelo
  `higallery` (ver STATUS acima). Este é o caminho da WARN-S2.
- **`/proc/msp/hifb0` é nó de CONTROLE, não superfície de desenho.** O firmware usa
  `echo hide/show > /proc/msp/hifb0` no `init.bigfish.rc` (linhas 363/366 do stock) para mostrar/esconder
  o overlay — **não** para escrever texto/pixels. Não trate o `hifb0` como framebuffer desenhável.
- **Marcador da correção:** `/vendor/etc/ZYCustom.ini` com `HW_VIRTUAL_CHANNEL = 1` (md5 `1ad641ed`).
  **Atenção:** os `.ini` são "Non-ISO extended-ASCII com terminador NEL" — o `grep` do vigia **precisa**
  do `-a` (senão o `grep` trata como binário e falha). O `pfl7560-fix.sh` já usa `grep -aE` por isso.
- O firmware roda scripts no boot (`nl_usb_update.sh` em `sys.boot_completed=1`; `update_after_boot.sh`
  em `/data/local/nlsu/`), e serviços podem ser declarados em `.rc` sob `/vendor` (persistente).
- A correção é permanente (`/vendor` sobrevive a reset de fábrica); só um **reflash total** a remove.

---

## DECISÃO DE ANCORAGEM (resolvida — não é mais paradoxo)

Onde o "vigia" (o que detecta a ausência do fix + mostra o aviso) deve morar?

**Decisão:** um **arquivo `.rc` novo em `/vendor/etc/init/pfl7560-warn.rc`** (mais o script/asset do
aviso em `/vendor`), com um serviço `oneshot` que roda no boot. Três razões:

1. **Sobrevive ao `revert`.** O `revert` restaura o `init.bigfish.rc` stock, mas não toca em arquivos
   `.rc` separados — o vigia continua lá e avisa que o fix sumiu. (Um serviço dentro do `init.bigfish.rc`
   seria apagado pelo revert.)
2. **Falha isolada.** Se o `.rc` do vigia tiver erro de parse, o dano fica contido nesse arquivo, sem
   arriscar o `init.bigfish.rc` boot-crítico.
3. **Cobertura.** Para o aparelho do dono (corrigido via `/vendor`), o vigia em `/vendor` cobre o caso
   realista: revert acidental. Um **reflash total** do stock apaga o `/vendor` inteiro (e o vigia junto)
   — esse caso só é 100% coberto quando o vigia vem **embarcado no `.bin` de distribuição** (sprint 18,
   BIN-S4b). Por isso a sprint 19 entrega o vigia como arquivo em `/vendor`, e a sprint 18 apenas o
   **embarca** no firmware. A sprint 19 **decide sozinha** a ancoragem; a 18 consome o resultado (sem
   ciclo — ver "Ordem" na sprint 18).

**Task 0 (verificação empírica, antes de tudo):** confirmar que o init desta build **varre**
`/vendor/etc/init/` e sobe serviços declarados lá.
```bash
# existe algum .rc em /vendor/etc/init/ que o init ja carrega?
adb -s <ip> shell 'ls -la /vendor/etc/init/ 2>/dev/null; ls -la /vendor/etc/init/hw/ 2>/dev/null'
# um servico de teste sobe? (crie um .rc trivial que so escreve num arquivo e cheque apos reboot)
```
**Proof-of-work da Task 0:** um `.rc` de teste em `/vendor/etc/init/` cujo serviço, após reboot, deixou
um rastro (ex.: um arquivo em `/data/local/tmp/`). Se o init **não** varrer esse diretório nesta build,
a ancoragem alternativa é declarar o serviço via um bloco adicional carregado por um `import` já
existente — **mas nunca editando o corpo do `init.bigfish.rc` que o revert restaura**; investigar um
`import /vendor/etc/init/*.rc` ou equivalente. Registrar o achado antes de prosseguir.

---

## Sub-sprints

### WARN-S1 — Viabilidade (gate JÁ RESOLVIDO; resta o disparo no boot)

> **GATE REABERTO em 2026-09-03.** A viabilidade dada como resolvida por `am start ... VIEW` **NAO se
> sustenta neste aparelho**: tres vias de exibicao de imagem por adb falharam e
> `pm resolve-activity -a android.intent.action.VIEW -t image/png` devolve `No activity found`.
> Ver [doc 39](../research/39-sessao-2026-09-02-optica-e-balanco-termico.md) §4.3 (OPT-S13).
> O vigia de tela precisa de outro mecanismo, ou de um APK proprio.

**O método visual está provado** (`am start ... VIEW`, ver STATUS). Resta apenas confirmar que dá para
**disparar no contexto de boot** (após `sys.boot_completed=1`, quando o `higallery` e o SurfaceFlinger
já estão de pé).

- Task: rodar o `am start ... VIEW <png>` a partir de um serviço `oneshot` que aguarda
  `sys.boot_completed=1` (property trigger no `.rc`), e confirmar que a imagem aparece.
- **Proof-of-work (runtime-real):** com o aparelho no launcher, um serviço/script disparado no boot faz a
  imagem de aviso aparecer na tela (confirmado por foto). Se por algum motivo o `am start` não funcionar
  cedo o suficiente, adicionar um pequeno atraso/espera pelo `higallery` — **não** partir para APK sem
  esgotar isso.

### WARN-S2 — Caminho shell (o principal)

Script de boot que checa o marcador e mostra o aviso se ausente.

- Task: script `/vendor/bin/pfl7560-warn.sh` (ou embutido no `.rc`) que faz:
  ```sh
  # marcador do fix; grep -a por causa do NEL/extended-ASCII nos .ini
  if ! grep -aq 'HW_VIRTUAL_CHANNEL = 1' /vendor/etc/ZYCustom.ini 2>/dev/null; then
      # fix AUSENTE -> mostra o aviso
      am start -a android.intent.action.VIEW -d file:///vendor/etc/pfl7560-warn.png -t image/png
  fi
  ```
  (Guardar a imagem do aviso em `/vendor` para não depender do `/data`, que é formatado no reflash.)
- Task: ancorar num serviço `oneshot` em **`/vendor/etc/init/pfl7560-warn.rc`** (arquivo novo — ver
  "Decisão de ancoragem"), com trigger `on property:sys.boot_completed=1`.
- **Proof-of-work (runtime-real, reversível, sem flash):**
  ```
  ./pfl7560-fix.sh revert  + reboot  ->  o aviso APARECE na tela
  ./pfl7560-fix.sh apply   + reboot  ->  o aviso SOME
  ```
  (Confirmar cada estado por foto.) Como o vigia mora em arquivo separado, o `revert` não o remove.

### WARN-S3 — Caminho APK (plano C, improvável)

Só se a WARN-S1/S2 provarem que shell não dá. **Menos preferido** por dois motivos duros:

- **Conflito com a invariante do projeto:** os métodos oficiais editam **apenas `/vendor`**
  ([`../../README.md`](../../README.md) e a política do projeto). Instalar app em `/system/app`
  violaria isso — se for por APK, restringir a **`/vendor/app`**.
- **Privilégio de plataforma indisponível:** assinar com dev-keys **não** dá privilégio de sistema (a
  chave de plataforma da fabricante não está disponível), então um overlay `TYPE_APPLICATION_OVERLAY`
  precisaria de `SYSTEM_ALERT_WINDOW` concedido via `appops` — passo extra e frágil.

Se inevitável: `BroadcastReceiver` de `BOOT_COMPLETED` lendo o marcador e mostrando `Toast`/overlay,
instalado em `/vendor/app`, com o grant de `SYSTEM_ALERT_WINDOW` via `appops set <pkg> SYSTEM_ALERT_WINDOW allow`.

### WARN-S4 — Texto, estilo e handoff para a sprint 18

- Definir o **texto do aviso** (ASCII puro, para não depender de fonte/acentuação na superfície do
  aparelho), ex.: `ATENCAO: correcao termica INATIVA - reaplique o pendrive de correcao`.
- Definir **estilo/tempo**: a imagem não pode atrapalhar a projeção normal — mostrar por alguns segundos
  no boot e sair, ou depender de o usuário fechar. Nunca cobrir a projeção permanentemente.
- **Handoff:** entregar à sprint 18 (BIN-S2b) a lista exata de arquivos novos do vigia
  (`/vendor/etc/init/pfl7560-warn.rc`, `/vendor/bin/pfl7560-warn.sh`, `/vendor/etc/pfl7560-warn.png`) com
  o metadado canônico de cada um (`.rc` e `.png`: `0644` + `vendor_configs_file`; `.sh`: `0755`), para
  que o `.bin` os embarque com rótulo/mode corretos (senão repete o brick).

---

## Critério de sucesso (mensurável)

Com o fix REMOVIDO (revert), o projetor mostra um aviso legível na tela no boot; com o fix aplicado,
nenhum aviso. O vigia não atrapalha o uso normal (projeção limpa quando tudo está ok). Todo o
desenvolvimento e validação são por adb, reversíveis, **sem** flash.

## Riscos

- **Editar o `init.bigfish.rc` para isto está PROIBIDO** — ele é boot-crítico e é restaurado pelo revert.
  O vigia mora em arquivo `.rc` separado (ver "Decisão de ancoragem").
- Overlay/imagem mal-dimensionada pode atrapalhar a projeção — usar timeout/saída automática.
- O marcador precisa de `grep -a` (arquivos `.ini` são extended-ASCII com NEL).

## Recuperação

**Correção da spec original:** a frase "qualquer serviço/app problemático se remove por adb" **só vale
enquanto o boot chegar ao launcher**. Se um `.rc` for corrompido a ponto de o init recusá-lo cedo, o
boot trava **sem adb** — e aí a única saída é o **power-hold + `usb_update.bin`** (que apaga o fix e
formata o `/data`). É exatamente por isso que:

1. o vigia mora em **arquivo separado** (falha isolada, não derruba o `init.bigfish.rc`); e
2. todo teste é **reversível por adb** e feito **com o kit de resgate à mão** (ver sprint 18,
   "Pré-requisito absoluto"), nunca às cegas.

Nada aqui toca no bootloader. Ver [`../guide/16-recuperacao-brick.md`](../guide/16-recuperacao-brick.md).
