package com.pfl7560.home;

import android.content.Context;
import android.graphics.Canvas;
import android.view.KeyEvent;
import android.view.View;

/**
 * A home inteira numa View so, desenhada pelo Desenho (o mesmo das previas) num quadro de
 * 1920x1080 escalado para a tela. Foco proprio, so D-pad: nada depende de toque.
 */
final class HomeView extends View {
    interface Ouvinte {
        void abrir(Item item);
    }

    private final Modelo modelo;
    private final PintorCanvas pintor;
    private final Ouvinte ouvinte;

    HomeView(Context ctx, Modelo modelo, Ouvinte ouvinte) {
        super(ctx);
        this.modelo = modelo;
        this.ouvinte = ouvinte;
        this.pintor = new PintorCanvas(ctx.getAssets());
        setFocusable(true);
        setFocusableInTouchMode(true);
        setBackgroundColor(Tema.FUNDO);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float s = Math.min(getWidth() / Desenho.LARGURA, getHeight() / Desenho.ALTURA);
        if (s <= 0) return;
        int salvo = canvas.save();
        try {
            canvas.translate((getWidth() - Desenho.LARGURA * s) / 2, (getHeight() - Desenho.ALTURA * s) / 2);
            canvas.scale(s, s);
            pintor.usar(canvas);
            Desenho.desenhar(pintor, modelo);
        } catch (RuntimeException e) {
            // um desenho que falha nao derruba a home: fica o fundo, e o proximo quadro tenta de novo
            Guarda.anotar(getContext(), "desenho", e);
        } finally {
            canvas.restoreToCount(salvo);
        }
    }

    @Override
    public boolean onKeyDown(int codigo, KeyEvent ev) {
        boolean mudou;
        switch (codigo) {
            case KeyEvent.KEYCODE_DPAD_LEFT:
                mudou = modelo.mover(-1, 0);
                break;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                mudou = modelo.mover(1, 0);
                break;
            case KeyEvent.KEYCODE_DPAD_UP:
                mudou = modelo.mover(0, -1);
                break;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                mudou = modelo.mover(0, 1);
                break;
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_NUMPAD_ENTER:
                if (ev.getRepeatCount() == 0) {
                    Item i = modelo.focado();
                    if (i != null) ouvinte.abrir(i);
                }
                return true;
            default:
                return super.onKeyDown(codigo, ev);
        }
        if (mudou) {
            modelo.aviso = null;
            invalidate();
        }
        return true;
    }
}
