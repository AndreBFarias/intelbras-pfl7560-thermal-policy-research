package com.pfl7560.home.previa;

import com.pfl7560.home.Acoes;
import com.pfl7560.home.Ajustes;
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
 * Previas e conferencias da tela "Ajustes do sistema" (bloco 24). Fica a parte da Previa para nao mexer nas
 * imagens ja guardadas da home: este programa so escreve na pasta previa-ajustes/.
 */
public final class PreviaAjustes {
    private PreviaAjustes() {
    }

    /**
     * A medida como o kit instala (padrao_de do suite-chaves.sh): os cinco grupos de debloat, o log do vplugin e o
     * aviso de dispositivo conectado aplicados (servicos desligados); porta de rede, chip Wi-Fi, web e keystone livres.
     */
    private static final String PADRAO = "11111100001";

    public static void main(String[] a) throws Exception {
        File fontes = new File(a[0]);
        File saida = new File(a[1]);
        if (!saida.isDirectory() && !saida.mkdirs()) throw new IllegalStateException("sem pasta " + saida);

        Modelo m = painel();
        m.ajustes.estado = PADRAO;
        salvar(m, fontes, new File(saida, "home-ajustes-padroes.png"));

        Modelo l = painel();
        salvar(l, fontes, new File(saida, "home-ajustes-lendo.png"));

        Modelo ap = painel();
        ap.ajustes.estado = PADRAO;
        for (int i = 0; i < 7; i++) ap.ajustes.mover(0, 1);
        ap.ajustes.ok();
        ap.ajustes.marcarAplicando();
        salvar(ap, fontes, new File(saida, "home-ajustes-aplicando.png"));

        Modelo c = painel();
        c.ajustes.estado = "11p-1100?000";
        for (int i = 0; i < 6; i++) c.ajustes.mover(0, 1);
        c.ajustes.ok();
        salvar(c, fontes, new File(saida, "home-ajustes-confirmar.png"));

        Modelo p = painel();
        p.ajustes.estado = PADRAO;
        p.ajustes.mover(0, 1);
        p.ajustes.mover(0, 1);
        p.aviso = "O projetor não confirmou a mudança";
        salvar(p, fontes, new File(saida, "home-ajustes-aviso.png"));

        Modelo d = painel();
        d.ajustes.estado = PADRAO;
        d.ajustes.mover(1, 0);
        d.ajustes.diario = "1:131072:0";
        d.ajustes.diarioEnvio = "2026-11-01T21:44:09";
        salvar(d, fontes, new File(saida, "home-ajustes-diario.png"));

        Modelo e = painel();
        e.ajustes.estado = PADRAO;
        e.ajustes.mover(1, 0);
        e.ajustes.diario = "1:262144:1";
        e.ajustes.diarioEnvio = "";
        e.ajustes.mover(0, 1);
        salvar(e, fontes, new File(saida, "home-ajustes-diario-pedido.png"));

        checar();
        System.out.println("ajustes: conferencias ok");
    }

    private static Modelo painel() {
        Modelo m = Modelo.padrao();
        Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("America/Sao_Paulo"));
        cal.clear();
        cal.set(2026, Calendar.NOVEMBER, 1, 21, 47, 0);
        m.relogio(cal);
        m.abrirAjustes();
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

    /** A linha da tela que mostra o id i; -1 se ele fica escondido. */
    private static int linhaDe(int i) {
        for (int l = 0; l < Ajustes.VISIVEIS.length; l++) if (Ajustes.VISIVEIS[l] == i) return l;
        return -1;
    }

    private static void verdade(boolean ok, String msg) {
        if (!ok) throw new IllegalStateException("FALHOU: " + msg);
    }

