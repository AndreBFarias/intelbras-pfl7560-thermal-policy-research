package com.pfl7560.home.previa;

import com.pfl7560.home.Pintor;

import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Font;
import java.awt.GradientPaint;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.font.FontRenderContext;
import java.awt.geom.Arc2D;
import java.awt.geom.Ellipse2D;
import java.awt.geom.Line2D;
import java.awt.geom.Path2D;
import java.awt.geom.Rectangle2D;
import java.awt.geom.RoundRectangle2D;
import java.io.File;

final class PintorJ2D implements Pintor {
    private final Graphics2D g;
    private final Font[] fontes = new Font[5];

    PintorJ2D(Graphics2D g, File dirFontes) throws Exception {
        this.g = g;
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_ON);
        g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        String[] nomes = {
            "IBMPlexSansCondensed-Regular.ttf", "IBMPlexSansCondensed-SemiBold.ttf",
            "IBMPlexSansCondensed-Bold.ttf", "IBMPlexMono-Regular.ttf", "IBMPlexMono-SemiBold.ttf",
        };
        for (int i = 0; i < nomes.length; i++) {
            fontes[i] = Font.createFont(Font.TRUETYPE_FONT, new File(dirFontes, nomes[i]));
        }
    }

    private static Color c(int argb) {
        return new Color(argb, true);
    }

    private BasicStroke traco(float esp) {
        return new BasicStroke(esp, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND);
    }

    @Override
    public void gradiente(float x, float y, float w, float h, int corTopo, int corBase) {
        g.setPaint(new GradientPaint(x, y, c(corTopo), x, y + h, c(corBase)));
        g.fill(new Rectangle2D.Float(x, y, w, h));
    }

    @Override
    public void retangulo(float x, float y, float w, float h, float raio, int cor) {
        g.setPaint(c(cor));
        g.fill(new RoundRectangle2D.Float(x, y, w, h, raio * 2, raio * 2));
    }

    @Override
    public void contorno(float x, float y, float w, float h, float raio, float esp, int cor) {
        g.setPaint(c(cor));
        g.setStroke(traco(esp));
        g.draw(new RoundRectangle2D.Float(x, y, w, h, raio * 2, raio * 2));
    }

    @Override
    public void linha(float x1, float y1, float x2, float y2, float esp, int cor) {
        g.setPaint(c(cor));
        g.setStroke(traco(esp));
        g.draw(new Line2D.Float(x1, y1, x2, y2));
    }

    @Override
    public void circulo(float cx, float cy, float r, int cor) {
        g.setPaint(c(cor));
        g.fill(new Ellipse2D.Float(cx - r, cy - r, 2 * r, 2 * r));
    }

    @Override
    public void anel(float cx, float cy, float r, float esp, int cor) {
        g.setPaint(c(cor));
        g.setStroke(traco(esp));
        g.draw(new Ellipse2D.Float(cx - r, cy - r, 2 * r, 2 * r));
    }

    @Override
    public void arco(float cx, float cy, float r, float inicio, float varredura, float esp, int cor) {
        g.setPaint(c(cor));
        g.setStroke(traco(esp));
        g.draw(new Arc2D.Float(cx - r, cy - r, 2 * r, 2 * r, -inicio, -varredura, Arc2D.OPEN));
    }

    @Override
    public void polilinha(float[] xy, boolean fechada, float esp, int cor) {
        Path2D.Float p = new Path2D.Float();
        p.moveTo(xy[0], xy[1]);
        for (int i = 2; i < xy.length; i += 2) p.lineTo(xy[i], xy[i + 1]);
        if (fechada) p.closePath();
        g.setPaint(c(cor));
        g.setStroke(traco(esp));
        g.draw(p);
    }

    private Font fonte(int f, float tam) {
        return fontes[f].deriveFont(tam);
    }

    @Override
    public void texto(String s, float x, float yBase, int fonte, float tam, int cor, int alin) {
        Font f = fonte(fonte, tam);
        float w = largura(s, fonte, tam);
        if (alin == CENTRO) x -= w / 2;
        else if (alin == DIR) x -= w;
        g.setFont(f);
        g.setPaint(c(cor));
        g.drawString(s, x, yBase);
    }

    @Override
    public float largura(String s, int fonte, float tam) {
        FontRenderContext frc = new FontRenderContext(null, true, true);
        return (float) fonte(fonte, tam).getStringBounds(s, frc).getWidth();
    }
}
