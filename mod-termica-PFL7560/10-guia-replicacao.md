# 10 - Guia de replicação (para outros donos do PFL7560)

Este guia aplica a mesma correção térmica em qualquer PFL7560 com firmware V1.0.0.9. Os métodos por `/vendor`
(Método A, via adb) são **reversíveis** (apagam 1 arquivo) e **não tocam no bootloader** (sem risco de brick).
Há também um `.bin` por pendrive (Método B), mas ele está **em quarentena** — foi testado e **trava o boot**;
use o Método A.

> **O que a correção faz:** ativa o 2º sensor de temperatura (desligado por bug de fábrica), força os fans a
> 100% sempre, trava o brilho em 100% e instala um desligamento de proteção real a 75 °C. Resultado medido:
> saída de ar de 46,7 °C → 37,2 °C.

## Método A — via adb (recomendado)

> **SUPERADO (deploy por `/atv/ini`):** o método definitivo hoje é a **edição direta do `/vendor`** via
> `pfl7560-fix.sh` (reversível) — ver [doc 14](14-estado-final-aplicado.md). O passo a passo por `/atv/ini`
> abaixo continua funcional, mas o `/atv` é um override de precedência preterido pelo `/vendor`.

### Requisitos
- PC com `adb` (Android platform-tools).
- Projetor no **mesmo Wi-Fi** que o PC (ou cabo na porta **USB-C** do projetor).

### Passos
1. **Conectar** (o firmware já vem com adb aberto — `userdebug`, sem senha):
   - Wi-Fi: descubra o IP do projetor (roteador, ou pelo MAC) e `adb connect <IP>:5555`
   - USB-C: ligue o cabo e `adb devices`
2. **Root:** `adb root` (concedido por `ro.debuggable=1`).
3. **Descobrir o projectid:** `adb shell getprop ro.boot.projectid`
   - Se der um número (ex.: 390), o arquivo tem que se chamar `ZYCustom_<número>.ini`.
   - Confira se já não existe um: `adb shell ls /atv/ini/ZYCustom*.ini` (normalmente não existe).
4. **Backup** (segurança): `adb pull /vendor/etc/ZYCustom.ini ZYCustom.ORIGINAL.ini`
5. **Gravar a correção** (arquivo `ZYCustom_390.ini` deste projeto; renomeie para o seu projectid):
   ```
   adb push ZYCustom_390.ini /atv/ini/ZYCustom_<seu_projectid>.ini
   adb shell chmod 644 /atv/ini/ZYCustom_<seu_projectid>.ini
   adb shell sync && adb reboot
   ```
   (Se o projectid for 0/vazio, use `/atv/ini/ZYCustom.ini`.)
6. **Validar** após o boot (entra no módulo `custom` do `hidebug`):
   ```
   adb shell 'printf "custom\ngfs 0\ngfs 1\ngtt 0\ngtt 1\nquit\n" | /vendor/bin/hidebug'
   ```
   Esperado: `fan speed 1000/1000` (fans máx), `gtt 0` ~26 °C e **`gtt 1` ~55-60 °C** (o 2º sensor vivo).
   Se `gtt 1` ficar igual a `gtt 0`, o mux não destravou — confira a linha `HW_VIRTUAL_CHANNEL=1` em `[Thermistor_1]`.

### Reverter
```
adb root && adb shell rm /atv/ini/ZYCustom_<projectid>.ini && adb reboot
```

### Calibrar o shutdown por unidade
O `75 °C` (EMERGENCY) e `70 °C` (WARNING) são defaults seguros: a operação normal com fans-máx fica ~59 °C.
Se em outra unidade o `gtt 1` normal for bem diferente, ajuste em `[Thermal]` mantendo margem (EMERGENCY
~15-20 °C acima do normal). **Nunca** deixe EMERGENCY abaixo da temperatura normal (desliga sem parar).

## O que muda no `ZYCustom.ini` (resumo — 7 pontos)

```
[ThermalPolicy]  POLICY_0_SPEED / POLICY_1_SPEED      -> tudo 1000     (fans máx sempre)
[CoolingFan_0]   DEFAULT_PWM_DUTY                      -> 1000
[CoolingFan_1]   DEFAULT_PWM_DUTY                      -> 1000
[CoolingFan_1]   FW_SPEED_CURVE  "825. 925"           -> "825, 925"    (corrige typo)
[BacklightPolicy] POLICY_0/1_BRIGHTNESS               -> tudo 1000     (brilho 100%)
[Thermistor_1]   HW_VIRTUAL_CHANNEL = 0               -> 1             (ATIVA o 2o sensor - o conserto)
[Thermal]        WARNING_VALUE 43000 / EMERGENCY 45000 -> 70000 / 75000 (proteção real)
```

## Método B — via `.bin` por pendrive — EM QUARENTENA, NÃO USE

Um `.bin` modificado gravável pela "Atualização local do sistema" (pendrive FAT32, sem PC) já foi **construído
e testado**, mas ele **TRAVA O BOOT** (os 3 arquivos reescritos ficam sem rótulo SELinux/modo/owner do stock) —
está **em quarentena, não flashe**. O brick e a recuperação estão na [doc 16](16-recuperacao-brick.md); o plano
para um `.bin` que boota está na [doc 18](18-sprint-bin-futuro.md). **Enquanto ele não passar no gate de boot em
hardware, use o Método A (`/vendor` via adb).**

## Avisos

- Só testado na V1.0.0.9. Em outra versão, confira os nomes das seções antes.
- Fans a 100% sempre = mais ruído e mais desgaste do fan (troca aceitável para salvar a óptica).
- Isto é modificação de aparelho próprio; anula garantia se a Intelbras considerar. Use por conta e risco.
