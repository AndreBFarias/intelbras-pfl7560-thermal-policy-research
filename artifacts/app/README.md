# app PFL7560 - icones "Verificar projetor" e "Wi-Fi" (bloco 9C)

App Android minimo, sem Gradle, que poe dois icones na lista de apps do projetor. Pacote
`com.pfl7560.verificar`, `minSdk 28`, `targetSdk 28`, **nenhuma permissao**. Documento do conjunto
(suite de boot): `docs/research/44-suite-de-boot.md`.

| Atividade | O que faz |
| --- | --- |
| `VerificarActivity` ("Verificar projetor") | grava `pedir-verificacao` em `getDataDir()` (`/data/data/com.pfl7560.verificar/`, com `FileOutputStream`: o arquivo nasce com o dono certo), mostra "Verificacao pedida" por 3 s e fecha; se nao gravar, diz isso e o que fazer |
| `WifiActivity` ("Wi-Fi") | abre `android.settings.WIFI_SETTINGS`; se nao resolver, `com.zhiying.settings/.network.WifiSettingActivity`; se nada abrir, mostra a mensagem e fecha |

Ambas com `MAIN` + `LAUNCHER` (o launcher do projetor lista so isso: doc 43 secao 6) e tambem
`LEANBACK_LAUNCHER` com `banner`, que custaram pouco. Por que a pasta privada: em `/sdcard` qualquer
app gravaria o pedido e dispararia a suite como root; na pasta privada so o UID do app grava, e o vigia
root (`pendrive-autorun/suite-boot.sh`, `suite-pedido.sh`) confere que o dono do arquivo e o dono da
pasta, com UID de app (>= 10000). O app nao sabe se o pedido foi atendido (a suite ignora pedidos ate 10
min depois de outra), e o vigia so liga no boot: o icone vale a partir do boot **seguinte** a instalacao.

## Compilar

    bash artifacts/app/build.sh
    bash tests/atualizar-md5-kit.sh      # o md5 do APK entra na lista do kit

SDK local, sem rede: `ANDROID_SDK` (padrao `~/Android/sdk`), `BUILD_TOOLS` (35.0.0), `PLATAFORMA`
(android-34); precisa de Java 17 (`javac --release 8`), `zip` e `apksigner`. Passos: `aapt2 compile` e
`link` (recursos, manifest, `R.java`), `javac`, `d8`, dex no zip, `zipalign`, `apksigner sign` e
`verify`. Saida: `artifacts/app/pfl7560.apk` e a copia `pendrive-autorun/pfl7560.apk`. O resultado e
deterministico (o mesmo md5 a cada execucao).

## Versao e assinatura

- `VERSAO_CODIGO` no `build.sh` e `APP_VERSION_CODE` no `pendrive-autorun/newlink_update.sh` tem de ser
  iguais (o `tests/test-kit-pendrive.sh` confere os dois e o `aapt2 dump badging` do APK). O kit instala
  (`pm install -r`) quando o app nao esta instalado ou o versionCode e outro.
- `assinatura.keystore` (PKCS12, alias `pfl7560`, senha no `build.sh`): chave propria e estavel. Nao e
  segredo: so garante que um APK novo instale POR CIMA do anterior. Nao serve para loja.

## Icones

`gerar-icones.py` (Pillow) desenha os PNG de `res/mipmap-*` e os banners de `res/drawable-xhdpi` no
estilo das telas da suite (fundo `#0E1116`, traco claro, acento `#6FD6A6`), sem emoji, e usa a fonte IBM
Plex do kit. A saida e deterministica. `python3 -I artifacts/app/gerar-icones.py`.

## Provas

- `build.sh` gera o APK do zero e `apksigner verify` passa.
- `aapt2 dump badging`: `package: name='com.pfl7560.verificar' versionCode='1'`, `targetSdkVersion:'28'`,
  duas `launchable-activity` e duas `leanback-launchable-activity`; `aapt2 dump permissions`: nenhuma.
- O kit instala o APK (stub de `pm` no `tests/test-kit-pendrive.sh`, caso `c_app`).

## Pendente (aparelho)

- `pm install -r` do APK no aparelho (como root, dentro do `exec` do init), os icones na lista de apps e o
  pedido chegando ao vigia: passos 1, 2, 5 e 6 do roteiro "Teste no aparelho" do doc 44.
