package com.pfl7560.home.previa;

import com.pfl7560.home.Acoes;
import com.pfl7560.home.Curvas;
import com.pfl7560.home.Desenho;
import com.pfl7560.home.Entradas;
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
        m.bluetooth = "Bluetooth ligado";
        m.temperatura = "59";
        m.temperaturaPlaca = "47";
        salvar(m, fontes, new File(saida, "home-foco-entrada.png"));

        m.fileira = Modelo.ATALHOS;
        m.coluna = 0;
        salvar(m, fontes, new File(saida, "home-foco-atalho.png"));

        m.coluna = 3;
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

        // a tela inicial do bloco 27: duas entradas, seis atalhos, Bluetooth e placa no rodape
        Modelo t = base();
        t.definirApps(firmware);
        t.wifi = "MinhaRede";
        t.bluetooth = "Bluetooth conectado";
        t.temperatura = "61";
        t.temperaturaPlaca = "48";
        t.mover(1, 0);
        salvar(t, fontes, new File(saida, "home-tela-inicial.png"));

        previasCurvas(fontes, saida, firmware);
        previasCabos(fontes, saida, firmware);

        checarNavegacao(firmware);
        checarEntradas();
    }

    /**
     * Bloco 30: os HDMI so com cabo, o USB-C sempre (decisao do dono). Sem cabo HDMI, so o USB-C; com cabo no HDMI 2,
     * HDMI 2 e USB-C; com os dois cabos, HDMI 1, HDMI 2 e USB-C.
     */
    private static void previasCabos(File fontes, File saida, List<Item> firmware) throws Exception {
        Modelo s = semCabo();
        s.definirApps(firmware);
        s.wifi = "MinhaRede";
        s.bluetooth = "Bluetooth ligado";
        s.temperatura = "59";
        s.temperaturaPlaca = "47";
        s.definirEntradas(Entradas.lista(false, false, true));
        salvar(s, fontes, new File(saida, "home-sem-cabo.png"));

        Modelo u = semCabo();
        u.definirApps(firmware);
        u.wifi = "MinhaRede";
        u.bluetooth = "Bluetooth ligado";
        u.temperatura = "59";
        u.temperaturaPlaca = "47";
        u.definirEntradas(Entradas.lista(false, true, true));
        salvar(u, fontes, new File(saida, "home-cabo-hdmi2.png"));

        Modelo t = semCabo();
        t.definirApps(firmware);
        t.wifi = "MinhaRede";
        t.bluetooth = "Bluetooth ligado";
        t.temperatura = "59";
        t.temperaturaPlaca = "47";
        t.definirEntradas(Entradas.lista(true, true, true));
        t.mover(1, 0);
        t.mover(1, 0);
        salvar(t, fontes, new File(saida, "home-cabos-todos.png"));
    }

    private static Modelo semCabo() {
        Modelo m = Modelo.padrao();
        Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("America/Sao_Paulo"));
        cal.clear();
        cal.set(2026, Calendar.NOVEMBER, 2, 21, 47, 0);
        m.relogio(cal);
        return m;
    }

    private static Item[] ent(boolean h1, boolean h2, boolean uc) {
        return Entradas.lista(h1, h2, uc);
    }

    private static void checarEntradas() {
        // o sinal: id da entrada de TV do hardware -> porta; fonte -> porta
        verdade(Entradas.portaDoId("com.hisilicon.tvinput.external/.HiHdmiTvInputService/HDMI0000C3") == 3, "id C3 = porta 3");
        verdade(Entradas.portaDoId("com.hisilicon.tvinput.external/.HiHdmiTvInputService/HDMI0000C1") == 1, "id C1 = porta 1");
        verdade(Entradas.portaDoId("com.hisilicon.tvinput.external/.HiHdmiTvInputService/HDMI300004") == -1, "aparelho CEC nao e porta");
        verdade(Entradas.portaDoId("com.hisilicon.tvinput.external/.HiCvbsTvInputService/HW0") == -1, "AV nao e porta");
        verdade(Entradas.portaDoId("x/HDMI0000C0") == -1 && Entradas.portaDoId("x/HDMI0000ZZ") == -1
                && Entradas.portaDoId(null) == -1 && Entradas.portaDoId("x/HDMI0000C12") == -1, "ids tortos");
        verdade(Entradas.porta("11", 11) == 3 && Entradas.porta("10", 10) == 2 && Entradas.porta("9", 9) == 1,
                "fonte - 8: 11 -> 3, 10 -> 2, 9 -> 1");
        verdade(Entradas.porta("", 10) == 2 && Entradas.porta("lixo", 11) == 3 && Entradas.porta("5", 11) == -1,
                "fonte vazia ou lixo usa o padrao; fonte <= 8 nao e porta");
        verdade(Entradas.temUsbC("1", "9") && Entradas.temUsbC("", "9") && !Entradas.temUsbC("", "")
                && !Entradas.temUsbC("0", ""), "USB-C so no firmware que tem");

        // estado por porta -> botoes (0 = cabo; 1 = sem cabo; sem entrada de TV = desconhecido, fica visivel).
        // O USB-C fica sempre (decisao do dono, doc 45 §14.4): o estado da porta 1 nao conta.
        int[] e = Entradas.estadosVazios();
        e[1] = 1;
        e[2] = 1;
        e[3] = 1;
        Item[] semHdmi = Entradas.comCabo(3, 2, true, e);
        verdade(semHdmi.length == 1 && semHdmi[0].acao.equals(Acoes.USBC), "sem cabo HDMI: so o USB-C");
        verdade(Entradas.comCabo(3, 2, false, e).length == 0, "sem cabo HDMI e firmware sem USB-C: nenhum botao");
        e[3] = 0;
        Item[] so1 = Entradas.comCabo(3, 2, true, e);
        verdade(so1.length == 2 && so1[0].acao.equals(Acoes.HDMI1) && so1[1].acao.equals(Acoes.USBC),
                "cabo no HDMI 1 (porta 3): HDMI 1 e USB-C");
        e[3] = 1;
        e[2] = 0;
        Item[] so2 = Entradas.comCabo(3, 2, true, e);
        verdade(so2.length == 2 && so2[0].acao.equals(Acoes.HDMI2) && so2[1].acao.equals(Acoes.USBC),
                "cabo no HDMI 2 (porta 2): HDMI 2 e USB-C");
        e[2] = 1;
        e[1] = 0;
        Item[] c1 = Entradas.comCabo(3, 2, true, e);
        verdade(c1.length == 1 && c1[0].acao.equals(Acoes.USBC), "C1 = 0 (como no aparelho, sempre): nada muda");
        verdade(Entradas.comCabo(3, 2, false, e).length == 0, "firmware sem USB-C: a porta 1 nao vira botao");
        e[1] = 1;
        verdade(Entradas.comCabo(3, 2, true, e).length == 1, "C1 = 1: o USB-C continua");
        e[2] = 0;
        e[3] = 0;
        Item[] tres = Entradas.comCabo(3, 2, true, e);
        verdade(tres.length == 3 && tres[0].acao.equals(Acoes.HDMI1) && tres[1].acao.equals(Acoes.HDMI2)
                && tres[2].acao.equals(Acoes.USBC), "os tres, na ordem HDMI 1, HDMI 2, USB-C");
        e[2] = Entradas.DESCONHECIDO;
        e[3] = 1;
        Item[] desc = Entradas.comCabo(3, 2, false, e);
        verdade(desc.length == 1 && desc[0].acao.equals(Acoes.HDMI2), "porta sem entrada de TV fica visivel");
        verdade(Entradas.semLeitura(false).length == 2 && Entradas.semLeitura(true).length == 3, "sem leitura: todas");

        // o aparelho como ele e: USB-C sempre, HDMI liga e desliga
        Modelo r = semCabo();
        verdade(r.definirEntradas(ent(false, false, true)) && r.fileira == Modelo.ENTRADAS
                && r.focado().acao.equals(Acoes.USBC), "abre sem cabo HDMI: foco no USB-C, o comeco da fileira");
        verdade(r.definirEntradas(ent(true, false, true)) && r.focado().acao.equals(Acoes.USBC),
                "HDMI 1 ligado: aparece a esquerda e o foco segue no USB-C");
        verdade(r.mover(-1, 0) && r.focado().acao.equals(Acoes.HDMI1), "seta para a esquerda: HDMI 1");
        verdade(r.definirEntradas(ent(false, false, true)) && r.fileira == Modelo.ENTRADAS
                && r.focado().acao.equals(Acoes.USBC), "HDMI 1 tirado com o foco nele: foco no USB-C, que pega o lugar");
        verdade(r.definirEntradas(ent(false, true, true)) && r.focado().acao.equals(Acoes.USBC),
                "HDMI 2 ligado: o foco nao e roubado");
        verdade(r.mover(-1, 0) && r.focado().acao.equals(Acoes.HDMI2), "seta para a esquerda: HDMI 2");
        verdade(r.definirEntradas(ent(false, false, true)) && r.focado().acao.equals(Acoes.USBC),
                "HDMI 2 tirado com o foco nele: foco no USB-C");
        r.inicio();
        verdade(r.fileira == Modelo.ENTRADAS && r.focado().acao.equals(Acoes.USBC), "HOME sem cabo HDMI: USB-C");

        // foco: abre sem entradas no primeiro atalho; a primeira leitura leva ao comeco
        Modelo m = semCabo();
        verdade(m.entradas.length == 0 && m.fileira == Modelo.ATALHOS && m.coluna == 0
                && m.focado().acao.equals(Acoes.VERIFICAR), "antes da leitura: foco em Verificar projetor");
        verdade(!m.mover(0, -1) && m.fileira == Modelo.ATALHOS, "sem entradas, nada acima dos atalhos");
        m.inicio();
        verdade(m.definirEntradas(ent(true, false, false)) && m.fileira == Modelo.ENTRADAS && m.coluna == 0,
                "primeira leitura com cabo, sem mexer: foco em HDMI 1");
        verdade(!m.definirEntradas(ent(true, false, false)), "mesma lista: nada a redesenhar");

        Modelo n = semCabo();
        verdade(!n.definirEntradas(ent(false, false, false)) && n.fileira == Modelo.ATALHOS && n.coluna == 0,
                "primeira leitura sem cabo: segue em Verificar projetor");
        verdade(n.definirEntradas(ent(true, false, false)) && n.fileira == Modelo.ATALHOS && n.coluna == 0,
                "cabo ligado depois: o foco nao e roubado");
        n.inicio();
        verdade(n.fileira == Modelo.ENTRADAS && n.coluna == 0, "HOME com cabo: HDMI 1");

        // o dono mexeu antes da primeira leitura: o foco fica onde ele pos
        Modelo t = semCabo();
        t.mover(1, 0);
        t.mover(1, 0);
        verdade(t.definirEntradas(ent(true, true, false)) && t.fileira == Modelo.ATALHOS && t.coluna == 2,
                "primeira leitura depois de mexer: o foco fica em Bluetooth");

        // o botao em foco continua: o foco vai com ele
        Modelo a = semCabo();
        a.definirEntradas(ent(false, true, false));
        verdade(a.focado().acao.equals(Acoes.HDMI2), "so HDMI 2: foco nele");
        verdade(a.definirEntradas(ent(true, true, false)) && a.focado().acao.equals(Acoes.HDMI2) && a.coluna == 1,
                "HDMI 1 aparece a esquerda: o foco segue em HDMI 2");
        verdade(a.definirEntradas(ent(true, true, true)) && a.focado().acao.equals(Acoes.HDMI2),
                "USB-C aparece: o foco segue em HDMI 2");

        // o botao em foco some: o vizinho que ocupa o lugar
        verdade(a.definirEntradas(ent(true, false, true)) && a.fileira == Modelo.ENTRADAS
                && a.focado().acao.equals(Acoes.USBC), "HDMI 2 some do meio: foco no USB-C, que pega o lugar");
        verdade(a.definirEntradas(ent(true, false, false)) && a.focado().acao.equals(Acoes.HDMI1),
                "USB-C some do fim: foco no HDMI 1");
        // a ultima entrada some: desce para o atalho logo abaixo, como a seta
        Modelo b = semCabo();
        b.definirEntradas(ent(true, false, false));
        float cx = Desenho.centroX(b, Modelo.ENTRADAS, 0);
        Modelo ref = semCabo();
        ref.definirEntradas(ent(true, false, false));
        ref.mover(0, 1);
        verdade(b.definirEntradas(ent(false, false, false)) && b.fileira == Modelo.ATALHOS && b.focado() != null
                && b.coluna == ref.coluna, "a unica entrada some: foco no atalho de baixo (" + cx + ")");
        verdade(b.focado().acao.equals(Acoes.CONFIG), "HDMI 1 sozinho fica sobre Configuracoes");
        verdade(!b.mover(0, -1) && b.fileira == Modelo.ATALHOS, "sem entradas, cima nao leva a lugar nenhum");

        // foco fora da fileira: cabo nao mexe nele
        Modelo c = semCabo();
        c.definirEntradas(ent(true, true, false));
        c.mover(0, 1);
        c.mover(-1, 0);
        int col = c.coluna;
        c.definirEntradas(ent(false, false, false));
        verdade(c.fileira == Modelo.ATALHOS && c.coluna == col, "foco nos atalhos: tirar o cabo nao mexe no foco");
        c.definirEntradas(ent(true, true, true));
        verdade(c.fileira == Modelo.ATALHOS && c.coluna == col, "foco nos atalhos: ligar o cabo nao mexe no foco");
        verdade(c.mover(0, -1) && c.fileira == Modelo.ENTRADAS && c.focado() != null, "e a seta para cima chega nelas");

        // painel aberto: a fileira muda por baixo sem perder o foco
        Modelo d = semCabo();
        d.definirEntradas(ent(true, false, false));
        d.abrirLuz();
        d.definirEntradas(ent(false, false, false));
        verdade(d.luzAberta && d.fileira == Modelo.ATALHOS && d.focado() != null, "com o painel de luz aberto");
        d.voltar();
        verdade(!d.luzAberta && d.focado() != null, "fecha e o foco esta num atalho");

        // HOME sem cabo: primeiro atalho
        d.inicio();
        verdade(d.fileira == Modelo.ATALHOS && d.coluna == 0, "HOME sem cabo: Verificar projetor");

        // nunca um foco que aponta para fora da fileira
        Modelo z = semCabo();
        boolean[][] seq = {{true, true, true}, {false, false, true}, {true, false, false}, {false, false, false},
            {false, true, true}, {true, true, false}, {false, false, false}};
        for (int i = 0; i < 3; i++) z.mover(1, 0);
        for (boolean[] s : seq) {
            z.definirEntradas(ent(s[0], s[1], s[2]));
            verdade(z.focado() != null, "foco valido depois de " + s[0] + s[1] + s[2]);
            z.mover(0, -1);
            verdade(z.focado() != null, "foco valido depois de subir");
        }
        System.out.println("entradas: conferencias ok");
    }

    private static Modelo painelCurvas(List<Item> firmware) {
        Modelo m = base();
        m.definirApps(firmware);
        m.wifi = "MinhaRede";
        m.temperatura = "54";
        m.abrirCurvas();
        return m;
    }

    private static void previasCurvas(File fontes, File saida, List<Item> firmware) throws Exception {
        Modelo a = painelCurvas(firmware);
        a.curvas.ventEstado = "silencioso:vivo";
        salvar(a, fontes, new File(saida, "home-curvas-vent-silencioso.png"));

        Modelo b = painelCurvas(firmware);
        b.curvas.mover(0, 1);
        b.curvas.mover(1, 0);
        b.curvas.mover(1, 0);
        b.curvas.ok();
        b.curvas.mover(0, -1);
        salvar(b, fontes, new File(saida, "home-curvas-vent-manual-pegando.png"));

        Modelo c = painelCurvas(firmware);
        c.curvas.ventAviso = "firmware";
        c.curvas.ventEstado = "silencioso:desistiu";
        c.curvas.mover(1, 0);
        c.curvas.mover(1, 0);
        salvar(c, fontes, new File(saida, "home-curvas-vent-aviso.png"));

        Modelo d = painelCurvas(firmware);
        d.curvas.mover(0, -1);
        d.curvas.mover(1, 0);
        d.curvas.mover(0, 1);
        d.curvas.mover(1, 0);
        d.curvas.ledEstado = "silencioso:vivo";
        salvar(d, fontes, new File(saida, "home-curvas-led-silencioso.png"));

        Modelo e = painelCurvas(firmware);
        e.curvas.mover(0, -1);
        e.curvas.mover(1, 0);
        salvar(e, fontes, new File(saida, "home-curvas-led-padrao.png"));

        Modelo f = painelCurvas(firmware);
        f.curvas.mover(0, -1);
        f.curvas.mover(1, 0);
        f.curvas.mover(1, 0);
        f.curvas.mover(0, 1);
        f.curvas.logoEstado = "ligado";
        f.curvas.logoCantos = "95,915 1715,1030 40,25 1775,35";
        f.curvas.logoHora = "2026-11-01 21:40";
        salvar(f, fontes, new File(saida, "home-curvas-logo-ligado.png"));

        Modelo g = painelCurvas(firmware);
        g.curvas.mover(0, -1);
        g.curvas.mover(1, 0);
        g.curvas.mover(1, 0);
        g.curvas.logoEstado = "desligado";
        g.curvas.logoCantos = Curvas.LOGO_RETO;
        g.curvas.logoMotivo = "releitura_devolvido";
        salvar(g, fontes, new File(saida, "home-curvas-logo-recusa.png"));
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

    /** Com cabo no HDMI 1 e no HDMI 2: a tela das previas de antes do bloco 30. */
    private static Modelo base() {
        Modelo m = Modelo.padrao();
        m.definirEntradas(Entradas.lista(true, true, false));
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
        verdade(m.entradas.length == 2 && m.mover(1, 0) && !m.mover(1, 0) && m.focado().acao.equals(Acoes.HDMI2),
                "duas entradas, sem USB-C; a ultima e HDMI 2");
        verdade(m.mover(0, 1) && m.fileira == Modelo.ATALHOS && m.coluna == 5, "de HDMI 2 desce para Configuracoes");
        verdade(m.atalhos.length == 6 && !m.mover(1, 0), "seis atalhos, Configuracoes e o ultimo");
        verdade(m.atalhos[4].acao.equals(Acoes.CURVAS) && m.atalhos[5].acao.equals(Acoes.CONFIG), "Curvas antes de Configuracoes");
        for (Item it : m.atalhos) verdade(!it.rotulo.equals("Imagem"), "o atalho Imagem saiu");
        verdade(Modelo.OCULTOS.contains("com.newlink.filemanager"), "o gerenciador de arquivos sai da fileira Apps");
        for (Item it : m.apps) verdade(!"com.newlink.filemanager".equals(it.pacote), "gerenciador na fileira");
        verdade(m.mover(0, -1) && m.fileira == Modelo.ENTRADAS && m.coluna == 1, "de Configuracoes sobe para HDMI 2");
        verdade(m.mover(0, 1) && m.coluna == 5, "e desce de novo para Configuracoes");
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
        // cima e baixo nao sao engolidas no painel Luz (bloco 28): cima = mais luz, baixo = menos, sem fechar
        z.luz = 60;
        z.abrirLuz();
        verdade(z.moverLuz(0, -1) && z.nivelLuz() == 80 && z.luzAberta, "cima: 60 -> 80 (mais luz)");
        verdade(z.moverLuz(0, 1) && z.moverLuz(0, 1) && z.nivelLuz() == 40 && z.luzAberta, "baixo: 80 -> 40 (menos luz)");
        verdade(z.moverLuz(0, 1) && !z.moverLuz(0, 1) && z.nivelLuz() == Modelo.LUZ_ECONOMICO, "baixo para em 25");
        for (int i = 0; i < 4; i++) z.moverLuz(0, -1);
        verdade(z.nivelLuz() == 100 && !z.moverLuz(0, -1) && z.luzAberta, "cima para em 100, o painel segue aberto");
        verdade(z.moverLuz(1, 0) && z.nivelLuz() == 80 && !z.moverLuz(0, 0), "direita igual a moverLuz(1); sem seta, nada");
        z.inicio();
        verdade(!z.luzAberta, "HOME fecha o painel de luz");
        Modelo o = base();
        List<Item> com = new ArrayList<Item>(apps);
        for (String pk : Modelo.OCULTOS) com.add(Item.app("Oculto " + pk, pk, ""));
        o.definirApps(com);
        verdade(o.apps.size() == m.apps.size() && !m.apps.isEmpty(), "a fileira Apps nao traz Office, iOSCast nem Espelhamento");
        for (Item it : o.apps) verdade(!Modelo.OCULTOS.contains(it.pacote), "oculto na fileira: " + it.pacote);
        Modelo v = base();
        v.definirApps(new ArrayList<Item>());
        v.mover(0, 1);
        verdade(!v.mover(0, 1) && v.fileira == Modelo.ATALHOS, "sem apps, a fileira vazia nao pega foco");
        checarCurvas();
        System.out.println("navegacao: conferencias ok");
    }

    private static void checarCurvas() {
        Modelo m = base();
        verdade(!m.curvasAberta, "o painel de curvas comeca fechado");
        m.abrirCurvas();
        Curvas c = m.curvas;
        verdade(m.curvasAberta && c.aba == Curvas.ABA_VENT && c.zona == Curvas.ZONA_PERFIL && c.perfilVent == 0, "abre em Ventiladores, Silencioso");
        verdade(c.pedido().equals("v1 silencioso vivo 30:70 45:70 55:75 61:85 66:100"), "pedido do Silencioso: " + c.pedido());
        verdade(c.mover(1, 0) && c.nomePerfil().equals("balanceado") && c.pedido().equals("v1 balanceado vivo 30:70 45:75 55:85 60:95 66:100"), "perfil Balanceado");
        verdade(c.mover(1, 0) && c.nomePerfil().equals("agressivo") && !c.editavel(), "Agressivo nao se edita");
        verdade(c.pedido().equals("v1 agressivo vivo 30:100 40:100 50:100 60:100 66:100"), "pedido Agressivo: " + c.pedido());
        verdade(c.mover(0, 1) && c.zona == Curvas.ZONA_GRAFICO, "desce para o grafico");
        verdade(c.ok() == Curvas.NADA && !c.pegando, "OK no Agressivo nao pega bola");
        verdade(c.mover(0, -1) && c.mover(-1, 0) && c.mover(-1, 0) && c.nomePerfil().equals("silencioso") && !c.mover(-1, 0), "volta ao Silencioso");
        verdade(c.mover(0, 1) && c.zona == Curvas.ZONA_GRAFICO && c.bola == 0, "grafico, bola 1");
        verdade(c.mover(1, 0) && c.mover(1, 0) && c.mover(1, 0) && c.mover(1, 0) && c.bola == 4 && !c.mover(1, 0), "cinco bolinhas");
        c.ok();
        verdade(c.pegando, "OK pega a bola 5");
        verdade(!c.mover(0, 1) && !c.mover(0, -1) && c.ventV[4] == 100, "a bola 5 fica em 100% sempre");
        verdade(!c.mover(1, 0) && c.ventT[4] == 66, "a bola 5 nao passa de 66 C");
        for (int i = 0; i < 80; i++) c.mover(-1, 0);
        verdade(c.ventT[4] == c.ventT[3] + 1, "a bola 5 nao passa da 4: " + c.ventT[4] + "/" + c.ventT[3]);
        verdade(c.voltar() && !c.pegando && !c.voltar(), "Voltar solta a bola; sem bola pega, fecha");
        verdade(c.nomePerfil().equals("manual"), "mexer numa bola vira Manual");
        c.mover(-1, 0);
        c.mover(-1, 0);
        c.mover(-1, 0);
        verdade(c.bola == 1 && c.ok() == Curvas.NADA && c.pegando, "pega a bola 2");
        for (int i = 0; i < 30; i++) c.mover(0, 1);
        verdade(c.ventV[1] == 70, "o piso e 70%: " + c.ventV[1]);
        for (int i = 0; i < 30; i++) c.mover(0, -1);
        verdade(c.ventV[1] == c.ventV[2], "a bola 2 nao passa da 3 em velocidade: " + c.ventV[1] + "/" + c.ventV[2]);
        for (int i = 0; i < 60; i++) c.mover(-1, 0);
        verdade(c.ventT[1] == c.ventT[0] + 1, "a bola 2 nao passa da 1 em temperatura");
        for (int i = 0; i < 4; i++) verdade(c.ventT[i] < c.ventT[i + 1] && c.ventV[i] <= c.ventV[i + 1] && c.ventV[i] >= 70 && c.ventT[i] >= 25, "ordem das bolas " + i);
        c.voltar();
        c.mover(0, -1);
        c.mover(-1, 0);
        c.mover(-1, 0);
        verdade(c.nomePerfil().equals("balanceado"), "troca para Balanceado");
        c.mover(1, 0);
        c.mover(1, 0);
        verdade(c.nomePerfil().equals("manual") && c.ventT[1] == c.ventT[0] + 1, "o Manual guarda as bolinhas do dono");
        c.mover(0, -1);
        verdade(c.zona == Curvas.ZONA_ABA && c.mover(1, 0) && c.aba == Curvas.ABA_LED && c.perfilLed == 0, "aba LED, Padrao do firmware");
        verdade(c.pedido().equals("v1 padrao vivo"), "padrao nao manda pontos: " + c.pedido());
        verdade(c.mover(0, 1) && c.mover(1, 0) && c.nomePerfil().equals("silencioso") && c.pedido().equals("v1 silencioso vivo 45:950 55:900 62:850"), "LED silencioso: " + c.pedido());
        c.mover(0, 1);
        c.ok();
        for (int i = 0; i < 40; i++) c.mover(0, 1);
        verdade(c.ledB[0] == c.ledB[1], "o brilho nao desce abaixo da bola seguinte: " + c.ledB[0]);
        for (int i = 0; i < 80; i++) c.mover(0, -1);
        verdade(c.ledB[0] == 1000, "o brilho nao passa de 1000");
        c.voltar();
        c.mover(1, 0);
        c.mover(1, 0);
        c.ok();
        for (int i = 0; i < 60; i++) c.mover(1, 0);
        verdade(c.ledT[2] == 69, "o LED so edita abaixo de 70 C: " + c.ledT[2]);
        for (int i = 0; i < 60; i++) c.mover(0, 1);
        verdade(c.ledB[2] == 850, "o brilho minimo e 850: " + c.ledB[2]);
        verdade(c.ledB[0] >= c.ledB[1] && c.ledB[1] >= c.ledB[2], "brilho nao crescente");
        c.voltar();
        c.mover(0, 1);
        c.mover(1, 0);
        verdade(c.modo == 1 && c.pedido().startsWith("v1 manual gravar "), "modo gravar: " + c.pedido());
        c.mover(1, 0);
        verdade(c.modo == 2 && !c.mover(1, 0), "tres modos");
        c.mover(0, 1);
        verdade(c.zona == Curvas.ZONA_APLICAR && !c.mover(0, 1) && c.ok() == Curvas.APLICAR, "OK no botao aplica");
        verdade(Curvas.pedidoValido(c.pedido()) && !Curvas.pedidoValido("v2 x vivo") && !Curvas.pedidoValido("v1 x ao-vivo") && !Curvas.pedidoValido(null), "pedidoValido");
        verdade(Curvas.rotuloEstado("silencioso:vivo").equals("Silencioso, ao vivo") && Curvas.rotuloEstado("").equals("Padrão do firmware"), "rotulos de estado");
        verdade(Curvas.rotuloAviso("firmware", true).contains("100%") && Curvas.rotuloAviso("", true).isEmpty(), "rotulos de aviso");
        c.zona = Curvas.ZONA_ABA;
        verdade(c.mover(1, 0) && c.aba == Curvas.ABA_LOGO && !c.mover(1, 0), "terceira aba: Logo do boot, a ultima");
        verdade(c.ok() == Curvas.NADA && c.mover(0, 1) && c.zona == Curvas.ZONA_PERFIL && !c.mover(0, 1), "na aba do logo so ha a chave abaixo das abas");
        verdade(!c.mover(1, 0) && !c.mover(-1, 0) && c.aba == Curvas.ABA_LOGO, "esquerda e direita na chave nao trocam de aba");
        verdade(c.logoLigado() && c.pedidoLogo().equals("desligado") && c.ok() == Curvas.LOGO, "chave ligada por padrao; OK pede desligar");
        c.logoEstado = "desligado";
        verdade(!c.logoLigado() && c.pedidoLogo().equals("ligado"), "desligada: OK pede ligar");
        c.pedindo = "ligado";
        verdade(c.ok() == Curvas.NADA, "nao pede de novo enquanto envia");
        c.pedindo = null;
        verdade(Curvas.pedidoLogoValido("ligado") && Curvas.pedidoLogoValido("desligado") && !Curvas.pedidoLogoValido("sim") && !Curvas.pedidoLogoValido(null), "pedidoLogoValido");
        verdade(Curvas.rotuloCantos(Curvas.LOGO_RETO).startsWith("Retos") && Curvas.rotuloCantos("").startsWith("Ainda") && Curvas.rotuloCantos("1,2 3,4 5,6 7,8").contains("Inf. dir. 7,8"), "rotulos dos cantos");
        verdade(Curvas.rotuloMotivo("").equals("Nenhuma") && Curvas.rotuloMotivo("nao_convexo").contains("quadril") && Curvas.rotuloMotivo("xyz").contains("xyz"), "rotulos das recusas");
        String[] motivos = {"formato", "fora_da_tela", "nao_convexo", "canto_trocado", "area_pequena", "programa", "arte", "modelo", "particao", "cabecalho", "suite_rodando", "pendrive", "backup", "primeiro", "mudou", "releitura_devolvido", "releitura_sem_volta", "trabalho", "gerar", "montar"};
        for (String mo : motivos) verdade(!Curvas.rotuloMotivo(mo).startsWith("Não gravado ("), "motivo sem texto: " + mo);
        verdade(c.mover(0, -1) && c.zona == Curvas.ZONA_ABA && c.mover(-1, 0) && c.aba == Curvas.ABA_LED, "volta para a aba LED");
        m.inicio();
        verdade(!m.curvasAberta, "HOME fecha o painel de curvas");
    }

    private static void verdade(boolean b, String o) {
        if (!b) throw new AssertionError("navegacao: " + o);
    }
}
