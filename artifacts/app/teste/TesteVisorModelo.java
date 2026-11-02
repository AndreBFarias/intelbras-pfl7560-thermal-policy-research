package com.pfl7560.verificar;

import java.io.File;
import java.nio.file.Files;

/**
 * Teste do modelo do visor (bloco 29), sem o android.jar: o tests/test-kit-pendrive.sh compila
 * src/.../VisorModelo.java com este arquivo e roda. Sai com 1 na primeira falha.
 */
public final class TesteVisorModelo {
    private static int n;

    private static void confere(boolean ok, String o) {
        n++;
        if (!ok) {
            System.out.println("FALHA: " + o);
            System.exit(1);
        }
    }

    public static void main(String[] a) throws Exception {
        // trocar a imagem nunca fecha o visor; so o pedido explicito fecha
        confere(VisorModelo.acao("etapa3-1793400000.png", false) == VisorModelo.Acao.MOSTRAR, "tela valida mostra");
        confere(VisorModelo.acao("resumo-1.png", false) != VisorModelo.Acao.FECHAR, "trocar a imagem nao fecha");
        confere(VisorModelo.acao("resumo-1.png", true) == VisorModelo.Acao.FECHAR, "fechar fecha");
        confere(VisorModelo.acao(null, false) == VisorModelo.Acao.NADA, "sem tela nao faz nada");
        // so nomes simples dentro da pasta do visor
        String[] ruins = {"../x.png", "a/b.png", "x.jpg", ".png", "-a.png", ".a.png", "A.png", "a..png", "a b.png", "", null,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png"};
        for (String r : ruins) {
            confere(!VisorModelo.nomeValido(r), "nome recusado: " + r);
            confere(VisorModelo.acao(r, false) == VisorModelo.Acao.NADA, "nome ruim nao mostra: " + r);
        }
        String[] bons = {"abertura-1793400000.png", "calibracao.png", "escada-1.png", "camera-12.png", "final.png"};
        for (String b : bons) confere(VisorModelo.nomeValido(b), "nome aceito: " + b);
        File d = Files.createTempDirectory("visor").toFile();
        confere(VisorModelo.arquivoDaTela(d, "resumo-1.png").equals(new File(new File(d, "visor"), "resumo-1.png")), "arquivo na pasta visor/");
        confere(VisorModelo.arquivoDaTela(d, "../x.png") == null, "arquivo fora da pasta recusado");
        // Voltar (4) e Esc/Sair (111) cancelam; OK, setas e Home nao
        confere(VisorModelo.cancela(4) && VisorModelo.cancela(111), "Voltar e Sair cancelam");
        confere(!VisorModelo.cancela(23) && !VisorModelo.cancela(66) && !VisorModelo.cancela(3) && !VisorModelo.cancela(19), "OK, Enter, Home e setas nao cancelam");
        // Voltar grava o pedido que a suite le
        File c = new File(d, "cancelar-suite");
        confere(!c.exists(), "sem pedido antes");
        confere(VisorModelo.gravarCancelar(d), "gravou");
        confere(c.isFile() && new String(Files.readAllBytes(c.toPath()), "US-ASCII").equals("1"), "pedido com '1'");
        confere(c.getName().equals(VisorModelo.CANCELAR) && VisorModelo.PASTA.equals("visor"), "nomes do canal");
        confere(!VisorModelo.gravarCancelar(new File(d, "nao-existe")), "pasta ausente = falha sem excecao");
        confere(!VisorModelo.gravarCancelar(null), "sem pasta = falha");
        c.delete();
        d.delete();
        System.out.println("visor-modelo: " + n + " verificacoes ok");
    }
}
