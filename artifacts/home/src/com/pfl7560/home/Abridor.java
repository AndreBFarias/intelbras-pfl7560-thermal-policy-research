package com.pfl7560.home;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.provider.Settings;

/**
 * Abre o que cada cartao pede, com os mesmos intents do firmware oficial V1.0.0.9 (doc 45, com a
 * fonte de cada um). Nunca lanca excecao: devolve false se nada abriu.
 */
final class Abridor {
    private static final String ZY = "com.zhiying.settings";

    private Abridor() {
    }

    static boolean abrir(Activity a, Item it) {
        if (it.acao == null) return app(a, it);
        switch (it.acao) {
            case Acoes.HDMI1:
                return entrada(a, "zysys.source.hdmi1", 11);
            case Acoes.HDMI2:
                return entrada(a, "zysys.source.hdmi2", 10);
            case Acoes.USB_C:
                return entrada(a, "zysys.source.typec1", 9);
            case Acoes.VERIFICAR:
                return iniciar(a, componente("com.pfl7560.verificar", "com.pfl7560.verificar.VerificarActivity"));
            case Acoes.WIFI:
                return iniciar(a, acao(Settings.ACTION_WIFI_SETTINGS))
                        || iniciar(a, componente(ZY, ZY + ".network.WifiSettingActivity"));
            case Acoes.BLUETOOTH:
                return iniciar(a, acao(Settings.ACTION_BLUETOOTH_SETTINGS));
            case Acoes.IMAGEM:
                // o item "Projecao" das Configuracoes de fabrica neste aparelho (NLPEntryUtils, doc 45)
                return iniciar(a, acao("android.settings.projection.cra.6d.sen_new"))
                        || iniciar(a, componente(ZY, ZY + ".pictureSetting.pictureModeActivity"))
                        || iniciar(a, acao(Settings.ACTION_SETTINGS));
            case Acoes.CONFIG:
                return iniciar(a, acao(Settings.ACTION_SETTINGS));
            case Acoes.ESPELHAR:
                return iniciar(a, lancador(a, "com.hisilicon.miracast")) || iniciar(a, lancador(a, "com.newlink.cast"));
            default:
                return false;
        }
    }

    /**
     * Entrada de video como o launcher de fabrica faz (MainActivityBx.selectHSSource): NLSourcePlayer
     * com o extra int SourceName = numero da fonte, lido da prop (padrao = valor do build.prop do aparelho).
     */
    private static boolean entrada(Activity a, String prop, int padrao) {
        int id = padrao;
        try {
            String v = Leitor.prop(prop).trim();
            if (!v.isEmpty()) id = Integer.parseInt(v);
        } catch (NumberFormatException e) {
            id = padrao;
        }
        int flags = Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_HISTORY | Intent.FLAG_ACTIVITY_NO_ANIMATION;
        Intent i = componente("com.newlink.nlsource", "com.newlink.nlsource.MainActivity").putExtra("SourceName", id).addFlags(flags);
        Intent j = componente("com.hisilicon.tvui", "com.hisilicon.tvui.MainActivity").putExtra("SourceName", id).addFlags(flags);
        if (iniciar(a, i) || iniciar(a, j)) {
            a.overridePendingTransition(0, 0);
            return true;
        }
        return false;
    }

    private static boolean app(Activity a, Item it) {
        if (it.pacote == null || it.classe == null) return false;
        Intent i = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(new ComponentName(it.pacote, it.classe))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        return iniciar(a, i);
    }

    /** Saida de emergencia da Guarda: o launcher de fabrica (WizardAciticity tem HOME, logo e exportada). */
    static boolean homeDeFabrica(Activity a) {
        return iniciar(a, componente("com.newlink.hisilauncher", "com.newlink.hisilauncher.WizardAciticity"));
    }

    private static Intent acao(String acao) {
        return new Intent(acao).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    }

    private static Intent componente(String pacote, String classe) {
        return new Intent().setComponent(new ComponentName(pacote, classe)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    }

    private static Intent lancador(Activity a, String pacote) {
        try {
            Intent i = a.getPackageManager().getLaunchIntentForPackage(pacote);
            return i == null ? null : i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static boolean iniciar(Activity a, Intent i) {
        if (i == null) return false;
        try {
            a.startActivity(i);
            return true;
        } catch (RuntimeException e) {   // ActivityNotFoundException, SecurityException
            Guarda.anotar(a, "abrir " + i, e);
            return false;
        }
    }
}
