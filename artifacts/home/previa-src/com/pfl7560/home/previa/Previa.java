package com.pfl7560.home.previa;

import com.pfl7560.home.Acoes;
import com.pfl7560.home.Curvas;
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

        previasCurvas(fontes, saida, firmware);

        checarNavegacao(firmware);
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
        verdade(m.mover(0, 1) && m.fileira == Modelo.ATALHOS && m.coluna == 6, "de USB-C desce para Configuracoes");
        verdade(m.atalhos.length == 7 && !m.mover(1, 0), "sete atalhos, Configuracoes e o ultimo");
        verdade(m.atalhos[5].acao.equals(Acoes.CURVAS) && m.atalhos[6].acao.equals(Acoes.CONFIG), "Curvas antes de Configuracoes");
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
