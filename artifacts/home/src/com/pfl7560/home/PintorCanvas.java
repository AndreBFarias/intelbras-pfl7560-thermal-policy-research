package com.pfl7560.home;

import android.content.res.AssetManager;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;

final class PintorCanvas implements Pintor {
    private final Typeface[] fontes = new Typeface[5];
    private final Paint cheio = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint traco = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint letra = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.SUBPIXEL_TEXT_FLAG);
    private final RectF r = new RectF();
    private final Path caminho = new Path();
    private Canvas c;

    PintorCanvas(AssetManager assets) {
        String[] nomes = {
            "IBMPlexSansCondensed-Regular.ttf", "IBMPlexSansCondensed-SemiBold.ttf",
            "IBMPlexSansCondensed-Bold.ttf", "IBMPlexMono-Regular.ttf", "IBMPlexMono-SemiBold.ttf",
        };
        for (int i = 0; i < nomes.length; i++) {
            Typeface t;
            try {
                t = Typeface.createFromAsset(assets, "fontes/" + nomes[i]);
            } catch (RuntimeException e) {
                t = i >= 3 ? Typeface.MONOSPACE : Typeface.SANS_SERIF;
            }
            fontes[i] = t;
        }
        cheio.setStyle(Paint.Style.FILL);
        traco.setStyle(Paint.Style.STROKE);
        traco.setStrokeCap(Paint.Cap.ROUND);
        traco.setStrokeJoin(Paint.Join.ROUND);
    }

    void usar(Canvas canvas) {
        c = canvas;
    }

    private Paint traco(float esp, int cor) {
        traco.setStrokeWidth(esp);
        traco.setColor(cor);
        return traco;
    }

    private Paint cheio(int cor) {
        cheio.setShader(null);
        cheio.setColor(cor);
        return cheio;
    }

    @Override
    public void gradiente(float x, float y, float w, float h, int corTopo, int corBase) {
        cheio.setShader(new LinearGradient(x, y, x, y + h, corTopo, corBase, Shader.TileMode.CLAMP));
        c.drawRect(x, y, x + w, y + h, cheio);
        cheio.setShader(null);
    }

    @Override
    public void retangulo(float x, float y, float w, float h, float raio, int cor) {
        r.set(x, y, x + w, y + h);
        c.drawRoundRect(r, raio, raio, cheio(cor));
    }

    @Override
    public void contorno(float x, float y, float w, float h, float raio, float esp, int cor) {
        r.set(x, y, x + w, y + h);
        c.drawRoundRect(r, raio, raio, traco(esp, cor));
    }

    @Override
    public void linha(float x1, float y1, float x2, float y2, float esp, int cor) {
        c.drawLine(x1, y1, x2, y2, traco(esp, cor));
    }

    @Override
    public void circulo(float cx, float cy, float raio, int cor) {
        c.drawCircle(cx, cy, raio, cheio(cor));
    }

    @Override
    public void anel(float cx, float cy, float raio, float esp, int cor) {
        c.drawCircle(cx, cy, raio, traco(esp, cor));
    }

    @Override
    public void arco(float cx, float cy, float raio, float inicio, float varredura, float esp, int cor) {
        r.set(cx - raio, cy - raio, cx + raio, cy + raio);
        c.drawArc(r, inicio, varredura, false, traco(esp, cor));
    }

    @Override
    public void polilinha(float[] xy, boolean fechada, float esp, int cor) {
        caminho.reset();
        caminho.moveTo(xy[0], xy[1]);
        for (int i = 2; i < xy.length; i += 2) caminho.lineTo(xy[i], xy[i + 1]);
        if (fechada) caminho.close();
        c.drawPath(caminho, traco(esp, cor));
    }

    private Paint letra(int fonte, float tam) {
        letra.setTypeface(fontes[fonte]);
        letra.setTextSize(tam);
        return letra;
    }

    @Override
    public void texto(String s, float x, float yBase, int fonte, float tam, int cor, int alin) {
        Paint p = letra(fonte, tam);
        p.setColor(cor);
        p.setTextAlign(alin == CENTRO ? Paint.Align.CENTER : alin == DIR ? Paint.Align.RIGHT : Paint.Align.LEFT);
        c.drawText(s, x, yBase, p);
    }

    @Override
    public float largura(String s, int fonte, float tam) {
        return letra(fonte, tam).measureText(s);
    }
}
