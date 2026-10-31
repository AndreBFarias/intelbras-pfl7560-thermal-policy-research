package com.pfl7560.home;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

final class Guarda {
    static final String TAG = "pfl7560.home";
    private static final String PREFS = "guarda";
    private static final String CHAVE = "quedas";
    private static final long JANELA_MS = 120000L;
    private static final int LIMITE = 2;
    private static boolean instalada;

    private Guarda() {
    }

    static synchronized void instalar(final Context app) {
        if (instalada) return;
        instalada = true;
        final Thread.UncaughtExceptionHandler antes = Thread.getDefaultUncaughtExceptionHandler();
        Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread t, Throwable e) {
                try {
                    anotarQueda(app);
                } catch (Throwable ignorada) {
                }
                if (antes != null) antes.uncaughtException(t, e);
            }
        });
    }

    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static void anotarQueda(Context c) {
        long agora = System.currentTimeMillis();
        StringBuilder sb = new StringBuilder();
        int n = 0;
        for (long t : quedas(c)) {
            if (agora - t < JANELA_MS && n < 4) {
                sb.append(t).append(',');
                n++;
            }
        }
        sb.append(agora);
        prefs(c).edit().putString(CHAVE, sb.toString()).commit();
    }

    static boolean emLaco(Context c) {
        long agora = System.currentTimeMillis();
        int n = 0;
        for (long t : quedas(c)) if (agora - t >= 0 && agora - t < JANELA_MS) n++;
        return n >= LIMITE;
    }

    static void limpar(Context c) {
        prefs(c).edit().remove(CHAVE).apply();
    }

    private static long[] quedas(Context c) {
        String s = prefs(c).getString(CHAVE, "");
        if (s == null || s.isEmpty()) return new long[0];
        String[] p = s.split(",");
        long[] r = new long[p.length];
        for (int i = 0; i < p.length; i++) {
            try {
                r[i] = Long.parseLong(p[i].trim());
            } catch (NumberFormatException e) {
                r[i] = 0;
            }
        }
        return r;
    }

    static void anotar(Context c, String onde, Throwable e) {
        Log.w(TAG, onde, e);
    }
}