    static void checar() {
        Modelo m = painel();
        Ajustes a = m.ajustes;
        verdade(m.ajustesAberta && a.aba == Ajustes.ABA_SERVICOS && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0,
                "abre em Servicos, no primeiro item");
        verdade(Ajustes.ABAS[0].equals("Serviços") && Ajustes.ABAS[1].equals("Diário"), "abas Servicos e Diario");
        int n = Ajustes.IDS.length;
        verdade(n == 11 && Ajustes.ROTULOS.length == n && Ajustes.FAZ.length == n && Ajustes.CONFIRMA.length == n
                && a.aplicando.length == n, "onze ids, cada um com rotulo e texto");
        verdade(Ajustes.IDS[10].equals("pop_disp") && Ajustes.IDS[7].equals("wifi_pwr") && Ajustes.IDS[6].equals("eth0"),
                "a ordem do projetor nao muda, so cresce no fim");
        // indices escondidos: o chip Wi-Fi nao aparece, os outros dez sim, em ordem
        verdade(Ajustes.VISIVEIS.length == 10, "dez itens na tela");
        for (int k = 0; k < Ajustes.VISIVEIS.length; k++) {
            verdade(Ajustes.VISIVEIS[k] != 7, "wifi_pwr escondido");
            if (k > 0) verdade(Ajustes.VISIVEIS[k] > Ajustes.VISIVEIS[k - 1], "visiveis em ordem");
        }
        verdade(Ajustes.ROTULOS[6].equals("Porta de rede por cabo") && Ajustes.ROTULOS[4].equals("Office do fabricante"),
                "eth0 e deb_vlc com o nome novo");
        for (int i = 0; i < n; i++) {
            String txt = (Ajustes.ROTULOS[i] + " " + Ajustes.FAZ[i]).toLowerCase(java.util.Locale.ROOT);
            verdade(!txt.contains("chave"), "a palavra chave sumiu: " + Ajustes.ROTULOS[i]);
            verdade(Ajustes.ROTULOS[i].length() <= 32 && Ajustes.FAZ[i].length() <= 64, "texto curto: " + Ajustes.ROTULOS[i]);
        }
        for (String r : new String[] {Ajustes.rotuloAviso("ok"), Ajustes.rotuloAviso("sem-home"), Ajustes.rotuloAviso("ausente"),
                Ajustes.rotuloAviso("sem-ip"), Ajustes.rotuloAviso("recusado"), Ajustes.rotuloAviso("sumiu"),
                Ajustes.rotuloAviso("nao-confere-p")}) {
            verdade(!r.toLowerCase(java.util.Locale.ROOT).contains("chave") && !r.contains("liguei"), "aviso sem chave: " + r);
        }
        // traducao servico <-> medida, nos dois sentidos
        verdade(Ajustes.servicoDaMedida('1') == '0' && Ajustes.servicoDaMedida('0') == '1', "medida aplicada = servico desligado");
        for (char c : new char[] {'1', '0', 'p', '-', '?'}) {
            verdade(Ajustes.medidaDoServico(Ajustes.servicoDaMedida(c)) == c, "ida e volta de " + c);
        }
        verdade(Ajustes.servicoDaMedida('p') == 'p' && Ajustes.servicoDaMedida('-') == '-', "parcial e ausente passam iguais");
        // a traducao vale para TODOS os ids: medida aplicada = servico desligado, e o OK pede o contrario do que se ve
        for (int i = 0; i < n; i++) {
            Ajustes t = painel().ajustes;
            char[] cs = "00000000000".toCharArray();
            cs[i] = '1';
            t.estado = new String(cs);
            verdade(t.servico(i) == '0' && t.rotuloServico(i).equals("Desligado") && t.servico(i == 0 ? 1 : 0) == '1',
                    "medida 1 = desligado: " + Ajustes.IDS[i]);
            t.linha = linhaDe(i);
            if (t.linha < 0) continue;
            verdade(t.indice() == i && t.pedido().equals("v1 " + Ajustes.IDS[i] + " desligar"),
                    "desligado: OK liga o servico (desliga a medida): " + Ajustes.IDS[i]);
            t.marcarAplicando();
            verdade(t.servico(i) == '1' && t.aplicando[i] == '0', "aplicando mostra ligado: " + Ajustes.IDS[i]);
            t.confirmar(Ajustes.IDS[i], "00000000000");
            verdade(t.servico(i) == '1' && t.rotuloServico(i).equals("Ligado"), "confirmado ligado: " + Ajustes.IDS[i]);
            verdade(t.pedido().equals("v1 " + Ajustes.IDS[i] + " ligar"), "ligado: OK desliga o servico: " + Ajustes.IDS[i]);
            if (Ajustes.CONFIRMA[i]) verdade(t.ok() == Ajustes.CONFIRMAR, "desligar pede confirmacao: " + Ajustes.IDS[i]);
            verdade(t.ok() == Ajustes.PEDIR, "OK pede: " + Ajustes.IDS[i]);
            t.marcarAplicando();
            verdade(t.servico(i) == '0' && t.aplicando[i] == '1' && t.rotuloServico(i).equals("Aplicando…"),
                    "aplicando mostra desligado: " + Ajustes.IDS[i]);
        }
        a.estado = "10000000000";
        verdade(a.servico(0) == '0' && a.rotuloServico(0).equals("Desligado") && a.ok() == Ajustes.PEDIR
                && a.pedido().equals("v1 deb_seg desligar"), "servico desligado: OK liga (pede desligar a medida)");
        a.estado = "00000000000";
        verdade(a.servico(0) == '1' && a.rotuloServico(0).equals("Ligado") && a.pedido().equals("v1 deb_seg ligar"),
                "servico ligado: OK desliga (pede ligar a medida)");
        // o protocolo segue o mesmo
        verdade(Ajustes.pedidoValido("v1 pop_disp ligar") && Ajustes.pedidoValido("v1 eth0 desligar") && Ajustes.pedidoValido("v1 ler"),
                "pedidos validos");
        verdade(!Ajustes.pedidoValido("v1 eth0 ligar; reboot") && !Ajustes.pedidoValido("v1 xx ligar") && !Ajustes.pedidoValido("eth0 ligar")
                && !Ajustes.pedidoValido(null) && !Ajustes.pedidoValido(""), "pedidos invalidos");
        // "Lendo…" ate ler
        Modelo lm = painel();
        Ajustes la = lm.ajustes;
        verdade(!la.lido() && la.precisaLer(), "abre sem leitura");
        for (int k = 0; k < Ajustes.VISIVEIS.length; k++) {
            verdade(la.rotuloServico(Ajustes.VISIVEIS[k]).equals("Lendo…"), "Lendo… no item " + k);
        }
        verdade(la.ok() == Ajustes.NADA, "sem leitura, OK nada pede");
        verdade(la.rotuloEstadoDiario().equals("Lendo…"), "Diario tambem diz Lendo…");
        la.estado = PADRAO;
        verdade(la.lido() && !la.rotuloServico(0).equals("Lendo…") && la.precisaLer(), "lido Servicos; falta o Diario");
        la.diario = "0:0:0";
        verdade(!la.precisaLer(), "tudo lido: para de reler");
        verdade(la.estadoDe(11) == '-', "kit antigo sem o id: nao existe aqui");
        la.estado = "1111000000";
        la.linha = 9;
        verdade(la.indice() == 10 && la.ok() == Ajustes.NADA && la.rotuloServico(10).equals("Não existe aqui"),
                "pop_disp sem o kit novo: nao pede");
        // OK muda na hora: "Aplicando…" com o alvo, e o projetor confirma depois
        Modelo om = painel();
        Ajustes oa = om.ajustes;
        oa.estado = PADRAO;
        oa.linha = 0;
        verdade(oa.ok() == Ajustes.PEDIR, "OK pede");
        String ped = oa.marcarAplicando();
        verdade(ped.equals("v1 deb_seg desligar"), "pedido: " + ped);
        verdade(oa.emCurso(0) && oa.servico(0) == '1' && oa.rotuloServico(0).equals("Aplicando…") && oa.algumEmCurso(),
                "a tela ja mostra o alvo (ligado) e Aplicando…");
        verdade(oa.ok() == Ajustes.NADA, "com o pedido em curso, OK de novo nao faz nada");
        verdade(oa.mover(0, 1) && oa.ok() == Ajustes.PEDIR, "outro item segue livre");
        oa.confirmar("deb_seg", "01110000000");
        verdade(!oa.emCurso(0) && !oa.algumEmCurso() && oa.servico(0) == '1' && oa.rotuloServico(0).equals("Ligado"),
                "o projetor confirmou");
        oa.linha = 0;
        oa.marcarAplicando();
        oa.confirmar("deb_seg", "");
        verdade(!oa.emCurso(0) && oa.servico(0) == '1', "sem resposta: volta ao que foi lido");
        // porta de rede: desligar o servico pede OK duas vezes; ligar nao
        oa.estado = PADRAO;
        oa.linha = 6;
        verdade(oa.indice() == 6 && oa.ok() == Ajustes.CONFIRMAR && oa.confirmando == 6, "desligar a porta de rede pede confirmacao");
        verdade(oa.ok() == Ajustes.PEDIR && oa.confirmando == -1 && oa.pedido().equals("v1 eth0 ligar"), "segundo OK pede");
        oa.ok();
        verdade(oa.mover(0, 1) && oa.confirmando == -1, "mudar de linha desiste da confirmacao");
        oa.estado = "00000010000";
        oa.linha = 6;
        verdade(oa.ok() == Ajustes.PEDIR && oa.pedido().equals("v1 eth0 desligar"), "religar a porta nao pede confirmacao");
        // todo pedido que a tela pode montar e valido e curto
        for (int k = 0; k < Ajustes.VISIVEIS.length; k++) {
            oa.linha = k;
            for (String e : new String[] {"00000000000", "11111111111"}) {
                oa.estado = e;
                verdade(Ajustes.pedidoValido(oa.pedido()) && oa.pedido().length() <= 40, "pedido do item " + k);
            }
        }
        checarSetas();
        checarDiario();
        checarVoltar();
        // o acesso e um item da fileira Apps, nao um atalho
        verdade(Acoes.AJUSTES.equals("ajustes"), "acao ajustes");
        List<Item> lista = new ArrayList<Item>();
        lista.add(new Item("Ajustes do sistema", com.pfl7560.home.Icones.AJUSTES, Acoes.AJUSTES));
        m.definirApps(lista);
        verdade(m.apps.size() == 1 && Acoes.AJUSTES.equals(m.apps.get(0).acao), "o item Ajustes aparece nos Apps");
        m.inicio();
        verdade(!m.ajustesAberta, "HOME fecha a tela de ajustes");
    }

