# app PFL7560 - ícones "Verificar projetor" e "Wi-Fi" (bloco 9C)

App Android mínimo, sem Gradle, que põe dois ícones na lista de apps do projetor. Pacote
`com.pfl7560.verificar`, `minSdk 28`, `targetSdk 28`, **nenhuma permissão**. Documento do conjunto
(suíte de boot): `docs/research/44-suite-de-boot.md`.

| Atividade | O que faz |
| --- | --- |
| `VerificarActivity` ("Verificar projetor") | grava `pedir-verificacao` em `getDataDir()` (`/data/data/com.pfl7560.verificar/`, com `FileOutputStream`: o arquivo nasce com o dono certo), mostra "Verificação pedida" por 3 s e fecha; se não gravar, diz isso e o que fazer |
| `WifiActivity` ("Wi-Fi") | abre `android.settings.WIFI_SETTINGS`; se não resolver, `com.zhiying.settings/.network.WifiSettingActivity`; se nada abrir, mostra a mensagem e fecha |

Ambas com `MAIN` + `LAUNCHER` (o launcher do projetor lista só isso: doc 43 seção 6) e também
`LEANBACK_LAUNCHER` com `banner`, que custaram pouco. Por que a pasta privada: em `/sdcard` qualquer
app gravaria o pedido e dispararia a suíte como root; na pasta privada só o UID do app grava, e o vigia
root (`pendrive-autorun/suite-boot.sh`, `suite-pedido.sh`) confere que o dono do arquivo é o dono da
pasta, com UID de app (>= 10000). O app não sabe se o pedido foi atendido (a suíte ignora pedidos até 10
min depois de outra), e o vigia só liga no boot: o ícone vale a partir do boot **seguinte** à instalação.

## Compilar

    bash artifacts/app/build.sh
    bash tests/atualizar-md5-kit.sh      # o md5 do APK entra na lista do kit

SDK local, sem rede: `ANDROID_SDK` (padrão `~/Android/sdk`), `BUILD_TOOLS` (35.0.0), `PLATAFORMA`
(android-34); precisa de Java 17 (`javac --release 8`), `zip` e `apksigner`. Passos: `aapt2 compile` e
`link` (recursos, manifest, `R.java`), `javac`, `d8`, dex no zip, `zipalign`, `apksigner sign` e
`verify`. Saída: `artifacts/app/pfl7560.apk` e a cópia `pendrive-autorun/pfl7560.apk`. O resultado é
determinístico (o mesmo md5 a cada execução).

## Versão e assinatura

- `VERSAO_CODIGO` no `build.sh` e `APP_VERSION_CODE` no `pendrive-autorun/newlink_update.sh` têm de ser
  iguais (o `tests/test-kit-pendrive.sh` confere os dois e o `aapt2 dump badging` do APK). O kit põe o APK em
  `/vendor/app/PFL7560/` como app do sistema quando ele falta ou difere: o `pm install` deste firmware recusa
  apps de fora (`INSTALL_FAILED_INVALID_INSTALL_LOCATION`, visto no aparelho em 2026-10-30).
- `assinatura.keystore` (PKCS12, alias `pfl7560`, senha no `build.sh`): chave própria e estável. Não é
  segredo: só garante que um APK novo instale POR CIMA do anterior. Não serve para loja.
- O APK leva os esquemas de assinatura v1, v2 e v3. O `apksigner verify` sem opções lista só o v3 (com
  `minSdk 28` ele só confere o que o Android 9 exige); `apksigner verify -v --min-sdk-version 23` mostra os três.

## Ícones

`gerar-icones.py` (Pillow) desenha os PNG de `res/mipmap-*` e os banners de `res/drawable-xhdpi` na
paleta Drácula das telas da suíte (bloco 10B, `artifacts/tema/`): fundo `#282A36`, cartão `#44475A` com
contorno `#6272A4`, traço `#F8F8F2`, o visto do Verificar em verde `#50FA7B` e o ponto do Wi-Fi em roxo
`#BD93F9`, sem emoji, e usa a fonte IBM Plex do kit. As cores das mensagens de 3 s (`res/values/styles.xml`)
são as mesmas: fundo, texto, secundário `#B4BCCF` (o comentário clareado, ver `artifacts/tema/README.md`)
e atenção `#FF5555`. A saída é determinística. `python3 -I artifacts/app/gerar-icones.py`.

## Provas

- `build.sh` gera o APK do zero e `apksigner verify` passa.
- `aapt2 dump badging`: `package: name='com.pfl7560.verificar' versionCode='2'` (o 2 é o do tema Drácula, bloco 10B), `targetSdkVersion:'28'`,
  duas `launchable-activity` e duas `leanback-launchable-activity`; `aapt2 dump permissions`: nenhuma.
- O kit instala o APK (stub de `pm` no `tests/test-kit-pendrive.sh`, caso `c_app`).

## Pendente (aparelho)

- Provado por rede em 2026-10-30: o app em `/vendor/app` (`flags=[ SYSTEM ]`) e o pedido do "Verificar
  projetor" chegando ao vigia. Falta ver os ícones na lista de apps com o controle (passo 5 do doc 44).
