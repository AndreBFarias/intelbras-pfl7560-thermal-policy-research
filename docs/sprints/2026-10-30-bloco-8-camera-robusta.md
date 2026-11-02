# Bloco 8 - câmera robusta e prova no aparelho com reboot (2026-10-30)

Pedido do dono: "melhora o sistema de câmera; será manualmente o contrário, reinicia e testa pra ver
se deu certo", e "verifica se a rampa de temperatura nossa funciona". Segue o
[bloco 7](2026-10-30-bloco-7-cor-automatica.md).

## O que se mediu

1. **A 2ª execução do bloco 7 (a partir de VESA) não terminou.** O log parou em `tela: aguarde`, a
   pasta de trabalho ficou e nada foi gravado. O projetor foi desligado pelo dono depois disso
   (`sys.boot.reason = shutdown,userrequested`); a causa mais provável é o desligamento no meio da
   espera do autofoco (até 90 s), não confirmada. Ficou em VESA porque o teste partia de VESA.
2. **Numa nova execução a partir de VESA, a câmera achou 10 faixas (de 16)** e o kit caiu no fluxo
   manual; sem tecla, manteve VESA. Nada foi gravado.
3. **Causa:** a imagem projetada sai inclinada para a câmera (a correção de quatro pontos roda no
   boot, `FourPointActivity`). As faixas de baixo descem ~45 px de um lado ao outro do quadro de
   640 px. O perfil de linhas tirava a média das colunas de 35 a 65 % da largura: nessa janela cada
   faixa escorre sobre a vizinha e os vãos não escurecem (vão ~135 contra pico ~180, limiar 125). A
   imagem em si está nítida (MJPG 1280x720 do mesmo instante).
4. **Teste no PC sobre os quadros reais:** com a janela de 47 a 53 %, as 16 faixas aparecem em todos
   os quadros (os de 16:15, que já passavam, e os inclinados de 18:45 e 19:04), e as decisões não
   mudam (JEIDA monótona, VESA com 3 inversões). Em YUYV 1280x720 os vãos vão ao preto (16 a 19).
5. **Orientação:** o quadro da câmera é **espelhado de cima para baixo**, não girado 180°: girando
   180° o texto do menu sai espelhado. A análise não depende disso.

## Cura (feita)

- `nl_camcheck.c`: janela de colunas 47 a 53 %; captura prefere YUYV 1280x720, senão 640x480, senão o
  menor. Binário ARM novo (NDK r27c) `a6667095…`, `NLCAM_MD5` do `cor.sh` e lista do
  `newlink_update.sh` regravados pelo script.
- `tests/test-camcheck.sh`: 6 quadros reais novos (640x480 inclinado em JEIDA; 1280x720 em JEIDA e
  VESA) e a janela conferida; valores de JEIDA/VESA de 640x480 remedidos com a janela nova.

## Prova

| Prova | Resultado |
|---|---|
| `make check`, `check-kit` (36 + 487), `check-fix` (48) | verdes, 0 falha |
| VESA gravado à mão (`lvdsctl fmt 0`, `92c63448`), reboot, kit real via adb | 16 faixas; escada `235 235 235 235 195 141 71 25 228 177 162 44 195 102 198 97` (3 inversões); troca para JEIDA; escada em ordem; tela "corrigida", sem tecla; partição `4899eefc` (só o byte 0x5c mudou); gancho e pasta de trabalho removidos |
| Reboot de novo, kit outra vez | boot em JEIDA (`4899eefc`); 16 faixas; escada em ordem; **nada escrito** |
| Rampa térmica: `pfl7560-saude.sh` | 10 OK, 0 falha (escada 66 a 73 °C, piso 850, mux comutando) |
| Rampa térmica: `pfl7560-saude.sh --vivacidade` | 71 °C simulados: 38 avisos de Overheat, brilho caiu para 850 e voltou a 1000 sozinho, override limpo |

## Fora deste bloco (anotado)

- A rampa foi provada com temperatura simulada; uma sessão longa de uso real
  (`pfl7560-monitor-termico.sh`) mostraria os degraus intermediários (66 a 70 °C) agindo.
- Pendrive FAT32 real (E4 do bloco 5) e prova de leigo (E6) continuam abertos.