    /** Voltar fecha a tela aberta com um aperto, de qualquer lugar dela; arrastando bola, solta a bola. */
    private static void checarVoltar() {
        Modelo m = painel();
        verdade(m.voltar() && !m.ajustesAberta, "Voltar fecha Servicos");
        m.abrirAjustes();
        m.ajustes.mover(0, -1);
        verdade(m.ajustes.zona == Ajustes.ZONA_ABA && m.voltar() && !m.ajustesAberta, "Voltar fecha das abas");
        m.abrirAjustes();
        m.ajustes.estado = PADRAO;
        m.ajustes.mover(1, 0);
        m.ajustes.mover(0, 1);
        verdade(m.voltar() && !m.ajustesAberta, "Voltar fecha o Diario");
        m.abrirAjustes();
        m.ajustes.linha = 6;
        m.ajustes.ok();
        verdade(m.ajustes.confirmando >= 0 && m.voltar() && !m.ajustesAberta && m.ajustes.confirmando == -1,
                "Voltar fecha mesmo esperando o segundo OK");
        m.abrirAjustes();
        m.ajustes.linha = 0;
        m.ajustes.marcarAplicando();
        m.aviso = "algo";
        verdade(m.voltar() && !m.ajustesAberta && m.aviso == null, "Voltar fecha com pedido em curso e apaga o aviso");
        m.abrirAjustes();
        verdade(m.ajustes.emCurso(0), "o pedido em curso segue ao reabrir");
        m.voltar();

        m.abrirLuz();
        m.moverLuz(1);
        verdade(m.voltar() && !m.luzAberta, "Voltar fecha a Luz");

        m.abrirCurvas();
        verdade(m.voltar() && !m.curvasAberta, "Voltar fecha as Curvas");
        m.abrirCurvas();
        m.curvas.mover(1, 0);
        m.curvas.mover(0, 1);
        verdade(m.voltar() && !m.curvasAberta, "Voltar fecha as Curvas de qualquer zona");
        m.abrirCurvas();
        m.curvas.pegando = true;
        verdade(m.voltar() && m.curvasAberta && !m.curvas.pegando, "arrastando bola, Voltar solta a bola");
        verdade(m.voltar() && !m.curvasAberta, "o aperto seguinte fecha");

        verdade(!m.voltar() && !m.luzAberta && !m.curvasAberta && !m.ajustesAberta, "na tela principal Voltar segue ao sistema");
    }

