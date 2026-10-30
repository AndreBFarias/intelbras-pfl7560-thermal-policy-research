# Requisitos — PFL7560 Fix

Lista curta em [`requirements`](requirements). Instalador automático: **`./install.sh`** (Linux/macOS) ou **`install.bat`** (Windows).
O que você precisa depende do método ([`INSTALL.md`](INSTALL.md)).

## Por método

| Método | Precisa de |
|---|---|
| **1. Pendrive autorun** | só um **pendrive FAT32**. Nenhum software no aparelho além do kit; no PC, só para copiar (recomendado: `./install.sh --pendrive DIR` ou `install.bat` opção 5, que conferem o md5). |
| **2. Script no PC** | `adb`. No Linux/macOS: `bash` + coreutils (`pfl7560-fix.sh`). No Windows: `install.bat` (adb puro). `nmap` **opcional** (só `PFL_MAC`). |
| **3. Manual** | `adb`. |

## No aparelho

- Intelbras **PFL7560**, firmware de fábrica **V1.0.0.9** (com USB-C) ou **V1.0.0.1** (sem USB-C, "NOTYPEC";
  só simulação). Outra versão: o kit e o `pfl7560-fix.sh` recusam.
- **adb por rede** (esta build vem `userdebug` com adb root na porta TCP **5555**). PC e projetor no **mesmo Wi-Fi**.

## Instalar as dependências (PC)

**Recomendado (automático):**
```bash
./install.sh          # Linux / macOS
./install.sh --check  # só verifica
```
```bat
install.bat           REM Windows (menu)
```

**Manual — Debian / Ubuntu / Pop!_OS:**
```bash
sudo apt update
sudo apt install android-tools-adb nmap
```

**Manual — Fedora:**
```bash
sudo dnf install android-tools nmap
```

**Manual — Arch:**
```bash
sudo pacman -S android-tools nmap
```

**Manual — macOS (Homebrew):**
```bash
brew install android-platform-tools nmap
```

**Manual — Windows:** [Platform-Tools (Google)](https://developer.android.com/tools/releases/platform-tools) no PATH, ou deixe o `install.bat` baixar em `tools\platform-tools\`.

## Versões de referência

Testado com: `adb` (platform-tools) 34+, `bash` 5.x, `nmap` 7.x, `git` 2.34+. Versões próximas funcionam.

## Variáveis de ambiente (Método 2)

| Variável | Para quê | Exemplo |
|---|---|---|
| `PFL_IP` | **recomendado** — IP do projetor | `PFL_IP=192.168.0.50` |
| `PFL_MAC` | busca por MAC via nmap (opcional) | `PFL_MAC=aa:bb:cc:dd:ee:ff` |
| `PFL_SUBNET` | faixa que o nmap varre | `PFL_SUBNET=192.168.0.0/24` |
| `PFL_LVDS_ESPERADO` | `pfl7560-saude.sh`: exige um formato de cor (`vesa`/`jeida`); sem ela, passa quando o em uso bate com o gravado | `PFL_LVDS_ESPERADO=vesa` |

`PFL_IP` aceita `IP` ou `IP:porta` (sem porta, usa 5555).

Sem `PFL_IP` e sem `PFL_MAC`, o script pede o IP e aborta (não há MAC de aparelho embutido).
