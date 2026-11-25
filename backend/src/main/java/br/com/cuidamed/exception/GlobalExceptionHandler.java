package br.com.cuidamed.exception;

import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Converte toda excecao no contrato {@code {"erro": "mensagem amigavel"}}.
 *
 * <p>
 * O app (<code>_extrairMensagemErro</code>) exibe este campo direto ao
 * usuario, entao nenhuma excecao pode escapar como HTML de erro do Spring —
 * isso quebraria o RNF de "mensagem amigavel" e, no login, causaria
 * FormatException no cliente.
 * </p>
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(NaoEncontradoException.class)
    public ResponseEntity<ErroResponse> naoEncontrado(NaoEncontradoException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ErroResponse(e.getMessage()));
    }

    @ExceptionHandler(NaoAutorizadoException.class)
    public ResponseEntity<ErroResponse> naoAutorizado(NaoAutorizadoException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(new ErroResponse(e.getMessage()));
    }

    @ExceptionHandler(RegraNegocioException.class)
    public ResponseEntity<ErroResponse> regraNegocio(RegraNegocioException e) {
        return ResponseEntity.badRequest().body(new ErroResponse(e.getMessage()));
    }

    /** Erros de @Valid: junta as mensagens em uma frase legivel. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErroResponse> validacao(MethodArgumentNotValidException e) {
        String mensagem = e.getBindingResult().getFieldErrors().stream()
                .map(erro -> erro.getDefaultMessage())
                .distinct()
                .collect(Collectors.joining(" "));
        if (mensagem.isBlank()) {
            mensagem = "Dados invalidos na requisicao.";
        }
        return ResponseEntity.badRequest().body(new ErroResponse(mensagem));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErroResponse> corpoIlegivel(HttpMessageNotReadableException e) {
        return ResponseEntity.badRequest()
                .body(new ErroResponse("Corpo da requisicao invalido ou mal formatado."));
    }

    @ExceptionHandler(MissingRequestHeaderException.class)
    public ResponseEntity<ErroResponse> headerAusente(MissingRequestHeaderException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new ErroResponse("Sessao ausente: faca login novamente."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErroResponse> inesperado(Exception e) {
        // Nunca vaza stacktrace para o cliente: o app mostraria isso ao paciente.
        log.error("Erro inesperado no backend", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErroResponse("Erro interno no servidor. Tente novamente."));
    }
}
