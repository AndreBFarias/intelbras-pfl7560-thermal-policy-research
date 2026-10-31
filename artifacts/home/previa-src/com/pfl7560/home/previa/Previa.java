package com.pfl7560.home.previa;

import com.pfl7560.home.Acoes;
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

        Modelo m = base();
        m.definirApps(firmware);
        m.wifi = "MinhaRede";
        m.temperatura = "59";
        salvar(m, fontes, new File(saida, "home-foco-entrada.png"));

        m.fileira = Modelo.ATALHOS;
        m.coluna = 0;
        salvar(m, fontes, new File(saida, "home-foco-atalho.png"));

        m.coluna = 4;
        salvar(m, fontes, new File(saida, "home-foco-luz.png"));
        m.coluna = 0;

        Modelo l = base();
        l.definirApps(firmware);
        l.wifi = "MinhaRede";
        l.temperatura = "59";
        l.abrirLuz();
        l.moverLuz(1);
        l.moverLuz(1);
        salvar(l, fontes, new File(saida, "home-painel-luz.png"));

        l.luz = 25;
        l.abrirLuz();
        l.aviso = "Luz 25%: pedido enviado";
        salvar(l, fontes, new File(saida, "home-painel-luz-economico.png"));

        m.mover(0, 1);
        m.mover(1, 0);
        m.wifi = "Sem rede";
        m.temperatura = null;
        m.aviso = "Não abriu: Bluetooth";
        salvar(m, fontes, new File(saida, "home-foco-app-sem-rede.png"));

        Modelo r = base();
        List<Item> muitos = completo(firmware);
        r.definirApps(muitos);
        r.wifi = "MinhaRede";
        r.temperatura = "59";
        r.mover(0, 1);
        r.mover(0, 1);
        for (int i = 0; i < muitos.size() - 1; i++) r.mover(1, 0);
        salvar(r, fontes, new File(saida, "home-rolagem-exemplo.png"));

        Modelo f = base();
        f.definirApps(muitos);
        f.wifi = "MinhaRede";
        f.temperatura = "59";
        f.mover(0, 1);
        f.mover(0, 1);
        for (int i = 0; i < muitos.size(); i++) f.mover(-1, 0);
        for (int i = 0; i < 4; i++) f.mover(1, 0);
        salvar(f, fontes, new File(saida, "home-apps-cheia.png"));

        folha(fontes, new File(saida, "home-icones-apps.png"));

        Modelo c = base();
        salvar(c, fontes, new File(saida, "home-carregando.png"));

        checarNavegacao(firmware);
    }

    private static List<Item> completo(List<Item> firmware) {
        List<Item> l = new ArrayList<Item>(firmware);
        l.add(Item.app("Office (oculto)", "com.mobisystems.editor.office_registered", ""));
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

    private static void checarNavegacao(List<Item> apps) {
        Modelo m = base();
        m.definirApps(apps);
        verdade(m.fileira == Modelo.ENTRADAS && m.coluna == 0, "comeca em HDMI 1");
        verdade(!m.mover(-1, 0) && !m.mover(0, -1), "nada acima nem a esquerda de HDMI 1");
        verdade(m.mover(1, 0) && m.mover(1, 0) && !m.mover(1, 0), "tres entradas");
        verdade(m.mover(0, 1) && m.fileira == Modelo.ATALHOS && m.coluna == 5, "de USB-C desce para Configuracoes");
        verdade(m.atalhos.length == 6 && !m.mover(1, 0), "seis atalhos, Configuracoes e o ultimo");
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
        Modelo o = base();
        List<Item> com = new ArrayList<Item>(apps);
        for (String pk : Modelo.OCULTOS) com.add(Item.app("Oculto " + pk, pk, ""));
        o.definirApps(com);
        verdade(o.apps.size() == m.apps.size() && !m.apps.isEmpty(), "a fileira Apps nao traz Office, iOSCast nem Espelhamento");
        for (Item it : o.apps) verdade(!Modelo.OCULTOS.contains(it.pacote), "oculto na fileira: " + it.pacote);
        Modelo n = Modelo.padrao(false);
        n.definirApps(apps);
        verdade(n.entradas.length == 2, "modelo sem USB-C: so HDMI 1 e HDMI 2");
        for (Item it : n.entradas) verdade(!Acoes.USB_C.equals(it.acao), "modelo sem USB-C com o cartao USB-C");
        verdade(n.mover(1, 0) && !n.mover(1, 0) && n.focado().acao.equals(Acoes.HDMI2), "duas entradas, a ultima e HDMI 2");
        verdade(n.mover(0, 1) && n.fileira == Modelo.ATALHOS, "de HDMI 2 desce para os atalhos");
        while (n.mover(1, 0)) { }
        verdade(n.mover(0, -1) && n.fileira == Modelo.ENTRADAS && n.coluna == 1, "de Configuracoes sobe para HDMI 2");
        Modelo v = base();
        v.definirApps(new ArrayList<Item>());
        v.mover(0, 1);
        verdade(!v.mover(0, 1) && v.fileira == Modelo.ATALHOS, "sem apps, a fileira vazia nao pega foco");
        System.out.println("navegacao: conferencias ok");
    }

    private static void verdade(boolean b, String o) {
        if (!b) throw new AssertionError("navegacao: " + o);
    }
}
