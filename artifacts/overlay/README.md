# Sobreposições Drácula do sistema do fabricante (bloco 13A)

Pedido do dono (2026-10-31): "Dentro das configs segue o tema antigo". As telas do fabricante passam
para a paleta do bloco 10 (`artifacts/tema/dracula.txt`) por **sobreposição de recursos em tempo
de execução** (RRO). Nenhum app do fabricante é alterado: cada APK daqui só traz cores e imagens, e
o Android as troca na hora de desenhar. Mapa completo, limites e saída de emergência:
`docs/research/48-tema-no-sistema.md`.

| APK (`apk/`) | Pacote | Alvo | O que troca |
| --- | --- | --- | --- |
| `PFL7560TemaZYSetting.apk` | `com.pfl7560.tema.zysetting` | `com.zhiying.settings` | fundo verde das Configurações e do Wi-Fi, os 4 cartões, a moldura de foco (rosa), a chave Ligado/Desligado, a janela de senha do Wi-Fi e o aviso "Deseja abrir HDMI1?" |
| `PFL7560TemaNLProvision.apk` | `com.pfl7560.tema.nlprovision` | `com.newlink.nlprovision` | os avisos próprios dele (painel, botão OK, toast) |
| `PFL7560TemaAndroid.apk` | `com.pfl7560.tema.android` | `android` | **só 3 cores** do diálogo claro do Leanback, onde cai o "Temperatura anormal". Instalar por último |

| Arquivo | O que é |
| --- | --- |
| `build.sh` | gera os três APKs do zero (`aapt2 compile/link`, `zipalign`, `apksigner`); reprodutível (mesmo md5) |
| `conferir.py` | confere cada APK contra o APK do alvo extraído do firmware: mesmo nome e **mesmo tipo**, todas as configurações do alvo cobertas, nenhum valor com referência, só `color` e `drawable` |
| `recolorir.py` | gera as imagens recoloridas de `zysetting/res/` a partir do app desmontado (roda uma vez por firmware) |
| `gerar-previa.py` | desenha `previa/antes-depois.png`, as cinco telas antes e depois, com os valores |
| `assinatura.keystore` | chave própria e estável (alias `pfl7560tema`, senha no `build.sh`; não é segredo) |

    bash artifacts/overlay/build.sh
    python3 -I artifacts/overlay/conferir.py <pasta com ZYSetting.apk, NLProvision.apk e framework-res.apk do firmware>

Instalação (não feita; o coordenador integra ao kit): `/vendor/overlay/<Nome>/<Nome>.apk`, pasta
0755 e arquivo 0644 de root, rótulo `vendor_overlay_file`, reboot, depois `cmd overlay enable
<pacote>`. Não estáticas: `cmd overlay disable <pacote>` desfaz na hora. Passo a passo no doc 48, §6.
