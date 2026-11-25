package br.com.cuidamed.service;

import br.com.cuidamed.domain.StatusEstoque;

/**
 * Regras de estoque — espelho de {@code lib/models/medicamento_model.dart}.
 *
 * <p>
 * Manter a MESMA implementacao nos dois lados e intencional: o app calcula
 * tudo offline e o backend so precisa responder o que o app espera. Se a regra
 * mudar, os dois arquivos mudam juntos (e os testes dos dois lados acusam).
 * </p>
 */
public final class CalculoEstoque {

    public static final int DIAS_ALERTA_PADRAO = 3;

    private CalculoEstoque() {
    }

    /**
     * Dias completos de tratamento ate o estoque acabar. Nunca negativo:
     * estoque zerado (ou menor que uma dose) vale 0 dias.
     */
    public static int diasRestantes(int quantidadeTotal, int quantidadePorDose) {
        if (quantidadePorDose <= 0 || quantidadeTotal <= 0) {
            return 0;
        }
        return quantidadeTotal / quantidadePorDose;
    }

    /**
     * Faixa de criticidade seguindo a precedencia do app:
     * esgotado (total <= 0) antes de baixo (dias <= diasAlerta).
     */
    public static StatusEstoque status(int quantidadeTotal, int quantidadePorDose, int diasAlerta) {
        if (quantidadeTotal <= 0) {
            return StatusEstoque.ESGOTADO;
        }
        if (diasRestantes(quantidadeTotal, quantidadePorDose) <= diasAlerta) {
            return StatusEstoque.BAIXO;
        }
        return StatusEstoque.NORMAL;
    }

    /** piso zero, para qualquer escrita no banco. */
    public static int normalizar(int quantidade) {
        return Math.max(quantidade, 0);
    }
}
