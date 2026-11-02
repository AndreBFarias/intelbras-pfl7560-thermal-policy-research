package com.pfl7560.verificar;

import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Descanso extends DreamService {
    private static final long MINUTO_MS = 60000L;
    private static final long TRANSICAO_MS = 3000L;
    private static final long SONDA_MS = 5000L;
    private static final long SONDA_INICIO_MS = 9 * MINUTO_MS;
    private static final long AVISO_MS = 60000L;
    private static final String PROP_STANDBY = "vendor.pfl7560.standby";
    private static final String FONTE = "fontes/IBMPlexSansCondensed-Bold.ttf";
    private static final float[][] LUGARES = {
        {0f, 0f}, {-0.7f, -0.6f}, {0.7f, 0.5f}, {-0.6f, 0.6f}, {0.6f, -0.5f},
    };

    private static final ExecutorService PEDIDOS = Executors.newSingleThreadExecutor();

    private final Handler maos = new Handler(Looper.getMainLooper());
    private final SimpleDateFormat formato = new SimpleDateFormat("HH:mm", Locale.US);
    private FrameLayout raiz;
    private LinearLayout conjunto;
    private TextView hora;
    private TextView aviso;
    private int lugar;
    private long avisoDesde;
    private final Runnable tique = new Runnable() {
        @Override
        public void run() {
            hora.setText(formato.format(new Date()));
            mover();
            long agora = System.currentTimeMillis();
            maos.postDelayed(this, MINUTO_MS - agora % MINUTO_MS);
        }
    };

    private final Runnable sonda = new Runnable() {
        @Override
        public void run() {
            PEDIDOS.execute(new Runnable() {
                @Override
                public void run() {
                    final String valor = lerProp();
                    maos.post(new Runnable() {
                        @Override
                        public void run() {
                            reagir(valor);
                        }
                    });
                }
            });
            maos.postDelayed(this, SONDA_MS);
        }
    };

    private final Runnable contagem = new Runnable() {
        @Override
        public void run() {
            mostrarAviso();
            maos.postDelayed(this, 1000L);
        }
    };

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);

        DisplayMetrics dm = getResources().getDisplayMetrics();
        Typeface negrito = fonte();

        raiz = new FrameLayout(this);
        raiz.setBackgroundColor(getColor(R.color.marca_fundo));

        conjunto = new LinearLayout(this);
        conjunto.setOrientation(LinearLayout.VERTICAL);
        conjunto.setGravity(Gravity.CENTER_HORIZONTAL);

        TextView nome = new TextView(this);
        nome.setText(nomeColorido());
        nome.setTextColor(getColor(R.color.marca_nome));
        nome.setTypeface(negrito);
        nome.setTextSize(TypedValue.COMPLEX_UNIT_PX, dm.widthPixels * 160f / 1920f);
        nome.setIncludeFontPadding(false);
        conjunto.addView(nome);

        hora = new TextView(this);
        hora.setText(formato.format(new Date()));
        hora.setTextColor(getColor(R.color.marca_hora));
        hora.setTypeface(negrito);
        hora.setTextSize(TypedValue.COMPLEX_UNIT_PX, dm.widthPixels * 64f / 1920f);
        hora.setIncludeFontPadding(false);
        hora.setPadding(0, (int) (dm.widthPixels * 16f / 1920f), 0, 0);
        conjunto.addView(hora);

        raiz.addView(conjunto, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER));

        aviso = new TextView(this);
        aviso.setTextColor(getColor(R.color.marca_hora));
        aviso.setTypeface(negrito);
        aviso.setTextSize(TypedValue.COMPLEX_UNIT_PX, dm.widthPixels * 48f / 1920f);
        aviso.setGravity(Gravity.CENTER);
        aviso.setVisibility(android.view.View.GONE);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        lp.bottomMargin = (int) (dm.widthPixels * 96f / 1920f);
        raiz.addView(aviso, lp);
        setContentView(raiz);
    }

    @Override
    public void onDreamingStarted() {
        super.onDreamingStarted();
        lugar = 0;
        avisoDesde = 0L;
        esconderAviso();
        maos.removeCallbacks(tique);
        maos.removeCallbacks(sonda);
        maos.postDelayed(sonda, SONDA_INICIO_MS);
        hora.setText(formato.format(new Date()));
        maos.postDelayed(tique, MINUTO_MS - System.currentTimeMillis() % MINUTO_MS);
        pedir("descanso-inicio");
    }

    @Override
    public void onDreamingStopped() {
        maos.removeCallbacks(tique);
        maos.removeCallbacks(sonda);
        maos.removeCallbacks(contagem);
        pedir("descanso-fim");
        super.onDreamingStopped();
    }

    // "Meow" no roxo da marca (a cor do TextView) e "Cast" no verde Dracula, como no logo (bloco 28).
    private CharSequence nomeColorido() {
        String texto = getString(R.string.descanso_nome);
        int i = texto.indexOf("Cast");
        if (i < 0) return texto;
        SpannableString s = new SpannableString(texto);
        s.setSpan(new ForegroundColorSpan(getColor(R.color.marca_cast)), i, i + 4, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        return s;
    }

    private void pedir(final String nome) {
        final File f = new File(getDataDir(), nome);
        PEDIDOS.execute(new Runnable() {
            @Override
            public void run() {
                try (FileOutputStream o = new FileOutputStream(f)) {
                    o.write('1');
                } catch (IOException e) {
                }
            }
        });
    }

    private String lerProp() {
        Process p = null;
        try {
            p = new ProcessBuilder("/system/bin/getprop", PROP_STANDBY).redirectErrorStream(true).start();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
                String l = r.readLine();
                return l == null ? "" : l.trim();
            }
        } catch (IOException e) {
            return "";
        } finally {
            if (p != null) p.destroy();
        }
    }

    private void reagir(String valor) {
        if ("aviso".equals(valor) || "agora".equals(valor)) {
            if (avisoDesde == 0L) {
                avisoDesde = System.currentTimeMillis();
                maos.removeCallbacks(contagem);
                maos.post(contagem);
            }
        } else if (avisoDesde != 0L) {
            esconderAviso();
        }
    }

    private void mostrarAviso() {
        long resta = (AVISO_MS - (System.currentTimeMillis() - avisoDesde) + 999L) / 1000L;
        if (resta < 0L) resta = 0L;
        aviso.setText(getString(R.string.descanso_aviso, resta));
        aviso.setVisibility(android.view.View.VISIBLE);
    }

    private void esconderAviso() {
        avisoDesde = 0L;
        maos.removeCallbacks(contagem);
        if (aviso != null) aviso.setVisibility(android.view.View.GONE);
    }

    @Override
    public void onDetachedFromWindow() {
        maos.removeCallbacks(tique);
        maos.removeCallbacks(sonda);
        maos.removeCallbacks(contagem);
        super.onDetachedFromWindow();
    }

    private void mover() {
        int folgaX = raiz.getWidth() - conjunto.getWidth();
        int folgaY = raiz.getHeight() - conjunto.getHeight();
        if (folgaX <= 0 || folgaY <= 0) return;
        lugar = (lugar + 1) % LUGARES.length;
        float x = LUGARES[lugar][0] * folgaX / 2f * 0.8f;
        float y = LUGARES[lugar][1] * folgaY / 2f * 0.8f;
        conjunto.animate().translationX(x).translationY(y).setDuration(TRANSICAO_MS)
                .setInterpolator(new AccelerateDecelerateInterpolator()).start();
    }

    private Typeface fonte() {
        try {
            return Typeface.createFromAsset(getAssets(), FONTE);
        } catch (RuntimeException e) {
            return Typeface.create("sans-serif-condensed", Typeface.BOLD);
        }
    }
}
