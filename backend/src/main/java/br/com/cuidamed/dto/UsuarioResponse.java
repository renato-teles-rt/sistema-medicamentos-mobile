package br.com.cuidamed.dto;

import br.com.cuidamed.domain.Usuario;

/**
 * Formato exato que o app espera em {@code UsuarioModel.fromJson}.
 * O app nao tolera campo obrigatorio ausente: {@code id}, {@code nome},
 * {@code email}, {@code tipoPerfil} e {@code codigoVinculo} sempre vao no JSON.
 */
public record UsuarioResponse(
        Long id,
        String nome,
        String email,
        String fotoUrl,
        String tipoPerfil,
        String codigoVinculo) {

    public static UsuarioResponse from(Usuario usuario) {
        return new UsuarioResponse(
                usuario.getId(),
                usuario.getNome(),
                usuario.getEmail(),
                usuario.getFotoUrl(),
                usuario.getTipoPerfil().name(),
                usuario.getCodigoVinculo());
    }
}
