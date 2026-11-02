package com.pfl7560.verificar;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.WindowManager;
import android.widget.ImageView;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Visor das telas da suite (bloco 29). Fica aberto a suite inteira sobre o fundo MeowCast (o tema
 * TemaVisor tem o logo da abertura como fundo da janela) e troca a imagem dentro de si: a home
 * nao aparece entre as telas. Voltar/Sair grava o pedido de cancelar e fecha. As regras ficam no
 * VisorModelo (Java puro, testado no PC).
 */
public class Visor extends Activity {
    private static final long FADE_MS = 180L;

    private final Handler maos = new Handler(Looper.getMainLooper());
    private final ExecutorService fila = Executors.newSingleThreadExecutor();
    private ImageView imagem;
    private int geracao;
    private boolean cancelou;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        imagem = new ImageView(this);
        imagem.setScaleType(ImageView.ScaleType.FIT_CENTER);
        imagem.setAlpha(0f);
        setContentView(imagem);
        tratar(getIntent());
    }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        setIntent(i);
        tratar(i);
    }

    private void tratar(Intent i) {
        if (i == null) return;
        String tela = i.getStringExtra(VisorModelo.EXTRA_TELA);
        switch (VisorModelo.acao(tela, i.getBooleanExtra(VisorModelo.EXTRA_FECHAR, false))) {
            case FECHAR:
                finish();
                break;
            case MOSTRAR:
                carregar(tela);
                break;
            default:
                break;
        }
    }

    private void carregar(String tela) {
        final int g = ++geracao;
        final File f = VisorModelo.arquivoDaTela(getDataDir(), tela);
        if (f == null) return;
        fila.execute(new Runnable() {
            @Override
            public void run() {
                final Bitmap bm = BitmapFactory.decodeFile(f.getPath());
                maos.post(new Runnable() {
                    @Override
                    public void run() {
                        trocar(g, bm);
                    }
                });
            }
        });
    }

    /** Some a imagem velha (aparece o fundo MeowCast), poe a nova e acende. */
    private void trocar(final int g, final Bitmap bm) {
        if (g != geracao || isFinishing() || isDestroyed()) return;
        imagem.animate().cancel();
        if (imagem.getDrawable() == null || imagem.getAlpha() == 0f) {
            imagem.setImageBitmap(bm);
            imagem.animate().alpha(bm == null ? 0f : 1f).setDuration(FADE_MS);
            return;
        }
        imagem.animate().alpha(0f).setDuration(FADE_MS).withEndAction(new Runnable() {
            @Override
            public void run() {
                if (g != geracao || isFinishing() || isDestroyed()) return;
                imagem.setImageBitmap(bm);
                if (bm != null) imagem.animate().alpha(1f).setDuration(FADE_MS);
            }
        });
    }

    @Override
    public boolean onKeyDown(int tecla, KeyEvent e) {
        if (VisorModelo.cancela(tecla)) {
            if (e.getRepeatCount() == 0) cancelar();
            return true;
        }
        return super.onKeyDown(tecla, e);
    }

    @Override
    public void onBackPressed() {
        cancelar();
    }

    /** Grava ANTES de fechar (sincrono, com fsync): a suite le o pedido no proximo segundo. */
    private void cancelar() {
        if (!cancelou) {
            cancelou = true;
            VisorModelo.gravarCancelar(getDataDir());
        }
        finish();
    }

    @Override
    protected void onDestroy() {
        fila.shutdownNow();
        super.onDestroy();
    }
}
