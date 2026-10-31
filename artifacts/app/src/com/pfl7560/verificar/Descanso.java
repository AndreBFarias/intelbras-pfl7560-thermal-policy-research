package com.pfl7560.verificar;

import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Descanso extends DreamService {
    private static final long MINUTO_MS = 60000L;
    private static final long TRANSICAO_MS = 3000L;
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
    private int lugar;
    private final Runnable tique = new Runnable() {
        @Override
        public void run() {
            hora.setText(formato.format(new Date()));
            mover();
            long agora = System.currentTimeMillis();
            maos.postDelayed(this, MINUTO_MS - agora % MINUTO_MS);
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
        nome.setText(R.string.descanso_nome);
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
        setContentView(raiz);
    }

    @Override
    public void onDreamingStarted() {
        super.onDreamingStarted();
        lugar = 0;
        maos.removeCallbacks(tique);
        hora.setText(formato.format(new Date()));
        maos.postDelayed(tique, MINUTO_MS - System.currentTimeMillis() % MINUTO_MS);
        pedir("descanso-inicio");
    }

    @Override
    public void onDreamingStopped() {
        maos.removeCallbacks(tique);
        pedir("descanso-fim");
        super.onDreamingStopped();
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

    @Override
    public void onDetachedFromWindow() {
        maos.removeCallbacks(tique);
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
