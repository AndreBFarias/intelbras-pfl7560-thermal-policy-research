# Tarefa - Aplicar as curas do doc 49 (2026-11-01, bloco depois do 23)

**Medido** (doc 49, conferido pelo P2): a CPU passa ≈ 80 % ociosa; o `hipluginserver` gasta 31 % de um núcleo e
escreve ≈ 125 linhas/s de log; o AIC8800 (Wi-Fi/BT por USB) nunca suspende; o `eth0` fica UP sem conector.

**Decisões do dono (rodada 1, 2026-11-01):**
- **Medida dos 5 °C: pulada.** As curas entram assumindo que as causas do doc 49 são reais; o uso do dia a dia
  confirma.
- **Debloat:** todos os grupos aprovados, além de VLC e Office (já na `debloat-aprovados.txt` do bloco 23):
  - seguros: `com.newlink.autotest`, `com.newlink.factorymenu`, `com.newlink.tvtestingtools`,
    `com.hikeymasterprovision`, `com.newlink.isuperred.ijkplayerdemo`, `com.android.location.fused`;
  - telemetria e OTA: `com.newlink.service`, `com.newlink.service2` (conferir depois a home, as teclas de atalho
    e o tema);
  - players e menus HiSilicon: `com.hisilicon.android.music`, `.videoplayer`, `.higallery`, `com.hisilicon.tvui`,
    `com.hisilicon.tv.menu` (testar o menu de imagem antes de fixar);
  - launcher de fábrica: `com.newlink.hisilauncher`.
  - **Fora da lista, de propósito:** `com.newlink.screensaver` (a feature 3 do bloco 23 depende dele).
- **Portas 80 e cmdsrv:** deixar como está.
- **Log do vplugin:** silenciar no boot (`setprop log.tag.HI_VPLUGIN S`; reversível). Conferir antes se ele ainda
  aparece com o keystone zerado (doc 46 §13) e se o `setprop` vale para o processo já vivo (INFERIDO no doc 49).

**Cura na origem.** No kit (depois do bloco 23, que mexe nos mesmos arquivos): ampliar a `debloat-aprovados.txt`
e acrescentar o silêncio do log no boot, com a volta pelo mesmo arquivo do pendrive que já desfaz o debloat.

**Como provar.** Testes do kit verdes; no aparelho, `pm list packages -d` mostra a lista, a home, os atalhos e o tema
funcionam, e `logcat -d | grep -c HI_VPLUGIN` cai para zero.

**Anotado em 2026-11-01 (achado do F3, fora do escopo do 23):** depois de gravar a curva do LED, o
`resultados.txt` da suíte diz `escada=ausente` (`suite.sh:799` procura os limiares de fábrica). Só o relatório
erra; a correção térmica não muda. Entra no próximo bloco que tocar a suíte.
