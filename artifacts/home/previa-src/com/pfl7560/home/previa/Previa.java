package com.pfl7560.home.previa;

import com.pfl7560.home.Desenho;
import com.pfl7560.home.Icones;
import com.pfl7560.home.Item;
import com.pfl7560.home.Modelo;
import com.pfl7560.home.Pintor;
import com.pfl7560.home.Tema;

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
 * icones de app sao desenhados no codigo (Icones), os mesmos do aparelho. "MinhaRede" e um nome de
 * exemplo; os apps "(exemplo)" tambem: existem so para encher a fileira e mostrar cada desenho.
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
        firmware.add(Item.app("Alto-falante Bluetooth", "com.zhiying.bluetoothmodelservice", ""));
        firmware.add(Item.app("Gerenciador de arquivos", "com.newlink.filemanager", ""));
        firmware.add(Item.app("iOSCast", "com.newlink.cast", ""));
        firmware.add(Item.app("VideoPlayer", "com.hisilicon.android.videoplayer", ""));

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

        // 2b. o atalho Luz em foco (nome e valor por baixo)
        m.coluna = 4;
        salvar(m, fontes, new File(saida, "home-foco-luz.png"));
        m.coluna = 0;

        // 2c. o painel de luz aberto: atual 100 %, foco em 60 %
        Modelo l = base();
        l.definirApps(firmware);
        l.wifi = "MinhaRede";
        l.temperatura = "59";
        l.abrirLuz();
        l.moverLuz(1);
        l.moverLuz(1);
        salvar(l, fontes, new File(saida, "home-painel-luz.png"));

        // 2d. o painel com a luz em 25 % (Economico atual) e o aviso do pedido
        l.luz = 25;
        l.abrirLuz();
        l.aviso = "Luz 25%: pedido enviado";
        salvar(l, fontes, new File(saida, "home-painel-luz-economico.png"));

        // 3. foco num app, sem rede, sem temperatura legivel, com um aviso
        m.mover(0, 1);
        m.mover(1, 0);
        m.wifi = "Sem rede";
        m.temperatura = null;
        m.aviso = "Não abriu: Bluetooth";
        salvar(m, fontes, new File(saida, "home-foco-app-sem-rede.png"));

        // 4. rolagem da fileira de apps (exemplo com 12 apps) e foco no ultimo visivel + 2
        Modelo r = base();
        List<Item> muitos = completo(firmware);
        r.definirApps(muitos);
        r.wifi = "MinhaRede";
        r.temperatura = "59";
        r.mover(0, 1);
        r.mover(0, 1);
        for (int i = 0; i < muitos.size() - 1; i++) r.mover(1, 0);
        salvar(r, fontes, new File(saida, "home-rolagem-exemplo.png"));

        // 4b. fileira de apps cheia (7 visiveis), foco num app de desenho proprio
        Modelo f = base();
        f.definirApps(muitos);
        f.wifi = "MinhaRede";
        f.temperatura = "59";
        f.mover(0, 1);
        f.mover(0, 1);
        for (int i = 0; i < muitos.size(); i++) f.mover(-1, 0);
        for (int i = 0; i < 4; i++) f.mover(1, 0);
        salvar(f, fontes, new File(saida, "home-apps-cheia.png"));

        // 4c. folha com todos os desenhos de app, em repouso e em foco
        folha(fontes, new File(saida, "home-icones-apps.png"));

        // 5. a lista de apps ainda carregando (o que aparece no primeiro quadro do boot)
        Modelo c = base();
        salvar(c, fontes, new File(saida, "home-carregando.png"));

        checarNavegacao(firmware);
    }

    /** 4 do firmware + um exemplo de cada desenho + monogramas de letras e cores diferentes. */
    private static List<Item> completo(List<Item> firmware) {
        List<Item> l = new ArrayList<Item>(firmware);
        l.add(Item.app("Office (exemplo)", "com.mobisystems.office", ""));
        l.add(Item.app("Galeria (exemplo)", "com.hisilicon.higallery", ""));
        l.add(Item.app("Navegador (exemplo)", "com.android.browser", ""));
        l.add(Item.app("Loja (exemplo)", "com.android.vending", ""));
        l.add(Item.app("Jogo (exemplo)", "com.exemplo.game", ""));
        l.add(Item.app("Música (exemplo)", "com.exemplo.music", ""));
        l.add(Item.app("Alfa (exemplo)", "exemplo.alfa", ""));
        l.add(Item.app("Beta (exemplo)", "exemplo.beta", ""));
        l.add(Item.app("Kilo (exemplo)", "exemplo.kilo", ""));
        l.add(Item.app("Zeta (exemplo)", "exemplo.zeta", ""));
        return l;
    }

    private static final int[] DESENHOS = {
        Icones.ARQUIVOS, Icones.VIDEO, Icones.MUSICA, Icones.ESPELHAR, Icones.DOCUMENTOS, Icones.ALTO_FALANTE,
        Icones.GALERIA, Icones.NAVEGADOR, Icones.LOJA, Icones.JOGO,
    };
    private static final String[] NOMES = {
        "arquivos", "video", "musica", "cast", "documentos", "alto-falante", "galeria", "navegador", "loja", "jogo",
    };

    private static final int[] COR = {Tema.ROXO, Tema.ROSA, Tema.CIANO, Tema.VERDE, Tema.LARANJA};
    private static final String[] NOME_COR = {"roxo", "rosa", "ciano", "verde", "laranja"};

    /** Folha de conferencia (nao e tela do app): cada desenho em repouso e em foco, e os 5 monogramas. */
    private static void folha(File fontes, File png) throws Exception {
        BufferedImage img = new BufferedImage(1920, 1080, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        Pintor p = new PintorJ2D(g, fontes);
        p.gradiente(0, 0, 1920, 1080, Tema.FUNDO, Tema.FUNDO_BASE);
        p.texto("Desenhos da fileira Apps (folha de conferencia)", 112, 100, Pintor.SANS_SEMI, 36, Tema.ROXO, Pintor.ESQ);
        float w = 155, h = 170, vao = 16;
        for (int l = 0; l < 2; l++) {
            boolean foco = l == 1;
            float y = 150 + l * (h + vao);
            for (int i = 0; i < DESENHOS.length; i++) {
                float x = 112 + i * (w + vao);
                p.retangulo(x, y, w, h, 18, foco ? Tema.LINHA : Tema.CARTAO);
                Icones.desenhar(p, DESENHOS[i], x + (w - 88) / 2, y + 22, 88, foco ? Tema.ROSA : Tema.TEXTO_2,
                        foco ? Tema.LINHA : Tema.CARTAO);
                p.texto(NOMES[i], x + w / 2, y + h - 22, Pintor.SANS_SEMI, 24, Tema.TEXTO, Pintor.CENTRO);
            }
        }
        // monogramas: um pacote para cada uma das 5 cores do sorteio estavel
        String[] letras = {"A", "B", "K", "Z", "M"};
        for (int l = 0; l < 2; l++) {
            boolean foco = l == 1;
            float y = 150 + 2 * (h + vao) + 60 + l * (h + vao);
            for (int c = 0; c < 5; c++) {
                String pacote = "exemplo.0";
                for (int n = 0; Icones.corMonograma(pacote) != COR[c]; n++) pacote = "exemplo." + n;
                float x = 112 + c * (w + vao);
                p.retangulo(x, y, w, h, 18, foco ? Tema.LINHA : Tema.CARTAO);
                Icones.monograma(p, letras[c] + "xx", pacote, x + (w - 88) / 2, y + 22, 88, foco);
                p.texto(NOME_COR[c], x + w / 2, y + h - 22, Pintor.SANS_SEMI, 24, Tema.TEXTO, Pintor.CENTRO);
            }
        }
        g.dispose();
        ImageIO.write(img, "png", png);
        System.out.println("previa: " + png);
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
        verdade(m.mover(0, 1) && m.fileira == Modelo.ATALHOS && m.coluna == 6, "de USB-C desce para Espelhamento");
        verdade(m.mover(0, 1) && m.fileira == Modelo.APPS, "desce para os apps");
        verdade(!m.mover(0, 1), "nada abaixo dos apps");
        m.inicio();
        verdade(m.fileira == Modelo.ENTRADAS && m.coluna == 0 && m.primeiroApp == 0, "HOME volta ao comeco");
        Modelo z = base();
        z.luz = 100;
        verdade(!z.luzAberta, "o painel de luz comeca fechado");
        z.abrirLuz();
        verdade(z.luzAberta && z.nivelLuz() == 100, "abre em 100");
        verdade(!z.moverLuz(-1) && z.moverLuz(1) && z.nivelLuz() == 80, "100 -> 80, sem passar do inicio");
        for (int i = 0; i < 6; i++) z.moverLuz(1);
        verdade(z.nivelLuz() == Modelo.LUZ_ECONOMICO && !z.moverLuz(1), "termina em 25 (Economico)");
        z.luz = 70;
        z.abrirLuz();
        verdade(z.nivelLuz() == 60 || z.nivelLuz() == 80, "abre no nivel mais perto do atual");
        z.inicio();
        verdade(!z.luzAberta, "HOME fecha o painel de luz");
        Modelo v = base();
        v.definirApps(new ArrayList<Item>());
        v.mover(0, 1);
        verdade(!v.mover(0, 1) && v.fileira == Modelo.ATALHOS, "sem apps, a fileira vazia nao pega foco");
        System.out.println("navegacao: 15 conferencias ok");
    }

    private static void verdade(boolean b, String o) {
        if (!b) throw new AssertionError("navegacao: " + o);
    }
}
