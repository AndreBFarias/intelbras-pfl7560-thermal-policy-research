# Relatório técnico — PFL7560: proteção térmica cega e falha prematura da óptica

**Produto:** Intelbras PFL7560
**Firmware analisado:** V1.0.0.9 (build 2026-06-17)
**Classificação sugerida:** problema de **confiabilidade / política térmica de firmware** que causa **falha prematura e dano físico** à óptica (polarizador e LCD)
**Autor:** pesquisador independente / proprietário do equipamento
**Data:** 2026-07-08
**Canal:** CSIRT Intelbras (e, se aplicável, encaminhamento a P&D / qualidade de produto)

> **NOTA (2026-10-30) — acréscimos sem alterar o relatório abaixo:**
> 1. **O defeito persiste em outubro de 2026.** O firmware oficial publicado em 2026-10-20 para produtos
>    fabricados a partir de 25/08/2026 (modelo sem USB-C, `V1.0.0.1`, build de 2026-08-08) mantém
>    `HW_VIRTUAL_CHANNEL = 0` nos dois termistores, a mesma curva de ventiladores, a mesma escada de brilho e
>    os mesmos 43/45 °C; a `libhitvservice.so` é byte-idêntica
>    ([doc 42](../research/42-firmware-2026-10-modelo-sem-usbc.md) §3).
> 2. **Posição do 2º sensor:** o NTC do `gtt 1` é um termistor encapsulado num olhal parafusado no topo do
>    **bloco dissipador do LED**; nenhum sensor mede o polarizador/LCD
>    ([doc 40](../research/40-sessao-2026-10-29-segunda-troca-lcd-e-auditoria.md) §3). Onde o texto diz
>    "bloco óptico" ou "temperatura real da óptica", o dado medido é o do bloco do LED.
> 3. **Refrigeração:** 3 ventiladores — 2 sopradores `DFH8030S` (12 V, 0,45 A) controlados pela política e 1
>    axial no exaustor do LED, sem controle; o anexo abaixo cita "2 sopradores DFH8025S", leitura de julho.

---

## 1. Resumo executivo

No PFL7560 com firmware V1.0.0.9, a proteção térmica fica **efetivamente cega** porque os dois termistores NTC do produto estão configurados no **mesmo canal virtual do multiplexador** (`HW_VIRTUAL_CHANNEL = 0` em ambos). O sistema só lê um sensor fisicamente desacoplado do fluxo quente da óptica (~26 °C), mantém ventilação insuficiente e **não aciona** os limiares de aviso/desligamento enquanto a saída de ar e o bloco óptico aquecem. No equipamento de origem desta pesquisa, polarizador e LCD foram substituídos **duas vezes em 18 meses**. A correção de software é mínima (alteração de configuração em `/vendor/etc/ZYCustom.ini`, essencialmente um caractere no canal virtual do 2º termistor, mais curvas de fan/brilho e limiares coerentes) e foi **validada em hardware real**, com redução medida da temperatura de saída de ar de **46,7 °C para 37,2 °C**.

---

## 2. Evidência do defeito de configuração

Arquivo de política: `/vendor/etc/ZYCustom.ini` (texto, lido pela HAL térmica `ZYThermalManager` / `libhitvservice.so`).

- Existem seções `[Thermistor_0]` e `[Thermistor_1]`, ambas em `HW_LSADC_CHANNEL = 1`, multiplexadas por `BL1551B` no `GPIO4_4`.
- Em fábrica, **as duas** usam `HW_VIRTUAL_CHANNEL = 0`. O multiplexador só comuta quando o canal virtual alvo difere do atual; com ambos em 0, o GPIO permanece em um único estado e o **segundo ramo NTC nunca é selecionado**.
- Em runtime (stock), `gtt 0` e `gtt 1` são **idênticos byte a byte** (~24–28 °C) mesmo com saída de ar > 43 °C (termômetro IR).
- A conversão ADC→°C do firmware está **correta** (verificada por engenharia reversa e dado ao vivo; erro ~0,04 °C). O problema **não** é a fórmula — é o **mux que não comuta** e o único sensor efetivo estar longe do calor.

Com `HW_VIRTUAL_CHANNEL = 1` em `[Thermistor_1]` (e reboot):

- `gtt 0` ≈ 24–26 °C (sensor de placa)
- `gtt 1` ≈ 55–61 °C (sensor que enxerga o calor real)
- ADC alterna entre valores distintos nos dois canais → mux comprovadamente comutando
- O firmware passa a registrar avisos de superaquecimento no canal 1 (comportamento ausente no stock)

---

## 3. Prova de impacto (medição e dano)

| Cenário | Temperatura na saída de ar (IR) |
|---|---|
| Stock (fans ~55% por sensor cego) | **46,7 °C** |
| Configuração corrigida (fans 100% desde o boot) | **37,2 °C** (−9,5 °C) |
| Corrigida + ventilação externa auxiliar | 32,9 °C |

- **Dano físico observado no equipamento de teste:** polarizador e painel LCD degradados/queimados, com **duas substituições em 18 meses** sob uso doméstico com ambientação ventilada.
- **Efeito colateral do stock no brilho:** a curva de dimming (`POLICY_*_BRIGHTNESS` 1000→750) está atada ao sensor cego, com limiares na faixa `27000-36000` que **não corresponde** à temperatura real da óptica; com o uso a imagem **enfraquece** sem que isso proteja nada. Na correção, a curva é reancorada no sensor **real**: brilho pleno (1000) em toda a faixa normal de operação, descendo em degraus (950 / 900 / 850) apenas entre 66 °C e 70 °C e voltando sozinha na descida. A imagem permanece estável no uso comum **e** a redução passa a acontecer quando de fato protege.