    /** Direita e esquerda trocam de aba de qualquer lugar da tela, sem engolir a tecla. */
    private static void checarSetas() {
        Modelo m = painel();
        Ajustes a = m.ajustes;
        a.estado = PADRAO;
        a.mover(0, 1);
        a.mover(0, 1);
        verdade(a.mover(1, 0) && a.aba == Ajustes.ABA_DIARIO && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0,
                "direita nas linhas vai ao Diario, na primeira linha");
        verdade(!a.mover(1, 0) && a.aba == Ajustes.ABA_DIARIO, "nao ha aba a direita do Diario");
        verdade(a.mover(-1, 0) && a.aba == Ajustes.ABA_SERVICOS && a.linha == 0, "esquerda volta a Servicos");
        verdade(!a.mover(-1, 0), "nao ha aba a esquerda de Servicos");
        verdade(a.mover(0, -1) && a.zona == Ajustes.ZONA_ABA, "de cima do primeiro item sobe para as abas");
        verdade(a.mover(1, 0) && a.aba == Ajustes.ABA_DIARIO && a.zona == Ajustes.ZONA_ABA, "nas abas, direita troca e fica nas abas");
        verdade(!a.mover(0, -1), "nada acima das abas");
        verdade(a.mover(0, 1) && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0, "baixo desce para as linhas");
        a.mover(-1, 0);
        for (int i = 0; i < Ajustes.VISIVEIS.length - 1; i++) verdade(a.mover(0, 1), "desce " + i);
        verdade(a.linha == Ajustes.VISIVEIS.length - 1 && a.indice() == 10 && !a.mover(0, 1), "termina no aviso de dispositivo");
    }

