package br.com.cuidamed.exception;

/**
 * Erro de negocio/validacao que deve virar HTTP 400 com
 * {@code {"erro": "..."}}.
 */
public class RegraNegocioException extends RuntimeException {

    public RegraNegocioException(String mensagem) {
        super(mensagem);
    }
}
