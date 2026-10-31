package com.pfl7560.home.previa;

import com.pfl7560.home.Desenho;
import com.pfl7560.home.Item;
import com.pfl7560.home.Modelo;

import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.TimeZone;

import javax.imageio.ImageIO;

/**
 * Gera as previas 1920x1080 da home no PC com o MESMO codigo de desenho do app (Desenho, Icones,
 * Modelo, Tema). Uso: java -cp <classes> com.pfl7560.home.previa.Previa <dir fontes> <dir saida>
 *
 * Dados: a hora e a data sao fixas; os apps sao os que o firmware V1.0.0.9 lista com MAIN+LAUNCHER
 * (aapt2 dump badging, rotulo em pt quando existe), menos os da lista de exclusao (doc 45). Os
 * icones de app viram monograma (o PC nao tem os Drawables). "MinhaRede" e um nome de exemplo.
 * 59 °C e a media medida do sensor do LED em regime (doc 40). A previa de rolagem usa "Exemplo N",
 * marcado como exemplo, so para provar o contador e que nada sai cortado.
 */
public final class Previa {
    private Previa() {
    }

    public static void main(String[] a) throws Exception {
        File fontes = new File(a[0]);
        File saida = new File(a[1]);
        if (!saida.isDirectory() && !saida.mkdirs()) throw new IllegalStateException("sem pasta " + saida);

        List<Item> firmware = new ArrayList<Item>();
        firmware.add(Item.app("Alto-falante Bluetooth", "com.zhiying.bluetoothmodelservice", "", null));
        firmware.add(Item.app("Gerenciador de arquivos", "com.newlink.filemanager", "", null));
        firmware.add(Item.app("iOSCast", "com.newlink.cast", "", null));
        firmware.add(Item.app("VideoPlayer", "com.hisilicon.android.videoplayer", "", null));

        // 1. foco no comeco (HDMI 1), com rede e temperatura
        Modelo m = base();
        m.definirApps(firmware);
        m.wifi = "MinhaRede";
        m.temperatura = "59";
        salvar(m, fontes, new File(saida, "home-foco-entrada.png"));

        // 2. foco em um atalho de rotulo longo (duas linhas)
        m.fileira = Modelo.ATALHOS;
        m.coluna = 0;
        salvar(m, fontes, new File(saida, "home-foco-atalho.png"));

        // 3. foco num app, sem rede, sem temperatura legivel, com um aviso
        m.mover(0, 1);
        m.mover(1, 0);
        m.wifi = "Sem rede";
        m.temperatura = null;
        m.aviso = "Não abriu: Bluetooth";
        salvar(m, fontes, new File(saida, "home-foco-app-sem-rede.png"));

        // 4. rolagem da fileira de apps (exemplo com 12 apps) e foco no ultimo visivel + 2
        Modelo r = base();
        List<Item> muitos = new ArrayList<Item>(firmware);
        for (int i = 1; i <= 8; i++) muitos.add(Item.app("Exemplo " + i, "exemplo." + i, "", null));
        r.definirApps(muitos);
        r.wifi = "MinhaRede";
        r.temperatura = "59";
        r.mover(0, 1);
        r.mover(0, 1);
        for (int i = 0; i < 8; i++) r.mover(1, 0);
        salvar(r, fontes, new File(saida, "home-rolagem-exemplo.png"));

        // 5. a lista de apps ainda carregando (o que aparece no primeiro quadro do boot)
        Modelo c = base();
        salvar(c, fontes, new File(saida, "home-carregando.png"));

        checarNavegacao(firmware);
    }

    private static Modelo base() {
        Modelo m = Modelo.padrao();
        Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("America/Sao_Paulo"));
        cal.clear();
        cal.set(2026, Calendar.OCTOBER, 31, 21, 47, 0);
        m.relogio(cal);
        return m;
    }

    private static void salvar(Modelo m, File fontes, File png) throws Exception {
        BufferedImage img = new BufferedImage(1920, 1080, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        Desenho.desenhar(new PintorJ2D(g, fontes), m);
        g.dispose();
        ImageIO.write(img, "png", png);
        System.out.println("previa: " + png);
    }

    /** Confere a navegacao do D-pad (o mesmo Modelo do aparelho). Falha = excecao. */
    private static void checarNavegacao(List<Item> apps) {
        Modelo m = base();
        m.definirApps(apps);
        verdade(m.fileira == Modelo.ENTRADAS && m.coluna == 0, "comeca em HDMI 1");
        verdade(!m.mover(-1, 0) && !m.mover(0, -1), "nada acima nem a esquerda de HDMI 1");
        verdade(m.mover(1, 0) && m.mover(1, 0) && !m.mover(1, 0), "tres entradas");
        verdade(m.mover(0, 1) && m.fileira == Modelo.ATALHOS && m.coluna == 5, "de USB-C desce para Espelhamento");
        verdade(m.mover(0, 1) && m.fileira == Modelo.APPS, "desce para os apps");
        verdade(!m.mover(0, 1), "nada abaixo dos apps");
        m.inicio();
        verdade(m.fileira == Modelo.ENTRADAS && m.coluna == 0 && m.primeiroApp == 0, "HOME volta ao comeco");
        Modelo v = base();
        v.definirApps(new ArrayList<Item>());
        v.mover(0, 1);
        verdade(!v.mover(0, 1) && v.fileira == Modelo.ATALHOS, "sem apps, a fileira vazia nao pega foco");
        System.out.println("navegacao: 9 conferencias ok");
    }

    private static void verdade(boolean b, String o) {
        if (!b) throw new AssertionError("navegacao: " + o);
    }
}
