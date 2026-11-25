package br.com.cuidamed.exception;

/**
 * Payload de erro no formato que o app exige: {@code { "erro": "mensagem" }}.
 * O {@code AuthVinculoService._extrairMensagemErro} le exatamente este campo.
 */
public record ErroResponse(String erro) {
}
