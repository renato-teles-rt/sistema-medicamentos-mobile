package br.com.cuidamed.domain;

/**
 * Perfis suportados pelo aplicativo. O app envia exatamente estes valores
 * em maiusculas no campo {@code tipoPerfil}.
 */
public enum TipoPerfil {
    PACIENTE,
    CUIDADOR;

    /**
     * Converte o texto recebido do app, aceitando diferencas de caixa e
     * espacos, e devolve {@code null} quando o valor nao e reconhecido.
     */
    public static TipoPerfil fromTexto(String texto) {
        if (texto == null) {
            return null;
        }
        try {
            return TipoPerfil.valueOf(texto.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
