# Requisitos — PFL7560 Fix

Este projeto é feito de **scripts shell** (não há Python/Node), então os "requisitos" são ferramentas de
sistema. O que você precisa depende do método de instalação (ver [`INSTALL.md`](INSTALL.md)).

## Por método

| Método | Precisa de |
|---|---|
| **1. Pendrive autorun** | só um **pendrive FAT32**. Nenhum software no PC. |
| **2. Script no PC** | `adb`, `bash`, coreutils. `nmap` opcional (busca por MAC). `gnome-terminal`/afim p/ o duplo-clique. |
| **3. Manual** | `adb`. |

## No aparelho

- Intelbras **PFL7560**, firmware **V1.0.0.9**.
- **adb por rede habilitado** (esta build vem `userdebug` com adb root aberto na porta TCP 5555 — é o que
  torna o Método 2/3 possível). O aparelho e o PC no **mesmo Wi-Fi**.

## Instalar as dependências (PC)

**Debian / Ubuntu / Pop!_OS:**
```bash
sudo apt update
sudo apt install android-tools-adb nmap
```

**Fedora:**
```bash
sudo dnf install android-tools nmap
```

**Arch:**
```bash
sudo pacman -S android-tools nmap
```

**macOS (Homebrew):**
```bash
brew install android-platform-tools nmap
```

## Versões de referência

Testado com: `adb` (Android platform-tools) 34+, `bash` 5.x, `nmap` 7.x, `git` 2.34+. Versões próximas
funcionam. O `sed` do próprio aparelho (toybox) suporta o *append* usado na correção do `xiriservice`
(verificado).

## Variáveis de ambiente (opcionais, Método 2)

| Variável | Para quê | Exemplo |
|---|---|---|
| `PFL_IP` | pula a busca e conecta direto no IP | `PFL_IP=192.168.0.50` |
| `PFL_SUBNET` | faixa que o `nmap` varre | `PFL_SUBNET=192.168.0.0/24` |
