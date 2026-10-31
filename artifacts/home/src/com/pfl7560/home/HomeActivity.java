package com.pfl7560.home;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import java.util.Calendar;
import java.util.Collections;
import java.util.List;

public class HomeActivity extends Activity implements HomeView.Ouvinte {
    private static final long AVISO_MS = 5000L;
    private static final long LUZ_RELER_MS = 4000L;

    private final Handler principal = new Handler(Looper.getMainLooper());
    private Modelo modelo;
    private HomeView vista;
    private boolean ouvindoTempo;
    private boolean ouvindoPacotes;
    private int geracaoApps;

    private final BroadcastReceiver tempo = new BroadcastReceiver() {
        @Override
        public void onReceive(Context c, Intent i) {
            atualizarRelogio();
            lerEstado();
        }
    };

    private final BroadcastReceiver pacotes = new BroadcastReceiver() {
        @Override
        public void onReceive(Context c, Intent i) {
            carregarApps();
        }
    };

    private final Runnable reler = new Runnable() {
        @Override
        public void run() {
            lerEstado();
        }
    };

    private final Runnable apagarAviso = new Runnable() {
        @Override
        public void run() {
            if (modelo != null && modelo.aviso != null) {
                modelo.aviso = null;
                vista.invalidate();
            }
        }
    };

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        Guarda.instalar(getApplicationContext());
        if (Guarda.emLaco(this)) {
            Guarda.limpar(this);
            if (Abridor.homeDeFabrica(this)) {
                finish();
                return;
            }
        }
        modelo = Modelo.padrao(Leitor.temUsbC());
        modelo.relogio(Calendar.getInstance());
        vista = new HomeView(this, modelo, this);
        setContentView(vista);
        vista.requestFocus();

        try {
            IntentFilter f = new IntentFilter();
            f.addAction(Intent.ACTION_PACKAGE_ADDED);
            f.addAction(Intent.ACTION_PACKAGE_REMOVED);
            f.addAction(Intent.ACTION_PACKAGE_CHANGED);
            f.addAction(Intent.ACTION_PACKAGE_REPLACED);
            f.addDataScheme("package");
            registerReceiver(pacotes, f);
            ouvindoPacotes = true;
        } catch (RuntimeException e) {
            Guarda.anotar(this, "receptor de pacotes", e);
        }
        carregarApps();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (modelo == null) return;
        try {
            IntentFilter f = new IntentFilter();
            f.addAction(Intent.ACTION_TIME_TICK);
            f.addAction(Intent.ACTION_TIME_CHANGED);
            f.addAction(Intent.ACTION_TIMEZONE_CHANGED);
            f.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
            f.addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION);
            registerReceiver(tempo, f);
            ouvindoTempo = true;
        } catch (RuntimeException e) {
            Guarda.anotar(this, "receptor de tempo", e);
        }
        atualizarRelogio();
        lerEstado();
        vista.requestFocus();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (ouvindoTempo) {
            try {
                unregisterReceiver(tempo);
            } catch (RuntimeException e) {
                Guarda.anotar(this, "desligar receptor de tempo", e);
            }
            ouvindoTempo = false;
        }
    }

    @Override
    protected void onDestroy() {
        principal.removeCallbacksAndMessages(null);
        if (ouvindoPacotes) {
            try {
                unregisterReceiver(pacotes);
            } catch (RuntimeException e) {
                Guarda.anotar(this, "desligar receptor de pacotes", e);
            }
            ouvindoPacotes = false;
        }
        super.onDestroy();
    }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        if (modelo == null) return;
        modelo.inicio();
        modelo.aviso = null;
        vista.invalidate();
    }

    @Override
    public void onBackPressed() {
        if (modelo != null && modelo.luzAberta) {
            modelo.fecharLuz();
            modelo.aviso = null;
            vista.invalidate();
        }
    }

    @Override
    public void aplicarLuz(final int nivel) {
        final Context app = getApplicationContext();
        modelo.luz = nivel;
        modelo.aviso = null;
        vista.invalidate();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                final boolean ok = Leitor.pedirLuz(app, nivel);
                final int atual = ok ? nivel : Leitor.luzAtual(app);
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        if (!ok) {
                            modelo.luz = atual;
                            modelo.aviso = "Não consegui pedir a luz";
                        }
                        vista.invalidate();
                        principal.removeCallbacks(apagarAviso);
                        principal.postDelayed(apagarAviso, AVISO_MS);
                        principal.removeCallbacks(reler);
                        principal.postDelayed(reler, LUZ_RELER_MS);
                    }
                });
            }
        }, "home-luz");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }

    @Override
    public void abrir(Item item) {
        if (Acoes.LUZ.equals(item.acao)) {
            modelo.abrirLuz();
            modelo.aviso = null;
            vista.invalidate();
            return;
        }
        boolean ok;
        try {
            ok = Abridor.abrir(this, item);
        } catch (RuntimeException e) {
            Guarda.anotar(this, "abrir " + item.rotulo, e);
            ok = false;
        }
        principal.removeCallbacks(apagarAviso);
        modelo.aviso = ok ? null : "Não abriu: " + item.rotulo;
        vista.invalidate();
        if (!ok) principal.postDelayed(apagarAviso, AVISO_MS);
    }

    private void atualizarRelogio() {
        modelo.relogio(Calendar.getInstance());
        vista.invalidate();
    }

    private void carregarApps() {
        final int geracao = ++geracaoApps;
        final Context app = getApplicationContext();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                List<Item> lista;
                try {
                    lista = Leitor.apps(app);
                } catch (Throwable e) {
                    Guarda.anotar(app, "lista de apps", e);
                    lista = Collections.emptyList();
                }
                final List<Item> fim = lista;
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed() || geracao != geracaoApps) return;
                        modelo.definirApps(fim);
                        vista.invalidate();
                    }
                });
            }
        }, "home-apps");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }

    private void lerEstado() {
        final Context app = getApplicationContext();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                String rede;
                String temp;
                try {
                    rede = Leitor.rede(app);
                } catch (Throwable e) {
                    Guarda.anotar(app, "rede", e);
                    rede = null;
                }
                try {
                    temp = Leitor.temperatura();
                } catch (Throwable e) {
                    temp = null;
                }
                final int luz = Leitor.luzAtual(app);
                final String r = rede;
                final String tt = temp;
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        modelo.wifi = r;
                        modelo.temperatura = tt;
                        modelo.luz = luz;
                        vista.invalidate();
                    }
                });
            }
        }, "home-estado");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }
}
