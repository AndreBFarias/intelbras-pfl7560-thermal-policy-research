package com.pfl7560.home;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.bluetooth.BluetoothAdapter;
import android.net.ConnectivityManager;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;

import java.util.Calendar;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class HomeActivity extends Activity implements HomeView.Ouvinte {
    private static final long AVISO_MS = 5000L;
    private static final long LUZ_RELER_MS = 4000L;
    private static final long CURVA_ESPERA_MS = 2500L;
    private static final long CHAVE_ESPERA_MS = 1000L;
    private static final int CHAVE_TENTATIVAS = 20;
    private static final long CHAVE_LER_MS = 2500L;

    private final Handler principal = new Handler(Looper.getMainLooper());
    /** Os pedidos ao projetor, um de cada vez, fora do thread principal. */
    private final ExecutorService fila = Executors.newSingleThreadExecutor();
    private Modelo modelo;
    private HomeView vista;
    private boolean ouvindoTempo;
    private boolean ouvindoPacotes;
    private int geracaoApps;
    /** Quais portas tem cabo (bloco 30), no fio proprio. */
    private HandlerThread fioCabos;
    private Cabos cabos;

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
        conferirLaco();
        modelo = Modelo.padrao();
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

        fioCabos = new HandlerThread("home-cabos");
        fioCabos.start();
        cabos = new Cabos(getApplicationContext(), new Handler(fioCabos.getLooper()), principal, new Cabos.Ouvinte() {
            @Override
            public void entradas(Item[] lista) {
                if (isDestroyed() || modelo == null) return;
                if (modelo.definirEntradas(lista)) vista.invalidate();
            }
        });
    }

    /**
     * Caiu duas vezes em 2 minutos? Entrega a tela inicial de fabrica. As preferencias ficam em disco: a leitura
     * corre fora do thread principal, e a troca volta a ele.
     */
    private void conferirLaco() {
        final Context app = getApplicationContext();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                if (!Guarda.emLaco(app)) return;
                Guarda.limpar(app);
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        if (Abridor.homeDeFabrica(HomeActivity.this)) finish();
                    }
                });
            }
        }, "home-guarda");
        t.start();
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
            f.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
            f.addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED);
            registerReceiver(tempo, f);
            ouvindoTempo = true;
        } catch (RuntimeException e) {
            Guarda.anotar(this, "receptor de tempo", e);
        }
        atualizarRelogio();
        lerEstado();
        if (cabos != null) cabos.ligar();
        // de volta a tela das Ajustes (de outro app, do descanso de tela): le de novo
        if (modelo.ajustesAberta) lerChavesAssincrono();
        vista.requestFocus();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (cabos != null) cabos.desligar();
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
        fila.shutdownNow();
        if (cabos != null) cabos.desligar();
        if (fioCabos != null) fioCabos.quitSafely();
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
        if (modelo == null) return;
        if (modelo.voltar()) vista.invalidate();
    }

    @Override
    public void aplicarCurva() {
        final Curvas cv = modelo.curvas;
        if (cv.pedindo != null) return;
        final boolean vent = cv.aba == Curvas.ABA_VENT;
        final String pedido = cv.pedido();
        cv.pedindo = pedido;
        final Context app = getApplicationContext();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                final boolean ok = Leitor.pedirCurva(app, vent ? "curva-vent" : "curva-led", pedido);
                if (ok) {
                    try {
                        Thread.sleep(CURVA_ESPERA_MS);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                }
                final String[] lido = lerCurvas();
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        cv.pedindo = null;
                        aplicarEstadoCurvas(lido);
                        modelo.aviso = ok ? "Pedido enviado ao projetor" : "Não consegui pedir a curva";
                        vista.invalidate();
                        principal.removeCallbacks(apagarAviso);
                        principal.postDelayed(apagarAviso, AVISO_MS);
                    }
                });
            }
        }, "home-curva");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }

    @Override
    public void alternarLogo() {
        final Curvas cv = modelo.curvas;
        if (cv.pedindo != null) return;
        final String pedido = cv.pedidoLogo();
        cv.pedindo = pedido;
        final Context app = getApplicationContext();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                final boolean ok = Leitor.pedirLogo(app, pedido);
                if (ok) {
                    try {
                        Thread.sleep(CURVA_ESPERA_MS);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                }
                final String[] lido = lerCurvas();
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        cv.pedindo = null;
                        aplicarEstadoCurvas(lido);
                        modelo.aviso = ok ? "Pedido enviado ao projetor" : "Não consegui pedir";
                        vista.invalidate();
                        principal.removeCallbacks(apagarAviso);
                        principal.postDelayed(apagarAviso, AVISO_MS);
                    }
                });
            }
        }, "home-logo");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }

    /**
     * OK numa linha das Ajustes: a tela ja mudou (aplicando) e o pedido entra na fila. A fila manda um pedido de
     * cada vez ao projetor, para um nao apagar o arquivo do outro; o OK nunca e ignorado por haver outro em curso.
     */
    public void aplicarChave() {
        final Ajustes aj = modelo.ajustes;
        if (aj.naLinhaDescanso()) {
            aj.marcarAplicando();
            pedirDescanso();
            return;
        }
        final boolean diario = aj.aba == Ajustes.ABA_DIARIO;
        final String id = aj.idEmFoco();
        final String pedido = aj.marcarAplicando();
        modelo.aviso = null;
        vista.invalidate();
        final Context app = getApplicationContext();
        fila.execute(new Runnable() {
            @Override
            public void run() {
                if (diario) pedirDiario(app, pedido);
                else pedirChave(app, id, pedido);
            }
        });
    }

    /** Roda na fila (fora do thread principal). */
    private void pedirChave(Context app, final String id, String pedido) {
        final String antes = Leitor.propRoot("chaves_aviso");
        final boolean ok = Leitor.pedirChave(app, pedido);
        String aviso = antes;
        if (ok) {
            for (int i = 0; i < CHAVE_TENTATIVAS; i++) {
                try {
                    Thread.sleep(CHAVE_ESPERA_MS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
                aviso = Leitor.propRoot("chaves_aviso");
                if (!aviso.equals(antes) && aviso.startsWith(id + ":")) break;
            }
        }
        final String lido = Leitor.propRoot("chaves");
        final String av = aviso;
        final boolean mudou = ok && !av.equals(antes) && av.startsWith(id + ":");
        principal.post(new Runnable() {
            @Override
            public void run() {
                if (isDestroyed()) return;
                modelo.ajustes.confirmar(id, lido);
                if (!ok) {
                    modelo.aviso = "Não consegui pedir ao projetor";
                } else if (!mudou) {
                    modelo.aviso = "O projetor não respondeu ao pedido";
                } else {
                    String r = Ajustes.rotuloAviso(Ajustes.codigoDoAviso(av, id));
                    modelo.aviso = "Feito".equals(r) ? null : r;
                }
                vista.invalidate();
                principal.removeCallbacks(apagarAviso);
                if (modelo.aviso != null) principal.postDelayed(apagarAviso, AVISO_MS);
            }
        });
    }

    /**
     * Desligar no descanso: a tela ja mostra o alvo (OK ou seta na linha); o pedido entra na mesma fila dos outros.
     * Cada pedido leva o seu numero: so a resposta do ultimo tira o "Aplicando…".
     */
    @Override
    public void pedirDescanso() {
        final Ajustes aj = modelo.ajustes;
        final String pedido = aj.pedidoDescanso();
        final String alvo = aj.descansoAplicando;
        final int n = aj.descansoPedidos;
        if (pedido == null) return;
        modelo.aviso = null;
        vista.invalidate();
        final Context app = getApplicationContext();
        fila.execute(new Runnable() {
            @Override
            public void run() {
                final boolean ok = Leitor.pedirDescanso(app, pedido);
                String lido = Leitor.propRoot("standby_conf");
                if (ok) {
                    for (int i = 0; i < CHAVE_TENTATIVAS && !alvo.equals(lido); i++) {
                        try {
                            Thread.sleep(CHAVE_ESPERA_MS);
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                            break;
                        }
                        lido = Leitor.propRoot("standby_conf");
                    }
                }
                final String fim = lido;
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        modelo.ajustes.confirmarDescanso(n, fim);
                        if (!ok) {
                            modelo.aviso = "Não consegui pedir ao projetor";
                        } else if (!alvo.equals(fim)) {
                            modelo.aviso = "O projetor não respondeu ao pedido";
                        } else {
                            modelo.aviso = null;
                        }
                        vista.invalidate();
                        principal.removeCallbacks(apagarAviso);
                        if (modelo.aviso != null) principal.postDelayed(apagarAviso, AVISO_MS);
                    }
                });
            }
        });
    }

    /** Roda na fila (fora do thread principal). */
    private void pedirDiario(Context app, String pedido) {
        final String antes = Leitor.propRoot("diario");
        final boolean ok = Leitor.pedirDiario(app, pedido);
        String depois = antes;
        if (ok) {
            for (int i = 0; i < CHAVE_TENTATIVAS; i++) {
                try {
                    Thread.sleep(CHAVE_ESPERA_MS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
                depois = Leitor.propRoot("diario");
                if (!depois.equals(antes)) break;
            }
        }
        final String lido = depois;
        final String envio = Leitor.propRoot("diario_envio");
        final boolean mudou = ok && !lido.equals(antes);
        principal.post(new Runnable() {
            @Override
            public void run() {
                if (isDestroyed()) return;
                modelo.ajustes.confirmarDiario(lido, envio);
                if (!ok) {
                    modelo.aviso = "Não consegui pedir ao projetor";
                } else if (!mudou) {
                    modelo.aviso = "O projetor não respondeu ao pedido";
                } else {
                    modelo.aviso = null;
                }
                vista.invalidate();
                principal.removeCallbacks(apagarAviso);
                if (modelo.aviso != null) principal.postDelayed(apagarAviso, AVISO_MS);
            }
        });
    }

    /**
     * Le o estado das Ajustes fora do thread principal. Enquanto a tela esta aberta e falta ler algo (o projetor
     * publica ~60 s depois do boot), tenta de novo a cada 2,5 s; o pedido "v1 ler" ao projetor vai a cada 4 voltas.
     */
    private void lerChavesAssincrono() {
        principal.removeCallbacks(relerAjustes);
        voltaAjustes = 0;
        lerAjustesUmaVez(true);
    }

    private final Runnable relerAjustes = new Runnable() {
        @Override
        public void run() {
            if (modelo == null || !modelo.ajustesAberta || isDestroyed()) return;
            voltaAjustes++;
            lerAjustesUmaVez(voltaAjustes % 4 == 0);
        }
    };
    private int voltaAjustes;

    private void lerAjustesUmaVez(boolean pedir) {
        final Context app = getApplicationContext();
        // com um pedido na fila, o "v1 ler" poderia apagar o arquivo dele: so le as propriedades
        final boolean pedirAoProjetor = pedir && !modelo.ajustes.algumEmCurso();
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                if (pedirAoProjetor) {
                    // a propriedade so muda quando o projetor publica: pede uma leitura nova
                    Leitor.pedirChave(app, Ajustes.PEDIDO_LER);
                    Leitor.pedirDiario(app, Ajustes.PEDIDO_DIARIO_LER);
                    Leitor.pedirDescanso(app, Ajustes.PEDIDO_DESCANSO_LER);
                }
                final String descanso = Leitor.propRoot("standby_conf");
                final String chaves = Leitor.propRoot("chaves");
                final String diario = Leitor.propRoot("diario");
                final String envio = Leitor.propRoot("diario_envio");
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        Ajustes a = modelo.ajustes;
                        if (!chaves.isEmpty()) a.estado = chaves;
                        if (!diario.isEmpty() && a.diarioAplicando == 0) {
                            a.diario = diario;
                            a.diarioEnvio = envio;
                        }
                        if (!descanso.isEmpty() && a.descansoAplicando == null) a.descanso = descanso;
                        vista.invalidate();
                        principal.removeCallbacks(relerAjustes);
                        // a primeira volta sempre rele (o "v1 ler" acabou de sair); depois, so enquanto faltar ler
                        if (modelo.ajustesAberta && (voltaAjustes == 0 || a.precisaLer())) {
                            principal.postDelayed(relerAjustes, CHAVE_LER_MS);
                        }
                    }
                });
            }
        }, "home-ajustes-estado");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
    }

    private static String[] lerCurvas() {
        return new String[] {
            Leitor.propRoot("vent"), Leitor.propRoot("led"), Leitor.propRoot("vent_aviso"), Leitor.propRoot("led_aviso"),
            Leitor.propRoot("logo"), Leitor.propRoot("logo_cantos"), Leitor.propRoot("logo_hora"), Leitor.propRoot("logo_motivo"),
        };
    }

    private void aplicarEstadoCurvas(String[] lido) {
        modelo.curvas.ventEstado = lido[0];
        modelo.curvas.ledEstado = lido[1];
        modelo.curvas.ventAviso = lido[2];
        modelo.curvas.ledAviso = lido[3];
        modelo.curvas.logoEstado = lido[4];
        modelo.curvas.logoCantos = lido[5];
        modelo.curvas.logoHora = lido[6];
        modelo.curvas.logoMotivo = lido[7];
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
        if (Acoes.AJUSTES.equals(item.acao)) {
            modelo.abrirAjustes();
            modelo.aviso = null;
            vista.invalidate();
            lerChavesAssincrono();
            return;
        }
        if (Acoes.CURVAS.equals(item.acao)) {
            modelo.abrirCurvas();
            modelo.aviso = null;
            vista.invalidate();
            lerCurvasAssincrono();
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

    private void lerCurvasAssincrono() {
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                final String[] lido = lerCurvas();
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        aplicarEstadoCurvas(lido);
                        vista.invalidate();
                    }
                });
            }
        }, "home-curvas-estado");
        t.setPriority(Thread.MIN_PRIORITY);
        t.start();
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
                String placa;
                try {
                    placa = Leitor.temperaturaPlaca();
                } catch (Throwable e) {
                    placa = null;
                }
                final String bt = Leitor.bluetooth(app);
                final int luz = Leitor.luzAtual(app);
                final String r = rede;
                final String tt = temp;
                final String tp = placa;
                principal.post(new Runnable() {
                    @Override
                    public void run() {
                        if (isDestroyed()) return;
                        modelo.wifi = r;
                        modelo.temperatura = tt;
                        modelo.temperaturaPlaca = tp;
                        modelo.bluetooth = bt;
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
