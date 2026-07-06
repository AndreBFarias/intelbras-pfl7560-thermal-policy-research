# 09 - Build definitiva e resultados medidos

Data: 2026-07-05. Aparelho: Intelbras PFL7560, V1.0.0.9, projectid=390, MAC 38:54:39:a3:6f:34.
Arquivo da build: `artefatos/ZYCustom_390.ini` (md5 `1ad641ed2dd99e61d8a987a675e9aced`).

## O que a build faz (10 linhas mudadas vs stock, resto byte-idêntico)

| Seção | Mudança | Efeito |
|---|---|---|
| `[ThermalPolicy]` POLICY_0/1_SPEED | `500..1000` → **tudo 1000** | **fans no máximo sempre**, independente da temperatura |
| `[CoolingFan_0/1]` DEFAULT_PWM_DUTY | `200`/`150` → **1000** | fans fortes já no bring-up do boot |
| `[CoolingFan_1]` FW_SPEED_CURVE | `825. 925` → **`825, 925`** | corrige typo de fábrica |
| `[BacklightPolicy]` POLICY_0/1_BRIGHTNESS | `1000..750` → **tudo 1000** | **brilho travado em 100%** |
| `[Thermistor_1]` HW_VIRTUAL_CHANNEL | `0` → **1** | **DESTRAVA O MUX** → ativa o 2º NTC (o que enxerga o calor real) |
| `[Thermal]` WARNING_VALUE | `43000` → **70000** | aviso só quando esquenta de verdade (não enche o saco a 59 °C) |
| `[Thermal]` EMERGENCY_VALUE | `45000` → **75000** | **desligamento de proteção REAL** a 75 °C (antes nunca funcionava) |

## Resultados medidos (saída de ar, termômetro IR)

| Cenário | Temperatura |
|---|---|
| Stock (fans ~55% por causa do sensor cego) + brilho 100% | **46,7 °C** |
| **Build (fans 100%)** + brilho 100% | **37,2 °C** (−9,5 °C) |
| Build + ventilador externo | **32,9 °C** (−13,8 °C) |

## A descoberta central (a "falha grosseira")

- O firmware **converte a temperatura corretamente** (fórmula verificada no binário). Não era bug de conta.
- Havia **2 NTCs**, mas os dois foram configurados no **mesmo canal do mux** (`HW_VIRTUAL_CHANNEL=0`), então o
  mux **nunca trocava** e o **2º sensor (o que fica perto da óptica) nunca era lido**. O firmware só via o 1º
  (ar da placa, ~26 °C) → achava que estava frio → deixava os fans em ~55% → a lente cozinhava.
- **Nosso fix (`HW_VIRTUAL_CHANNEL=1`) destravou o mux.** Prova ao vivo, pós-reboot:
  - `gtt 0` = **26 °C** (sensor velho) · `gtt 1` = **59 °C** (2º sensor, agora lendo o calor REAL)
  - logcat: `Thermistor_1 Overheat Warning Temperature: 58954!` — o firmware reclamou do calor **pela 1ª vez**
  - ADC do canal alterna 168 (NTC0) ↔ 100 (NTC1) → mux confirmadamente comutando
- **Conclusão:** a falha tem **conserto de software**. Um erro de 1 caractere de fábrica desligava a proteção térmica.

## Deploy (idempotente, reversível)

Instalado como override de precedência máxima, **sem tocar `/vendor`** nem o bootloader:
```
adb root
adb push ZYCustom_390.ini /atv/ini/ZYCustom_390.ini
adb shell chmod 644 /atv/ini/ZYCustom_390.ini
adb shell sync && adb reboot
```
Reverter (volta 100% ao stock):
```
adb root && adb shell rm /atv/ini/ZYCustom_390.ini && adb reboot
```
Backups do `.ini` stock: `artefatos/ZYCustom.ini.ORIGINAL` e `ZYCustom.ini.DEVICE-2026-07-05`.

## Bugs colaterais achados (para o relatório Intelbras)

1. **Sensor térmico desligado** (mux config bug) — a proteção térmica não funcionava de fábrica. CRÍTICO.
2. **Wi-Fi não reconecta sozinho após reboot** (28 erros `WifiVendorHal`) — precisa reconectar manual.
3. Firmware `userdebug`/`dev-keys` em produção, SELinux permissivo com dezenas de `avc denied`, sem dm-verity,
   updater sem assinatura (só CRC), adb root aberto por padrão. Descuido geral de release.
