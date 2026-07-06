# PFL7560 Fix — correção térmica, brilho e Wi-Fi (Intelbras PFL7560)

Correção de software para o projetor **Intelbras PFL7560** (firmware V1.0.0.9) que resolve um
**superaquecimento causado por um bug de fábrica** — um sensor de temperatura que veio **desligado**,
deixando a proteção térmica cega. Esse calor **queima o polarizador e o LCD** (no aparelho de origem
deste projeto, trocados 2x em 18 meses).

> **Aviso:** projeto independente, **sem vínculo com a Intelbras**. Mexe em partição do aparelho por sua
> conta e risco. Não toca no bootloader — as mudanças são reversíveis e não brickam o aparelho. Veja
> [Segurança](#segurança-e-recuperação).

## O que a correção faz

| Item | Antes (fábrica) | Depois |
|---|---|---|
| **2º sensor de temperatura** | desligado por um bug de config (`HW_VIRTUAL_CHANNEL=0`) → proteção cega | ativo → proteção real |
| **Ventiladores** | só aceleram tarde, guiados pelo sensor cego | **100% desde o boot** |
| **Brilho** | vinha represado (dimming atado ao sensor cego) → tela fraca | **100% de verdade** |
| **Desligamento de proteção** | limiar que quase nunca dispara | **75 °C** (rede de segurança) |
| **Wi-Fi** | não reconecta após reiniciar (`wifi_disconnect_on_boot=1`) | reconecta sozinho |
| **Log** | spam do `xiriservice` ~1x/s | silenciado |

**Resultado medido** na saída de ar: **46,7 °C (stock) → 37,2 °C** (com a correção) — e a tela ficou
visivelmente mais clara.

## A descoberta central

A política térmica **não é código compilado** — é um arquivo de texto (`/vendor/etc/ZYCustom.ini`). O
firmware tem **dois termistores**, mas os dois foram mapeados para o **mesmo canal de leitura**
(`HW_VIRTUAL_CHANNEL=0`), então o multiplexador nunca chaveava para o segundo NTC. Resultado: o sistema
lia só um ponto e ficava **cego** para o calor real da óptica. A correção é, na essência, **trocar um
caractere** (`0` → `1`) mais o ajuste das curvas de fan/brilho. Detalhes em
[`mod-termica-PFL7560/08-por-que-fica-cego.md`](mod-termica-PFL7560/08-por-que-fica-cego.md).

## Como aplicar (3 métodos)

Escolha **um**. Todos gravam a mesma correção na partição `/vendor` (permanente, sobrevive a reset de
fábrica). Veja o passo a passo em [`INSTALL.md`](INSTALL.md) e as dependências em
[`REQUIREMENTS.md`](REQUIREMENTS.md).

1. **Pendrive autorun (mais fácil, sem PC).** Copie `pendrive-autorun/newlink_update.sh` e
   `pendrive-autorun/ZYCustom.ini` para a raiz de um pendrive FAT32, plugue no projetor **desligado** e
   ligue. O próprio firmware executa o script no boot e reinicia sozinho. Idempotente.
2. **Script no PC (adb por Wi-Fi).** `./pfl7560-fix.sh apply` — conecta, faz backup, aplica e valida.
   Também `status` e `revert`. Ou clique duas vezes em `PFL7560-Corrigir.desktop` (menu).
3. **Manual (adb).** Comandos crus documentados em
   [`mod-termica-PFL7560/06-acesso-adb-e-comandos.md`](mod-termica-PFL7560/06-acesso-adb-e-comandos.md).

## Segurança e recuperação

- **Não tocamos no bootloader/recovery** — nenhuma mudança nossa pode impedir o aparelho de ligar.
- Só editamos a partição **`/vendor`** (que **não** tem dm-verity nesta build). Sobrevive a reset de fábrica.
- Toda aplicação faz **backup do stock** antes; `revert` restaura.
- Recuperação máxima: regravar o firmware de fábrica pela "Atualização local do sistema" (menu do projetor).
- Detalhes: [`mod-termica-PFL7560/12-seguranca-e-recuperacao.md`](mod-termica-PFL7560/12-seguranca-e-recuperacao.md).

## Estrutura do repositório

```
pfl7560-fix.sh              Script principal (status | apply | revert) via adb
pfl7560-menu.sh            Menu amigavel (usado pelo atalho de duplo-clique)
PFL7560-Corrigir.desktop   Atalho de duplo-clique (Linux)
pendrive-autorun/          newlink_update.sh + ZYCustom.ini (metodo pendrive)
mod-termica-PFL7560/       Documentacao tecnica completa (15 docs) + artefatos
  README.md                Indice da pesquisa
  01..14-*.md              Teardown, sistema termico, causa-raiz, build, replicacao, etc.
  artefatos/               ZYCustom.ini (a build), stock, DTB, perfis
INSTALL.md  REQUIREMENTS.md  LICENSE
```

> Os binários proprietários (firmware `.bin`/`.zip` e manuais `.pdf` da Intelbras) e os logs com dados
> pessoais do aparelho **não** vão para o Git (ver `.gitignore`). Baixe o firmware oficial no site da Intelbras.

## Aparelho-alvo

Intelbras PFL7560 · SoC HiSilicon Hi3751V553 · Android 9 (HiDPT) · firmware **V1.0.0.9**. Outras versões
podem diferir — confira antes.

## Licença

[GPLv3](LICENSE). Copyright (C) 2026 os contribuidores deste projeto. Sem garantia; veja a licença.
Marcas, firmware e manuais da Intelbras pertencem à Intelbras — aqui usados apenas para fins de reparo e
interoperabilidade.
