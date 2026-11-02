# re-termico - material de engenharia reversa do loop térmico

Diretório de trabalho do disassembly que produziu o
[doc 37](../../docs/research/37-mecanismo-lsadc-defasagem-dos-aneis.md).

| Arquivo | Tracking | Como obter |
|---|---|---|
| `libhitvservice.so` | **fora do Git** (`*.so` no `.gitignore`) | `adb pull /vendor/lib/libhitvservice.so` |

A lib é **proprietária** (Intelbras / HiSilicon) e segue a mesma regra dos `.bin` e do `.zip` de
firmware: fica na máquina, nunca no repositório. A cópia analisada foi extraída em 2026-08-18 do
aparelho de origem desta pesquisa - md5 `4ce869799a82493799be61ff5d922be3`, 3649256 bytes.

## Como reproduzir

O `objdump` da máquina não tem alvo ARM. Use **capstone** via Python (a lib é Thumb):

```bash
python3 -c "import capstone" || pip install --user capstone
readelf -SW libhitvservice.so | grep -E '\.text|\.data'   # confira VMA e offset antes de tudo
```

Símbolos-chave (confirme com `nm -D` e com o `.gnu_debugdata`, que traz os locais):

| Símbolo | Papel no mecanismo |
|---|---|
| `_ZN16ZYThermalManager16RunDaulRigalModeEv` | o modo térmico ativo (`THERMAL_MODE = 0x1001`) |
| `_ZN10Thermistor14getTemperatureEv` | avança o anel de amostras - incondicionalmente |
| `_ZN10Thermistor21getAverageTemperatureEv` | média do anel; clampa valor fora de faixa em `MIN_VALUE-1` |
| `_ZN9HiDevCtrl5Lsadc8getValueEjPj` | leitura crua do LSADC |
| `_ZN8ZYConfig7Thermal9MIN_VALUEE` | a sentinela comparada no teste de erro |

Os endereços citados no doc 37 valem para **esta** cópia (md5 acima). Outra build desloca tudo.
