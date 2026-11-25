package br.com.cuidamed.exception;

/**
 * Falha de autenticacao/autorizacao → HTTP 401 ou 403.
 */
public class NaoAutorizadoException extends RuntimeException {

    public NaoAutorizadoException(String mensagem) {
        super(mensagem);
    }
}
