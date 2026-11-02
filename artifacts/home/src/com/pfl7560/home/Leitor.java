package com.pfl7560.home;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.provider.Settings;

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

final class Leitor {
    static final Set<String> FORA = new HashSet<String>(Arrays.asList(
            "com.qiyivideo.sibichi", "com.jrm.localmm", "com.gitvvideo.shanghaishijiu", "org.mozilla.tv.firefox",
            "com.newlink.hisilauncher",
            "com.pfl7560.home", "com.pfl7560.verificar"));

    private Leitor() {
    }

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
        r.add(new Item("Ajustes do sistema", Icones.AJUSTES, Acoes.AJUSTES));
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

    /** Temperatura do LED (zysys.env_temp). */
    static String temperatura() {
        return graus(prop("zysys.env_temp"));
    }

    /** Temperatura da placa: zysys.light_temp e o termistor 0 (POLICY_0), doc 50. Nunca gtt/stp. */
    static String temperaturaPlaca() {
        return graus(prop("zysys.light_temp"));
    }

    /** "Bluetooth desligado", "Bluetooth conectado" (fone ou caixa) ou "Bluetooth ligado"; null se nao deu para ler. */
    static String bluetooth(Context c) {
        try {
            BluetoothAdapter ba = BluetoothAdapter.getDefaultAdapter();
            if (ba == null) return null;
            int s = ba.getState();
            if (s == BluetoothAdapter.STATE_OFF || s == BluetoothAdapter.STATE_TURNING_OFF) return "Bluetooth desligado";
            // A2DP (2), HEADSET (1) e A2DP_SINK (11): o que um projetor liga de verdade
            for (int perfil : new int[] {BluetoothProfile.A2DP, BluetoothProfile.HEADSET, 11}) {
                if (ba.getProfileConnectionState(perfil) == BluetoothProfile.STATE_CONNECTED) return "Bluetooth conectado";
            }
            return "Bluetooth ligado";
        } catch (RuntimeException e) {
            Guarda.anotar(c, "bluetooth", e);
            try {
                return Settings.Global.getInt(c.getContentResolver(), "bluetooth_on", 0) != 0 ? "Bluetooth ligado" : "Bluetooth desligado";
            } catch (RuntimeException e2) {
                return null;
            }
        }
    }

    private static String graus(String v) {
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

    static boolean pedirLuz(Context c, int nivel) {
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), "luz"))) {
            out.write(String.valueOf(nivel).getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir luz", e);
            return false;
        }
    }

    static boolean pedirCurva(Context c, String nome, String pedido) {
        if (!Curvas.pedidoValido(pedido)) return false;
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), nome))) {
            out.write(pedido.getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir " + nome, e);
            return false;
        }
    }

    static boolean pedirLogo(Context c, String pedido) {
        if (!Curvas.pedidoLogoValido(pedido)) return false;
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), "logo-auto"))) {
            out.write(pedido.getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir logo-auto", e);
            return false;
        }
    }

    static boolean pedirChave(Context c, String pedido) {
        if (!Ajustes.pedidoValido(pedido)) return false;
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), "chave"))) {
            out.write(pedido.getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir chave", e);
            return false;
        }
    }

    static boolean pedirDiario(Context c, String pedido) {
        if (!Ajustes.pedidoDiarioValido(pedido)) return false;
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), "diario"))) {
            out.write(pedido.getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir diario", e);
            return false;
        }
    }

    static boolean pedirDescanso(Context c, String pedido) {
        if (!Ajustes.pedidoDescansoValido(pedido)) return false;
        try (FileOutputStream out = new FileOutputStream(new File(c.getDataDir(), "standby"))) {
            out.write(pedido.getBytes("US-ASCII"));
            return true;
        } catch (IOException | RuntimeException e) {
            Guarda.anotar(c, "pedir standby", e);
            return false;
        }
    }

    static String propRoot(String nome) {
        Process p = null;
        try {
            p = new ProcessBuilder("getprop", "vendor.pfl7560." + nome).redirectErrorStream(true).start();
            byte[] b = new byte[64];
            int n = p.getInputStream().read(b);
            if (n <= 0) return "";
            return new String(b, 0, n, "US-ASCII").trim();
        } catch (IOException | RuntimeException e) {
            return "";
        } finally {
            if (p != null) p.destroy();
        }
    }

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
