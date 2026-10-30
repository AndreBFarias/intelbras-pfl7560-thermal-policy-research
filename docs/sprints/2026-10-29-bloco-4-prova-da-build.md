# Bloco 4 - prova de que a build é funcional (2026-10-29)

Pedido do dono: **"ao final temos que garantir que nossa build será funcional."** Roda por último,
sobre a árvore de integração com os blocos 1, 2 e 3 (e o bloco da T1.1, se existir).

"Build" aqui são dois entregáveis:
- o `.bin` de firmware (`firmware/PFL7560-FIX-escada-NAO-GRADUADO.bin`, md5 `eae3a83d…`, gerado por
  `artifacts/bin-build/build_fix_bin.py`), e
- o kit de pendrive (`pendrive-autorun/`), mais os scripts de PC.

## Parte A - offline (sem aparelho; o agente prova sozinho)

1. **Reprodutibilidade depois das mudanças:** rodar o builder alterado na T1.5 sobre o stock do zip
   (`28a2f280…`) e o `artifacts/ZYCustom_390.ini` (`252ab7a7…`). O md5 tem que continuar
   `eae3a83db44f790b64b9a5838a27a977`. Se mudar, a mudança do builder alterou a saída: explicar ou
   reverter.
2. **Inspeção do `.bin` gerado:** cabeçalho e `checksum1` (`0x738ebd09`) intactos; faixas divergentes
   só dentro do slot da vendor; dentro da vendor: md5 do `.ini`, modo `0644` dos `.rc`, xattr
   `security.selinux` presente (a causa do brick de julho).
3. **`make check` verde**, `bash -n` e `shellcheck` em todos os `.sh` (sem aviso novo em relação ao
   início do dia), `python3 -m py_compile` no builder.
4. **Kit de pendrive simulado de ponta a ponta** com stubs de `getprop`/`dd`/`md5sum`/`mount`:
   aparelho stock → aplica; roda de novo → não muda nada (**idempotência**); aparelho já corrigido → não
   mexe; `.ini` antigo pré-escada → atualiza.

## Parte B - no aparelho, reversível (precisa do projetor na rede)

5. `pfl7560-saude.sh` verde (12/12, com a seção de cor aceitando VESA).
6. Kit de pendrive aplicado de verdade num boot e, de novo, num segundo boot (idempotência real).
   **Requer um pendrive FAT32** (o dono está sem; custo ~R$ 20).

## Parte C - flash do `.bin` (gate BIN-S4a; risco de brick)

7. Só com **autorização explícita do dono no momento**, e com o kit de resgate pronto antes:
   pendrive FAT32 com o `usb_update.bin` oficial (procedimento no
   [guia 16](../guide/16-recuperacao-brick.md)). Critério: boota, `saude.sh` verde, cor e Wi-Fi intactos.
   Sem esta parte, o `.bin` continua "offline aprovado, hardware não graduado", e os docs precisam dizer
   isso com essas palavras.

## Estado (2026-10-30)

- **Parte A (offline):** as provas que existem são as dos blocos 1, 5 e 6: o stock V1.0.0.9 continua
  gerando `eae3a83d…` (T6.2), e `make check` (9 OK), `make check-kit`, `make check-bin` e `make check-fix`
  passam. Não há registro próprio deste bloco para o item 2 (inspeção do `.bin`).
- **Partes B e C: ABERTAS** — dependem do aparelho na rede, de um pendrive FAT32 e, na C, da autorização
  explícita do dono. **BIN-S4a continua sem boot real:** o `.bin` segue "offline aprovado, hardware não
  graduado".