**Anexos.** Já no repositório (`media/` + dossiê visual [`docs/dossie-teardown.html`](../dossie-teardown.html), detalhado em [`docs/research/27-teardown-cabo-gnd-ntc.md`](../research/27-teardown-cabo-gnd-ntc.md)): fotos do teardown — 2 sopradores DFH8025S, header `GND/NTC` na placa NL-5H039-MAIN, e o mapa da placa corrigido (SoC HiSilicon vs. controlador de armazenamento). Pendentes de captura: fotos do polarizador/LCD danificados e do termômetro IR na saída de ar (o comparativo térmico e as leituras `hidebug` `gtt`/`gfs` antes/depois estão registrados numericamente). Repositório de pesquisa (ainda sob janela de divulgação coordenada): *intelbras-pfl7560-thermal-policy-research*.

---

## 4. Causa-raiz e correção proposta (mínima)

**Causa-raiz:** mapeamento incorreto do multiplexador de termistores na configuração de fábrica (`HW_VIRTUAL_CHANNEL` idêntico nos dois canais), resultando em proteção térmica que não observa a temperatura real da óptica.

**Diff conceitual no `ZYCustom.ini` (principais linhas; build validada md5 `252ab7a72a007a8b79b3fc86bd5c0d19`):**

| Seção / chave | Stock | Proposto / validado |
|---|---|---|
| `[Thermistor_1] HW_VIRTUAL_CHANNEL` | `0` | **`1`** ← destrava o mux |
| `[ThermalPolicy] POLICY_*_SPEED` | rampa 500…1000 | **1000** (piso máximo enquanto a óptica for crítica) |
| `[CoolingFan_*] DEFAULT_PWM_DUTY` | 200 / 150 | **1000** no boot |
| `[BacklightPolicy] POLICY_*_THRESHOLD` | `27000…36000` (faixa do sensor cego) | **`66000, 67500, 69000, 70000, 71500, 73000`** (faixa real da óptica) |
| `[BacklightPolicy] POLICY_*_BRIGHTNESS` | 1000…750 atado ao sensor cego | **`1000, 950, 900, 850, 850, 850`** — pleno no uso normal, escada só a partir de 66 °C |
| `[Thermal] WARNING / EMERGENCY` | 43 / 45 °C | **70 / 75 °C** (coerentes com `gtt1` real ~55–61 °C) |
| typo `FW_SPEED_CURVE` fan1 | `825. 925` | `825, 925` |

Correções auxiliares observadas no mesmo firmware (qualidade de uso, não térmicas):

- `vendor.newlink.wifi_disconnect_on_boot=1` → `0` (Wi-Fi reconecta após reboot)
- serviço `xiriservice` gerando spam de log (~1×/s) → pode ser desabilitado se não for requisito de produto

**Importante:** a correção comunitária edita apenas `/vendor` (sem dm-verity nesta build) e **não altera o bootloader**. Um `.bin` reempacotado experimental **não** deve ser distribuído até metadados de filesystem (modo/owner/xattrs) estarem validados — um protótipo travou o boot e foi colocado em quarentena.

---

## 5. Impacto no consumidor e enquadramento

- Risco de **dano recorrente** a polarizador e LCD (peças de custo relevante e, em muitos casos, fora do alcance de reparo pelo usuário).
- Proteção térmica de fábrica **não cumpre a função esperada** de interromper o ciclo de superaquecimento da óptica.
- Sob a ótica do Código de Defesa do Consumidor, trata-se de potencial **vício de qualidade / inadequação ao uso ordinário** e de risco de prejuízo material repetido, não de “mau uso” isolado.
- Build analisada apresenta postura de engenharia (`userdebug` / chaves de desenvolvimento, SELinux permissivo, adb de rede aberto) — relevante para qualidade de release, ainda que o núcleo deste relatório seja a **política térmica**.

Não se alega má-fé. O objetivo é permitir que P&D/firmware **reproduza o achado**, corrija o mapeamento do mux e publique atualização oficial.

---

## 6. Oferta de colaboração

Como researcher independente que identificou e **validou a correção em hardware real**, coloco-me à disposição para:

1. Fornecer logs, trechos de configuração e medições adicionais sob pedido;
2. **Testar qualquer patch oficial** (OTA / imagem de fábrica) que a Intelbras venha a liberar, no mesmo modelo e firmware de referência;
3. Apoiar validação de peças de reposição óptica (polarizador/LCD) se a fabricante julgar útil para o processo de qualidade.

Contato: _(preencher no formulário CSIRT / e-mail de resposta)_.

Atenciosamente,
**[REDACTED]**
Proprietário / pesquisador — PFL7560 · firmware V1.0.0.9

---

## Anexo A — Como reproduzir (resumo)

```text
# 1) Stock: gtt0 == gtt1 (~26 C) com saida de ar quente
# 2) Em /vendor/etc/ZYCustom.ini, [Thermistor_1]:
#       HW_VIRTUAL_CHANNEL = 0  ->  1
# 3) Reboot; hidebug:
#       gtt 0  -> ~26 C
#       gtt 1  -> ~55-61 C
#       gfs 0 / gfs 1 com fans ajustados conforme politica
```

Documentação técnica completa (teardown, disassembly da conversão NTC, guias de aplicação comunitária e recuperação) será publicada em repositório aberto após a janela de divulgação coordenada, salvo orientação em contrário da Intelbras.
