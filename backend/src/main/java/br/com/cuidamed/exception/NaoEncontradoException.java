package br.com.cuidamed.exception;

/**
 * Recurso inexistente → HTTP 404.
 */
public class NaoEncontradoException extends RuntimeException {

    public NaoEncontradoException(String mensagem) {
        super(mensagem);
    }
}
