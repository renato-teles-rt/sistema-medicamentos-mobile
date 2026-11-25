package br.com.cuidamed.domain;

/**
 * Faixas de criticidade do estoque. O enum do app e serializado pelo proprio
 * nome em miniatura ({@code normal}, {@code baixo}, {@code esgotado}), e o app
 * nao depende desse campo — ele recalcula tudo localmente.
 */
public enum StatusEstoque {
    NORMAL,
    BAIXO,
    ESGOTADO
}