    private static void checarDiario() {
        Modelo m = painel();
        Ajustes a = m.ajustes;
        verdade(Ajustes.ABAS.length == 2 && a.abas() == 2 && a.aba == Ajustes.ABA_SERVICOS, "duas abas, abre em Servicos");
        a.mover(1, 0);
        verdade(a.aba == Ajustes.ABA_DIARIO && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0 && a.linhas() == 2, "aba Diario: duas linhas");
        verdade(a.mover(0, -1) && a.zona == Ajustes.ZONA_ABA, "da primeira linha sobe para as abas");
        a.mover(0, 1);
        verdade(a.mover(0, 1) && a.linha == 1 && !a.mover(0, 1), "so duas linhas");
        a.linha = 0;
        verdade(a.ok() == Ajustes.NADA && a.estadoDiario() == '?' && a.diarioBytes() == 0, "sem leitura nada pede");
        a.diario = "lixo";
        verdade(!a.diarioLido() && a.ok() == Ajustes.NADA, "leitura fora do formato nao vale");
        a.diario = "1:4096:0";
        verdade(a.diarioLido() && a.diarioLigado() && !a.diarioPedido() && a.diarioBytes() == 4096, "leitura ligada");
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 desligar") && a.idEmFoco().equals("diario"), "ligado, OK desliga");
        a.diario = "0:0:0";
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 ligar") && a.estadoDiario() == '0', "desligado, OK liga");
        // OK muda na hora
        verdade(a.marcarAplicando().equals("v1 ligar") && a.estadoDiario() == '1' && a.rotuloEstadoDiario().equals("Aplicando…"),
                "Diario: a tela ja mostra o alvo");
        verdade(a.ok() == Ajustes.NADA && a.algumEmCurso(), "com o pedido em curso, OK nao faz nada");
        a.confirmarDiario("1:0:0", "");
        verdade(a.diarioAplicando == 0 && a.estadoDiario() == '1' && a.rotuloEstadoDiario().equals("Gravando"), "o projetor confirmou");
        a.linha = 1;
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 enviar"), "Enviar agora pede enviar");
        a.diario = "1:4096:1";
        verdade(a.diarioPedido() && a.ok() == Ajustes.NADA, "com pedido marcado, Enviar agora espera");
        for (String v : new String[] {"v1 ligar", "v1 desligar", "v1 enviar", "v1 ler"}) {
            verdade(Ajustes.pedidoDiarioValido(v) && v.length() <= 16, "pedido valido " + v);
        }
        verdade(!Ajustes.pedidoDiarioValido("v1 ligar; reboot") && !Ajustes.pedidoDiarioValido("ligar")
                && !Ajustes.pedidoDiarioValido("v1 eth0 ligar") && !Ajustes.pedidoDiarioValido(null) && !Ajustes.pedidoDiarioValido(""),
                "pedidos do diario invalidos");
        verdade(!Ajustes.pedidoValido("v1 enviar") && !Ajustes.pedidoValido("v1 ligar"), "o pedido do diario nao passa pelos servicos");
        verdade(Ajustes.rotuloTamanho(0).equals("vazio") && Ajustes.rotuloTamanho(900).equals("900 bytes"), "tamanho pequeno");
        verdade(Ajustes.rotuloTamanho(4096).equals("4,0 KB") && Ajustes.rotuloTamanho(131072).equals("128 KB"), "tamanho em KB");
        verdade(Ajustes.rotuloTamanho(524288).equals("512 KB") && Ajustes.rotuloTamanho(2097152).equals("2,0 MB"), "tamanho grande");
        verdade(Ajustes.rotuloEnvio("2026-11-01T21:44:09").equals("01/11/2026 21:44"), "data do envio");
        verdade(Ajustes.rotuloEnvio("").equals("nunca") && Ajustes.rotuloEnvio("ontem").equals("nunca") && Ajustes.rotuloEnvio(null).equals("nunca"),
                "sem envio: nunca");
        m.fecharAjustes();
        m.abrirAjustes();
        verdade(a.aba == Ajustes.ABA_SERVICOS && a.linha == 0 && a.zona == Ajustes.ZONA_LINHAS, "abre sempre em Servicos");
    }
}
