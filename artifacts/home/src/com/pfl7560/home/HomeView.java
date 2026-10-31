package com.pfl7560.home;

import android.content.Context;
import android.graphics.Canvas;
import android.view.KeyEvent;
import android.view.View;

final class HomeView extends View {
    interface Ouvinte {
        void abrir(Item item);

        void aplicarLuz(int nivel);
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
            Guarda.anotar(getContext(), "desenho", e);
        } finally {
            canvas.restoreToCount(salvo);
        }
    }

    @Override
    public boolean onKeyDown(int codigo, KeyEvent ev) {
        if (modelo.luzAberta) return teclaLuz(codigo, ev);
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

    private boolean teclaLuz(int codigo, KeyEvent ev) {
        switch (codigo) {
            case KeyEvent.KEYCODE_DPAD_LEFT:
                if (modelo.moverLuz(-1)) invalidate();
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                if (modelo.moverLuz(1)) invalidate();
                return true;
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_DPAD_DOWN:
                return true;
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_NUMPAD_ENTER:
                if (ev.getRepeatCount() == 0) ouvinte.aplicarLuz(modelo.nivelLuz());
                return true;
            default:
                return super.onKeyDown(codigo, ev);
        }
    }
}
