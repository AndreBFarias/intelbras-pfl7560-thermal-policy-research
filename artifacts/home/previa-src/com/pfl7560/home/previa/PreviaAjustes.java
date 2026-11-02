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

    public static void main(String[] a) throws Exception {
        File fontes = new File(a[0]);
        File saida = new File(a[1]);
        if (!saida.isDirectory() && !saida.mkdirs()) throw new IllegalStateException("sem pasta " + saida);

        Modelo m = painel();
        m.ajustes.estado = "1111110000";
        salvar(m, fontes, new File(saida, "home-ajustes-padroes.png"));

        Modelo r = painel();
        r.ajustes.estado = "1111111010";
        for (int i = 0; i < 7; i++) r.ajustes.mover(0, 1);
        salvar(r, fontes, new File(saida, "home-ajustes-risco-alto.png"));

        Modelo c = painel();
        c.ajustes.estado = "11p-1100?0";
        for (int i = 0; i < 7; i++) c.ajustes.mover(0, 1);
        c.ajustes.ok();
        salvar(c, fontes, new File(saida, "home-ajustes-confirmar.png"));

        Modelo p = painel();
        p.ajustes.estado = "1101100001";
        p.ajustes.mover(0, 1);
        p.ajustes.mover(0, 1);
        p.aviso = "Pedi, mas o projetor não confirmou a mudança";
        salvar(p, fontes, new File(saida, "home-ajustes-aviso.png"));

        Modelo d = painel();
        irParaDiario(d.ajustes);
        d.ajustes.diario = "1:131072:0";
        d.ajustes.diarioEnvio = "2026-11-01T21:44:09";
        salvar(d, fontes, new File(saida, "home-ajustes-diario.png"));

        Modelo e = painel();
        irParaDiario(e.ajustes);
        e.ajustes.diario = "1:262144:1";
        e.ajustes.diarioEnvio = "";
        e.ajustes.mover(0, 1);
        e.aviso = "Feito";
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

    private static void irParaDiario(Ajustes a) {
        a.mover(0, -1);
        a.mover(1, 0);
        a.mover(0, 1);
    }

    private static void salvar(Modelo m, File fontes, File png) throws Exception {
        BufferedImage img = new BufferedImage(1920, 1080, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        Desenho.desenhar(new PintorJ2D(g, fontes), m);
        g.dispose();
        ImageIO.write(img, "png", png);
        System.out.println("previa: " + png);
    }

    private static void verdade(boolean ok, String msg) {
        if (!ok) throw new IllegalStateException("FALHOU: " + msg);
    }

    static void checar() {
        Modelo m = painel();
        Ajustes a = m.ajustes;
        verdade(m.ajustesAberta && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0, "abre na primeira chave");
        verdade(Ajustes.IDS.length == 10 && Ajustes.ROTULOS.length == 10 && Ajustes.FAZ.length == 10
                && Ajustes.RISCO.length == 10 && Ajustes.NIVEL_RISCO.length == 10 && Ajustes.CONFIRMA.length == 10,
                "dez chaves, cada uma com rotulo, texto e risco");
        for (int i = 0; i < 10; i++) {
            verdade(!Ajustes.RISCO[i].isEmpty() && !Ajustes.FAZ[i].isEmpty(), "chave " + i + " sem mensagem de risco");
        }
        verdade(!a.mover(1, 0) && !a.mover(-1, 0), "nas linhas esquerda e direita nao fazem nada");
        verdade(a.mover(0, -1) && a.zona == Ajustes.ZONA_ABA && a.aba == Ajustes.ABA_CHAVES, "de cima da primeira chave sobe para as abas");
        verdade(!a.mover(0, -1) && !a.mover(-1, 0), "nas abas nada sobe e nao ha aba a esquerda");
        verdade(a.mover(0, 1) && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0, "baixo volta para as chaves");
        for (int i = 0; i < 9; i++) verdade(a.mover(0, 1), "desce " + i);
        verdade(a.linha == 9 && !a.mover(0, 1), "termina na decima");
        // pedidos
        a.estado = "0000000000";
        a.linha = 0;
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 deb_seg ligar"), "liga: " + a.pedido());
        a.estado = "1000000000";
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 deb_seg desligar"), "desliga: " + a.pedido());
        a.estado = "p000000000";
        verdade(a.pedido().equals("v1 deb_seg ligar"), "parcial pede ligar de novo");
        // ausente e ilegivel nao pedem
        a.estado = "-000000000";
        verdade(a.ok() == Ajustes.NADA, "chave ausente nao pede");
        a.estado = "?000000000";
        verdade(a.ok() == Ajustes.NADA, "estado ilegivel nao pede");
        a.estado = "";
        verdade(a.ok() == Ajustes.NADA && a.estadoDe(3) == '?', "sem leitura: nada pede");
        a.estado = "0000000000";
        // eth0 e chip Wi-Fi pedem OK duas vezes para LIGAR, nunca para desligar
        a.linha = 6;
        verdade(a.ok() == Ajustes.CONFIRMAR && a.confirmando == 6, "eth0 pede confirmacao");
        verdade(a.ok() == Ajustes.PEDIR && a.confirmando == -1, "segundo OK pede");
        a.ok();
        verdade(a.mover(0, 1) && a.confirmando == -1, "mudar de linha desiste da confirmacao");
        verdade(a.linha == 7 && a.ok() == Ajustes.CONFIRMAR, "chip Wi-Fi pede confirmacao");
        a.estado = "0000000100";
        a.linha = 7;
        a.confirmando = -1;
        a.estado = "0000000110";
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 wifi_pwr desligar"), "desligar o chip nao pede confirmacao");
        a.pedindo = "wifi_pwr";
        verdade(a.ok() == Ajustes.NADA, "com pedido em curso, OK nao faz nada");
        a.pedindo = null;
        // estados e avisos
        verdade(Ajustes.rotuloEstado('1').equals("Ligada") && Ajustes.rotuloEstado('0').equals("Desligada"), "rotulos");
        verdade(Ajustes.rotuloEstado('-').startsWith("Não existe") && Ajustes.rotuloEstado('?').startsWith("Não consegui"), "rotulos de ausencia");
        verdade(Ajustes.codigoDoAviso("eth0:ok:1793584405", "eth0").equals("ok"), "codigo do aviso");
        verdade(Ajustes.codigoDoAviso("eth0:ok:1793584405", "wifi_pwr").isEmpty(), "aviso de outra chave nao vale");
        verdade(Ajustes.codigoDoAviso("deb_hisi:nao-confere-p:1", "deb_hisi").equals("nao-confere-p"), "codigo com hifen");
        verdade(Ajustes.rotuloAviso("sem-home").startsWith("Não liguei"), "aviso sem-home");
        // validade dos pedidos que a home escreve
        verdade(Ajustes.pedidoValido("v1 ler") && Ajustes.pedidoValido("v1 eth0 ligar") && Ajustes.pedidoValido("v1 keystone desligar"), "pedidos validos");
        verdade(!Ajustes.pedidoValido("v1 eth0 ligar; reboot") && !Ajustes.pedidoValido("v1 xx ligar") && !Ajustes.pedidoValido("eth0 ligar")
                && !Ajustes.pedidoValido(null) && !Ajustes.pedidoValido(""), "pedidos invalidos");
        // todo pedido que a tela pode montar cabe no limite de 64 bytes do projetor e e valido
        for (int i = 0; i < 10; i++) {
            a.linha = i;
            for (String e : new String[] {"0000000000", "1111111111"}) {
                a.estado = e;
                verdade(Ajustes.pedidoValido(a.pedido()) && a.pedido().length() <= 40, "pedido da chave " + i);
            }
        }
        checarDiario();
        // o acesso e um item da fileira Apps, nao um oitavo atalho
        verdade(m.atalhos.length == 7, "os sete atalhos seguem sete");
        verdade(Acoes.AJUSTES.equals("ajustes"), "acao ajustes");
        List<Item> lista = new ArrayList<Item>();
        lista.add(new Item("Ajustes do sistema", com.pfl7560.home.Icones.AJUSTES, Acoes.AJUSTES));
        m.definirApps(lista);
        verdade(m.apps.size() == 1 && Acoes.AJUSTES.equals(m.apps.get(0).acao), "o item Ajustes aparece nos Apps");
        m.inicio();
        verdade(!m.ajustesAberta, "HOME fecha a tela de ajustes");
    }

    private static void checarDiario() {
        Modelo m = painel();
        Ajustes a = m.ajustes;
        verdade(Ajustes.ABAS.length == 2 && a.abas() == 2 && a.aba == Ajustes.ABA_CHAVES, "duas abas, abre em Chaves");
        irParaDiario(a);
        verdade(a.aba == Ajustes.ABA_DIARIO && a.zona == Ajustes.ZONA_LINHAS && a.linha == 0 && a.linhas() == 2, "aba Diario: duas linhas");
        verdade(!a.mover(0, -1) == false && a.zona == Ajustes.ZONA_ABA, "da primeira linha sobe para as abas");
        a.mover(0, 1);
        verdade(a.mover(0, 1) && a.linha == 1 && !a.mover(0, 1), "so duas linhas");
        a.linha = 0;
        // sem leitura nada pede
        verdade(a.ok() == Ajustes.NADA && a.estadoDiario() == '?' && a.diarioBytes() == 0, "sem leitura nada pede");
        a.diario = "lixo";
        verdade(!a.diarioLido() && a.ok() == Ajustes.NADA, "leitura fora do formato nao vale");
        a.diario = "1:4096:0";
        verdade(a.diarioLido() && a.diarioLigado() && !a.diarioPedido() && a.diarioBytes() == 4096, "leitura ligada");
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 desligar") && a.idEmFoco().equals("diario"), "ligado, OK desliga");
        a.diario = "0:0:0";
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 ligar") && a.estadoDiario() == '0', "desligado, OK liga");
        a.linha = 1;
        verdade(a.ok() == Ajustes.PEDIR && a.pedido().equals("v1 enviar"), "Enviar agora pede enviar");
        a.diario = "1:4096:1";
        verdade(a.diarioPedido() && a.ok() == Ajustes.NADA, "com pedido marcado, Enviar agora espera");
        a.diario = "1:4096:0";
        a.pedindo = "diario";
        verdade(a.ok() == Ajustes.NADA, "com pedido em curso, OK nao faz nada");
        a.pedindo = null;
        for (String v : new String[] {"v1 ligar", "v1 desligar", "v1 enviar", "v1 ler"}) {
            verdade(Ajustes.pedidoDiarioValido(v) && v.length() <= 16, "pedido valido " + v);
        }
        verdade(!Ajustes.pedidoDiarioValido("v1 ligar; reboot") && !Ajustes.pedidoDiarioValido("ligar")
                && !Ajustes.pedidoDiarioValido("v1 eth0 ligar") && !Ajustes.pedidoDiarioValido(null) && !Ajustes.pedidoDiarioValido(""),
                "pedidos do diario invalidos");
        verdade(!Ajustes.pedidoValido("v1 enviar") && !Ajustes.pedidoValido("v1 ligar"), "o pedido do diario nao passa pelas chaves");
        // tamanho e data
        verdade(Ajustes.rotuloTamanho(0).equals("vazio") && Ajustes.rotuloTamanho(900).equals("900 bytes"), "tamanho pequeno");
        verdade(Ajustes.rotuloTamanho(4096).equals("4,0 KB") && Ajustes.rotuloTamanho(131072).equals("128 KB"), "tamanho em KB: " + Ajustes.rotuloTamanho(4096));
        verdade(Ajustes.rotuloTamanho(524288).equals("512 KB") && Ajustes.rotuloTamanho(2097152).equals("2,0 MB"), "tamanho grande");
        verdade(Ajustes.rotuloEnvio("2026-11-01T21:44:09").equals("01/11/2026 21:44"), "data do envio");
        verdade(Ajustes.rotuloEnvio("").equals("nunca") && Ajustes.rotuloEnvio("ontem").equals("nunca") && Ajustes.rotuloEnvio(null).equals("nunca"),
                "sem envio: nunca");
        // voltar para Chaves e abrir de novo sempre cai em Chaves, na primeira linha
        m.fecharAjustes();
        m.abrirAjustes();
        verdade(a.aba == Ajustes.ABA_CHAVES && a.linha == 0 && a.zona == Ajustes.ZONA_LINHAS, "abre sempre em Chaves");
    }
}
