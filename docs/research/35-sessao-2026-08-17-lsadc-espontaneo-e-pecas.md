# 35 - Sessão 2026-08-17: a proteção cega no meio do uso

Sessão de diagnóstico ao vivo com o aparelho ligado (adb Wi-Fi, `94.140.14.52:5555`), motivada por três
queixas do dono: a película polarizada voltou a queimar, apareceu artefato/faixas na imagem, e a
impressão de que a resolução caiu.

**Resumo em uma frase:** nada da correção se perdeu — todos os fixes estão aplicados e ativos —, mas a
proteção térmica **cegou durante a sessão** (`LSADC Error`), e a evidência disponível aponta para a
**sondagem externa por `hidebug` como gatilho**, não para defeito elétrico.

> **Revisado em 2026-08-18** após auditoria adversarial que confrontou cada afirmação contra os arquivos
> brutos. Sete correções numéricas e cinco afirmações refutadas. A seção 7 registra o que foi perdido
> por falha de método. Lista de compras: [`../guide/36-lista-de-compras-reparo-optico.md`](../guide/36-lista-de-compras-reparo-optico.md).

---

## 1. Estado verificado (o que NÃO está quebrado)

Tudo abaixo tem artefato em `evidencias/diagnostico-2026-08-17/`.

| Item | Estado | Evidência |
|---|---|---|
| `ZYCustom.ini` em `/vendor` | correto | `md5-vendor.txt`: `252ab7a72a007a8b79b3fc86bd5c0d19` |
| Mux dos termistores | destravado | `chaves-ini.txt`: `HW_VIRTUAL_CHANNEL = 0` e `= 1`; sensores leem valores distintos |
| Fans | 100% | `hidebug-01.txt`: `gfs 0`/`gfs 1` = `1000`; log `bAbnormal=0` |
| Escada de brilho | armada | `chaves-ini.txt`: `POLICY_0_THRESHOLD = 66000..73000`, `BRIGHTNESS = 1000..850` |
| Wi-Fi | corrigido | `wifi-xiri.txt`: `vendor.newlink.wifi_disconnect_on_boot=0` |
| `xiriservice` | silenciado | `wifi-xiri.txt`: `disabled` no `.rc`; `pos-reboot/artefatos-ausentes.txt`: `init.svc.xiriservice` vazio |
| `/atv/ini/ZYCustom.ini` | **não existe** | `atv-ini.txt`: só `aq.ini`, `cfg.ini`, `db.ini`, `db_44.ini`, `programlist1/2.ini` |
| Cor LCD (JEIDA) | ativa, persistente | `pos-reboot/proc-panel-pos-reboot.txt`: `lvds_fmt: jeida` **após o reboot desta sessão**. Desde a 2ª troca de LCD (2026-10-29) o aparelho está em **VESA** ([doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §1) |
| Resolução | 1080p, modo único | `pos-reboot/display-modos.txt`: `supportedModes [{id=1, 1920x1080, 60.000004 fps}]` |

### 1.1. A persistência do JEIDA é NATIVA (corrige registro anterior)

```bash
adb shell 'dd if=/dev/block/by-name/panelparam bs=1 \
  skip=$((168 + 69*768 + 0x5c)) count=1 2>/dev/null | od -An -tu1'   # -> 1
```

Artefato: `pos-reboot/panelparam-byte5c.txt`. O byte `0x5c` do perfil 69 está gravado com `1` (JEIDA). O
**boot service intermediário foi removido**: `/vendor/bin/nl_lvds.sh` e `/vendor/etc/init/nl_lvds.rc`
não existem (artefato: `pos-reboot/artefatos-ausentes.txt`); sobrou apenas o binário
`/vendor/bin/nl_lvdsctl`, ferramenta de teste ao vivo. Confirma que a cor persiste na própria `panelparam`, sem serviço de boot, e **descarta** que
reconfiguração de LVDS em runtime pudesse causar piscar de imagem — não há nada reaplicando.

### 1.2. `fun_call_cnt` não é contador de reconfiguração

Medido em `/proc/msp/panel`: sobe ~1454 a cada 12 s, ou seja ~121/s — 2x a taxa de vsync de 60 Hz. É
contador de ISR. Pista encerrada. **Ressalva de evidência:** das três leituras, apenas uma foi salva em
arquivo (`proc-panel.txt`, `fun_call_cnt: 145145`); as outras duas são relato.

---

## 2. O ACHADO PRINCIPAL: leituras inválidas do LSADC (LSADC-S1)

### 2.1. O precursor: uma sondagem que devolveu lixo

Em `evidencias/2026-08-17/sessao-diagnostico-231714.tsv`, no meio de uma série perfeitamente estável:

```
23:20:23   851.79   gtt1 = 63421
23:20:44   851.79   gtt1 =     2      <-- leitura invalida
23:21:05   872.69   gtt1 = 63421
```

Uma leitura de **2 mC** (0,002 °C) num sensor que estava em 63,4 °C. Não é temperatura: é leitura
inválida do conversor. Aconteceu **sete minutos antes** do episódio travado começar.

**Atribuição correta (corrige uma leitura errada anterior):** esse TSV foi produzido por um capturador
que chama `/vendor/bin/hidebug` com `gtt 0` / `gtt 1` — **cada linha dele é uma sondagem externa, não uma
amostra do loop do firmware**. Portanto o dado NÃO mede a taxa basal do firmware, e a extrapolação
"o firmware vê dez vezes mais" que constava aqui **não tem base e foi removida**.

O que o dado mede é outra coisa, e é mais direta ao ponto: **em 33 sondagens por `gtt`, uma devolveu
lixo.** Como cada `gtt` força comutação do mux `BL1551B`, o valor inválido é compatível com leitura feita
antes do assentamento do canal. Isto é evidência **a favor de LSADC-S2** — a sondagem externa como
gatilho —, não de defeito elétrico.

### 2.2. Cronologia do episódio

| Hora | Uptime | Evento |
|---|---|---|
| ~23:15:45 | ~553 s | `logcat -d` salvo (`logcat-full.txt`): **zero** `LSADC Error`, 12 `Achieve Balance` |
| 23:20:44 | ~852 s | **`gtt1` devolve 2 mC** — amostra inválida (artefato no TSV) |
| 23:23:31 | ~1019 s | gtt1 sobe de `63421` para `65763` e fica |
| **23:27:44** | **~1272 s** | **Primeiro `LSADC Error`**, em `Thermistor_0` e `Thermistor_1` |
| 23:28:03 | 1290 s | Última amostra; toda sondagem por `hidebug` encerrada |
| 23:28–23:30 | — | **2 min 51 s** de observação passiva, nenhum acesso ao `hidebug` |
| 23:30:54 | — | Erro persiste a cada 2 s. `Achieve Balance: 0` |
| 23:32:28 | — | `adb reboot` |
| 23:33:34 | 62 s | Volta. `LSADC Error: 0` — proteção restaurada |

**Estabelecido:** o erro não se recuperou em 2 min 51 s de observação, e enquanto durou,
`getAverageTemperature` devolve sentinela e `ThermalSense::dispatchProcess` a testa **antes** de
WARNING/EMERGENCY — logo o corte em 75 °C não podia disparar.

**Não estabelecido — a causa.** A sondagem por `hidebug` (`gtt 0`/`gtt 1` a cada 20 s por ~11 min, mais
um `gtc` do `pfl7560-fix.sh status`) era o único fator incomum na janela e **não pode ser descartada**
como gatilho. Ver a pendência LSADC-S2.

### 2.3. Existem DOIS regimes, não um

Comparando com o log histórico `artifacts/diagnostico/heat.logcat` (2026-07-05, pré-correção, linha 167):

| | Transitório (2026-07-05) | Travado (2026-08-17) |
|---|---|---|
| Ocorrências | 1 | contínuas, a cada ~2 s |
| Precursor | `Upset Balance at Temperature:-1296474592` (log do firmware) | `gtt1 = 2` mC (**numa sondagem externa**) |
| Recuperou? | **sim** — 12 `Achieve Balance` depois | **não** em 2 min 51 s |
| Sondagem externa | nenhuma conhecida | sim, ativa |

A diferença de origem importa: o precursor de 2026-07-05 aparece no **log interno do firmware**, sem
sondagem conhecida, e o próprio [doc 27](27-teardown-cabo-gnd-ntc.md) já o catalogou como glitch isolado
com o terra do NTC íntegro. O de 2026-08-17 aparece **numa leitura que o operador pediu**. Ou seja: o
glitch espontâneo existe, mas é raro e se recupera; o regime travado só foi observado sob sondagem
intensa. O que falta determinar é se o regime travado ocorre **sem** sondagem — é a pergunta que o
`pfl7560-vigia-lsadc.sh` mede.

### 2.4. Consequência metodológica: medir por props e logcat, nunca por `hidebug`

As props `zysys.env_temp` (gtt1, o sensor quente; fica no bloco do LED, [doc 40](40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3) e `zysys.light_temp` (gtt0, placa) são servidas pelo próprio
loop térmico, leem em ~29 ms e não forçam comutação de mux. Os nomes vêm invertidos de fábrica.

**Correção de uma afirmação anterior:** a versão original deste doc dizia que valor congelado nas props
serve de detector do erro. **Isso é falso.** Em `evidencias/2026-08-17/props-233919.tsv` o `gtt1` fica em
`65.8` por 23 ciclos consecutivos num boot saudável, porque o ADC é grosso — os degraus medidos são
`61154 / 63421 / 65763`, ou seja ~2,3 °C. Valor parado é comportamento normal. O detector correto do
erro é o **logcat**, e o detector *precoce* é a **amostra fora de faixa**.

---

## 3. A queixa de "perda de resolução" é óptica, não de software

O display expõe **um único modo** — `supportedModes [{id=1, width=1920, height=1080, fps=60.000004}]`
(artefato: `pos-reboot/display-modos.txt`) — e o `screencap` devolve um buffer de 1920x1080. Nada na
cadeia de sinal reduz resolução, então a perda de nitidez percebida é **óptica**, consistente com
polarizador degradado.

**Correção:** a versão original citava "framebuffer nítido" como prova. Não é: o framebuffer capturado
é o papel de parede do launcher (fundo chapado mais logo vetorial, 29 KB), sem conteúdo de alta
frequência. Ele comprova a **resolução do buffer**, não a nitidez da projeção.

O artefato relatado (faixas/chiado) permanece **em aberto** (ART-S1). Dados elétricos do link, para
referência: `current: 300MV`, `com_vol: 1200MV`, `2_link`, `8BIT`, `4_byte`, `spread_en: TRUE` com
`sp_ratio: 0`; timing exato (`htotal 2000` x `vtotal 1120` x 60 = `134,4 MHz`, confere com `clk`). Um
swing de 300 mV é a extremidade baixa da faixa LVDS típica — candidato plausível, **não verificado**.

---

## 4. Correção de bug: a autocaptura nunca coletou nada

`pfl7560-autocaptura.sh` abriu **8.257 sessões** entre 2026-07-30 e 2026-08-17 (contadas em
`evidencias/autocaptura.log`) e deixou **8.253 TSVs só-cabeçalho**.

**Causa raiz:** o adbd do aparelho sobe como `uid=2000(shell)` e o script nunca escalava root. `hidebug`
vive em `/vendor/bin` e exige root, então `amostra()` falhava sempre que o adbd **não** tivesse herdado
root de um `adb root` anterior — o que explica as poucas sessões que funcionaram (2026-07-29, logo após
uso manual do `fix.sh`, que escala root em `pfl7560-fix.sh:64`). O script então zerava `$DEV`, logava
**"projetor offline"** (rótulo errado: o aparelho tinha acabado de responder ao `getprop`), redescobria
e abria um TSV novo — um arquivo vazio a cada ~12 s.

Correções aplicadas:

1. `garante_root()` — escala e reconecta se `id` não retornar `uid=0`;
2. o TSV só nasce **depois** da primeira amostra boa;
3. a falha de amostragem deixou de ser rotulada como desconexão (variável `MOTIVO`);
4. **amostra inválida do LSADC agora é marcada** (`gtt1` fora de 5000..120000 mC) e não contamina o pico;
5. o alerta de brilho comparava com `1000`, mas `gbri 0` devolve o **PWM real**, que lê `996` no máximo —
   toda amostra era marcada como anômala. Passou a alertar só abaixo de `950`, o primeiro degrau real
   da escada (`gbll`: 750, 800, 850, 900, 950, 1000).

Os arquivos sem dado foram removidos (36 MB → 2,8 MB); os 6 TSVs com dado de 2026-07-29 e os 2 desta
sessão foram preservados.

---

## 5. Ferramental novo desta sessão

| Script | O que faz | Toca o mux? |
|---|---|---|
| `pfl7560-saude.sh` | 12 checagens read-only do estado da correção; `--idempotencia` roda duas passagens e compara. **`--vivacidade` NÃO é read-only** — ver nota abaixo | **não** |
| `pfl7560-vigia-lsadc.sh` | mede a taxa de episódios de `LSADC Error` por hora de uso, com cobertura explícita e detecção do precursor; `--resumo` calcula a taxa e o limite superior pela regra dos três | **não** |
| `pfl7560-monitor-props.sh` | curva térmica passiva via props | **não** |

Nenhum dos três usa `hidebug` — um instrumento que usa `hidebug` mediria o observador, não o fenômeno.

> **Exceção a registrar: `pfl7560-saude.sh --vivacidade` NÃO é read-only.** É o **único modo não passivo**
> de todo o ferramental desta tabela: escreve a propriedade `vendor.zy.power.tm.temp` (override total da
> malha térmica), **muda o brilho** do aparelho (a escada desce até 850 e volta sozinha) e **grava log** em
> `evidencias/vivacidade/`. Não toca o `hidebug` e não comuta o mux, mas também não é observação —
> é provocação deliberada. O override é limpo num `trap EXIT INT TERM`. Detalhes e aviso de segurança em
> [`37-mecanismo-lsadc-defasagem-dos-aneis.md`](37-mecanismo-lsadc-defasagem-dos-aneis.md) §6.

### 5.1. Quem sonda e quem não sonda (importa para o risco)

**Reformulado após o doc 37.** A formulação original desta seção — "estas ferramentas sondam, logo são
risco" — é imprecisa. O mecanismo, provado no binário
([doc 37](37-mecanismo-lsadc-defasagem-dos-aneis.md) §3), é mais fino:

- `gtt N` avança o anel de amostras do termistor `N` **e só dele**.
- `gtt 0` **e** `gtt 1` **em par** avançam um anel cada e **preservam a fase**. Foi o que os **1060
  comandos `gtt`** do corpus histórico fizeram, com **zero** episódios confirmados.
- O risco é sondagem **ÍMPAR**: um `gtt` sozinho, os canais crus do LSADC, **ou um par interrompido no
  meio** — que é exatamente o que um `timeout` de adb produz.

A conclusão prática **permanece a mesma**: não deixar sondador rodando como serviço. Não porque cada par
seja perigoso, mas porque quanto mais pares emitidos, maior a chance de um deles ser cortado no meio.
Classificação verificada com `grep -v '^\s*#' <script> | grep hidebug`:

| Sonda via `hidebug` (usar só pontualmente, com o aparelho supervisionado) | Passivo (seguro em uso contínuo) |
|---|---|
| `pfl7560-autocaptura.sh` · `pfl7560-evidencias.sh` · `pfl7560-monitor-termico.sh` · `pfl7560-fix.sh status` | `pfl7560-saude.sh` · `pfl7560-vigia-lsadc.sh` · `pfl7560-monitor-props.sh` · `pfl7560-lcd-color.sh` · `pfl7560-menu.sh` |

**Ação tomada em 2026-08-18:** o serviço de usuário `pfl7560-autocaptura` estava **`enabled`** — subiria
no próximo boot do PC e passaria a sondar a cada 30 s durante o uso real, agora com a escalada de root
funcionando. Foi **desabilitado** (`systemctl --user disable pfl7560-autocaptura`). Reabilitar só depois
que LSADC-S2 estiver respondida; para monitoramento contínuo, usar os passivos.

Observação com valor de sorte: o bug do root manteve esse serviço inofensivo entre 2026-07-30 e
2026-08-17. Consertá-lo sem responder LSADC-S2 primeiro teria transformado o instrumento de medida em
fonte do próprio defeito que ele mede.

---

## 6. Achado colateral: a premissa da VIGIA-S1 é falsa neste aparelho

`/data/local/nlsu/` **não existe** (artefato: `pos-reboot/artefatos-ausentes.txt`). O hook
`sys.boot_completed` → `exec ... /data/local/nlsu/update_after_boot.sh` citado como ancoragem
alternativa do vigia de tela não tem diretório de destino aqui. A ancoragem por arquivo `.rc` novo em
`/vendor/etc/init/` continua sendo o caminho, com precedente empírico a favor: foi assim que o
`nl_lvds.rc` funcionou antes de ser substituído pela gravação nativa.

---

## 7. Falha de método desta sessão (registro honesto)

**O episódio de `LSADC Error` das 23:27 não tem artefato.** As leituras foram feitas com
`adb shell logcat -d | grep`, cujo resultado foi lido na tela e nunca gravado em arquivo. O
`logcat-full.txt` salvo é de ~23:15, **anterior** ao episódio, e o buffer se perdeu no reboot das
23:32. Um `grep -rl 'LSADC Error'` sobre o repositório não encontra nenhum arquivo daquela janela.

Consequência: a cronologia da seção 2.2, a contagem de 130 ocorrências, o `Achieve Balance: 0` e a
restauração pós-reboot são **relato do operador**, não evidência auditável. O precursor de 23:20:44 (2 mC)
sobrevive porque caiu num TSV por acaso.

**Regra adotada a partir daqui:** toda leitura que sustente uma conclusão é redirecionada para arquivo
em `evidencias/` no mesmo comando que a produz. O `pfl7560-vigia-lsadc.sh` já nasce assim.

---

## 8. Pendências

| ID | Severidade | Estado | Item |
|---|---|---|---|
| **LSADC-S1** | **alta** | **ABERTO, despriorizado** (desde o [doc 37](37-mecanismo-lsadc-defasagem-dos-aneis.md) §11; instrumentado) | Medir episódios por hora de uso real sem sondagem. `pfl7560-vigia-lsadc.sh` coletando. Critério: zero em ~30 h descarta taxa >= 1 a cada 10 h |
| **LSADC-S2** | **alta** | **ABERTO — prioridade máxima** ([doc 37](37-mecanismo-lsadc-defasagem-dos-aneis.md) §8 e §11) | `gtt` repetido via `hidebug` é gatilho? A doc trata `gtt` como seguro. Se for, inválida `pfl7560-autocaptura.sh` como método de medição |
| ~~LSADC-S3~~ | — | **DESCARTADA** | Levantei "mau contato no chicote GND/NTC" como origem elétrica. O [doc 27](27-teardown-cabo-gnd-ntc.md) **já havia respondido**: o cabo solto é jumper de aterramento/EMI com terminal de anel, e o terra funcional do NTC entra pelo conector JST de 2 vias, que está **plugado**. Terminal de anel não entra em carcaça JST. Além disso o doc 27 já catalogou o glitch do `heat.logcat` e mostrou que o terra esteve íntegro (leituras finitas e válidas). **Causa elétrica no chicote está excluída; o vetor vivo é software/sondagem** |
| **ART-S1** | média | **ABERTO** | Artefato/faixas não caracterizado. Discriminar elétrico (LVDS `current` 300MV, flat) vs óptico |
| ~~POL-S1~~ | — | **FECHADO (2026-09-02)** | Polarizador é **placa de vidro separada** entre a Fresnel traseira e o LCD, **não laminado ao painel**; o de **entrada** é o que queimou; a peça de reposição bate medida, espessura e eixo. Ver [doc 38](38-motor-optico-e-troca-do-polarizador.md) |
| **BRI-S1** | média | **ABERTO** (decisão do dono, [doc 39](39-sessao-2026-09-02-optica-e-balanco-termico.md) §5) | Decidir o brilho base. Com 0,43 °C por 1% (doc 34), 1000→900 compra ~4,3 °C; 1000→850, ~6,5 °C |
| VIGIA-S1 | média | aberto, **premissa REFUTADA** (ver [doc 34](34-escada-brilho-e-fanmonitor.md)) | Premissa do hook `/data/local/nlsu/` **refutada** |

## 9. Proof-of-work

```bash
# veredito completo do estado (12 checagens, exit code 0/1):
PFL_IP=<ip> ./pfl7560-saude.sh
PFL_IP=<ip> ./pfl7560-saude.sh --idempotencia

# medicao da taxa de LSADC Error (passivo, roda por dias):
PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh
PFL_IP=<ip> ./pfl7560-vigia-lsadc.sh --resumo

# a protecao esta VIVA agora? PROVA FORTE (ativa: injeta 71 C, ~65 s, e ve se o
# firmware reage). Esperado: "o WARNING disparou" + "a escada de brilho atuou".
PFL_IP=<ip> ./pfl7560-saude.sh --vivacidade

# o grep abaixo NAO e prova de saude: o erro so aparece em 2 de cada 10 iteracoes
# do loop e o ring do logcat dura 60-150 s, entao zero pode so significar que voce
# nao olhou tempo suficiente. Vale como sinal POSITIVO: se aparecer, algo esta
# errado de fato (doc 37, secao 7).
adb shell 'logcat -d' | grep -c 'LSADC Error'
```
