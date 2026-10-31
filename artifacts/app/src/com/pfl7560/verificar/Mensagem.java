package com.pfl7560.verificar;

import android.app.Activity;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Tela de mensagem de 3 s no estilo das telas da suite (fundo escuro, traco claro). */
final class Mensagem {
    private static final long MS = 3000;

    private Mensagem() {}

    static void mostrar(final Activity a, int titulo, int texto, int corTitulo) {
        LinearLayout caixa = new LinearLayout(a);
        caixa.setOrientation(LinearLayout.VERTICAL);
        caixa.setGravity(Gravity.CENTER);
        caixa.setBackgroundColor(a.getColor(R.color.fundo));
        int m = (int) (48 * a.getResources().getDisplayMetrics().density);
        caixa.setPadding(m, m, m, m);

        TextView t = new TextView(a);
        t.setText(titulo);
        t.setTextColor(a.getColor(corTitulo));
        t.setTextSize(36);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setGravity(Gravity.CENTER);
        caixa.addView(t);

        TextView s = new TextView(a);
        s.setText(texto);
        s.setTextColor(a.getColor(R.color.secundario));
        s.setTextSize(22);
        s.setGravity(Gravity.CENTER);
        s.setPadding(0, m / 2, 0, 0);
        caixa.addView(s);

        a.setContentView(caixa);
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                a.finish();
            }
        }, MS);
    }
}
