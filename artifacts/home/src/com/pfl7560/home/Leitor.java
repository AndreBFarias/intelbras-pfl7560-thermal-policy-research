package com.pfl7560.home;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.text.Collator;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Leituras feitas fora da thread da interface: lista de apps, rede e temperatura. Sem root. */
final class Leitor {
    /**
     * Fora da fileira de Apps. Os 4 primeiros e o proprio launcher sao a lista negra do launcher de
     * fabrica (RGTPLauncher, AppUtils.<clinit>, doc 43 secao 6); depois os nossos. Os apps que o dono
     * mandou desligar (Office, iOSCast, Espelhamento) ficam em Modelo.OCULTOS.
     */
    static final Set<String> FORA = new HashSet<String>(Arrays.asList(
            "com.qiyivideo.sibichi", "com.jrm.localmm", "com.gitvvideo.shanghaishijiu", "org.mozilla.tv.firefox",
            "com.newlink.hisilauncher",
            "com.pfl7560.home", "com.pfl7560.verificar"));

    private Leitor() {
    }

    /** MAIN+LAUNCHER, como o launcher de fabrica, menos FORA, ordenado pelo nome. */
    static List<Item> apps(Context c) {
        PackageManager pm = c.getPackageManager();
        Intent i = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> lista = pm.queryIntentActivities(i, 0);
        List<Item> r = new ArrayList<Item>();
        if (lista == null) return r;
        for (ResolveInfo ri : lista) {
            ActivityInfo a = ri.activityInfo;
            if (a == null || FORA.contains(a.packageName)) continue;
            String rotulo = a.packageName;
            try {
                CharSequence cs = ri.loadLabel(pm);
                if (cs != null && cs.toString().trim().length() > 0) rotulo = cs.toString().trim();
            } catch (RuntimeException e) {
                Guarda.anotar(c, "rotulo " + a.packageName, e);
            }
            r.add(Item.app(rotulo, a.packageName, a.name));
        }
        final Collator col = Collator.getInstance(new Locale("pt", "BR"));
        col.setStrength(Collator.PRIMARY);
        Collections.sort(r, new Comparator<Item>() {
            @Override
            public int compare(Item x, Item y) {
                return col.compare(x.rotulo, y.rotulo);
            }
        });
        return r;
    }

    /** Nome da rede Wi-Fi, "Sem rede", "Cabo de rede" ou "Wi-Fi conectado" (quando o nome vem escondido). */
    static String rede(Context c) {
        ConnectivityManager cm = (ConnectivityManager) c.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo ni = cm == null ? null : cm.getActiveNetworkInfo();
        if (ni == null || !ni.isConnected()) return "Sem rede";
        if (ni.getType() == ConnectivityManager.TYPE_ETHERNET) return "Cabo de rede";
        if (ni.getType() != ConnectivityManager.TYPE_WIFI) return "Conectado";
        String nome = null;
        try {
            WifiManager wm = (WifiManager) c.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            WifiInfo wi = wm == null ? null : wm.getConnectionInfo();
            if (wi != null) nome = ssid(wi.getSSID());
        } catch (RuntimeException e) {
            Guarda.anotar(c, "wifi", e);
        }
        // Android 9 esconde o SSID do WifiInfo sem permissao de localizacao; o extraInfo da rede ativa ainda o traz
        if (nome == null) nome = ssid(ni.getExtraInfo());
        return nome != null ? nome : "Wi-Fi conectado";
    }

    private static String ssid(String s) {
        if (s == null) return null;
        s = s.trim();
        if (s.length() >= 2 && s.startsWith("\"") && s.endsWith("\"")) s = s.substring(1, s.length() - 1);
        if (s.isEmpty() || s.equals("<unknown ssid>") || s.equals("0x")) return null;
        return s;
    }

    /**
     * Temperatura do LED (zysys.env_temp, o sensor gtt1 no bloco do LED; doc 40 secao 3) em graus
     * inteiros, ou null se a prop nao for legivel por um app comum (SELinux) ou vier sem numero.
     */
    static String temperatura() {
        String v = prop("zysys.env_temp");
        StringBuilder num = new StringBuilder();
        for (char ch : v.toCharArray()) if ((ch >= '0' && ch <= '9') || ch == '.') num.append(ch);
        try {
            float f = Float.parseFloat(num.toString());
            if (f <= 0 || f > 150) return null;
            return String.valueOf(Math.round(f));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * Luz atual em %: o numero que o root publica na prop vendor.pfl7560.luz (ver suite-pedido.sh),
     * lido com getprop; 100 se a prop nao existe, esta vazia ou fora de 10..100. O root nao escreve
     * na pasta do app (revisao de seguranca).
     */
    static int luzAtual(Context c) {
        Process p = null;
        try {
            p = new ProcessBuilder("getprop", "vendor.pfl7560.luz").redirectErrorStream(true).start();
            byte[] b = new byte[8];
            int n = p.getInputStream().read(b);
            if (n <= 0) return 100;
            int v = Integer.parseInt(new String(b, 0, n, "US-ASCII").trim());
            return v >= 10 && v <= 100 ? v : 100;
        } catch (IOException | RuntimeException e) {
            return 100;
        } finally {
            if (p != null) p.destroy();
        }
    }

    /**
     * Pede a luz: grava so os digitos no arquivo luz da pasta do app. Quem aplica e o vigia root
     * (suite-pedido.sh); o app nao tem como falar com o hidebug. Devolve false se nao gravou.
     */
    static boolean pedirLuz(Context c, int nivel) {
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), "luz"))) {
            out.write(String.valueOf(nivel).getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir luz", e);
            return false;
        }
    }

    /** android.os.SystemProperties.get por reflexao (API escondida, liberada para targetSdk 28). "" se falhar. */
    static String prop(String nome) {
        try {
            Class<?> k = Class.forName("android.os.SystemProperties");
            Object r = k.getMethod("get", String.class, String.class).invoke(null, nome, "");
            return r == null ? "" : r.toString();
        } catch (Throwable t) {
            return "";
        }
    }
}
