package br.com.cuidamed.service;

import br.com.cuidamed.domain.TipoPerfil;
import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.dto.UsuarioResponse;
import br.com.cuidamed.exception.NaoAutorizadoException;
import br.com.cuidamed.exception.RegraNegocioException;
import br.com.cuidamed.repository.UsuarioRepository;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Login: valida o ID token do Google e cria/atualiza o usuario.
 *
 * <p>
 * O {@code tipoPerfil} vem escolhido na tela de login. Se o mesmo e-mail ja
 * existe com outro perfil, a troca e recusada — permitir trocar de paciente
 * para cuidador com a mesma conta faria o paciente perder o vinculo e o
 * catalogo associado ao id.
 * </p>
 */
@Service
public class AuthService {

    private final GoogleTokenVerifier tokenVerifier;
    private final UsuarioRepository usuarioRepository;
    private final CodigoVinculoGenerator codigoGenerator;

    public AuthService(
            GoogleTokenVerifier tokenVerifier,
            UsuarioRepository usuarioRepository,
            CodigoVinculoGenerator codigoGenerator) {
        this.tokenVerifier = tokenVerifier;
        this.usuarioRepository = usuarioRepository;
        this.codigoGenerator = codigoGenerator;
    }

    @Transactional
    public UsuarioResponse autenticar(String idToken, String tipoPerfilTexto) {
        TipoPerfil perfil = TipoPerfil.fromTexto(tipoPerfilTexto);
        if (perfil == null) {
            throw new RegraNegocioException("Tipo de perfil invalido. Use PACIENTE ou CUIDADOR.");
        }

        GoogleTokenVerifier.DadosGoogle dados = tokenVerifier.verificar(idToken);

        String email = dados.email().trim().toLowerCase(Locale.ROOT);
        Usuario usuario = usuarioRepository.findByEmail(email).orElseGet(() -> novoUsuario(dados, email, perfil));

        if (!usuario.getTipoPerfil().equals(perfil)) {
            throw new NaoAutorizadoException(
                    "Esta conta ja esta cadastrada como " + usuario.getTipoPerfil().name()
                            + ". Entre com o perfil correto.");
        }

        // Mantem nome/foto atualizados com o Google a cada login.
        usuario.setNome(dados.nome() == null ? usuario.getNome() : dados.nome());
        usuario.setFotoUrl(dados.fotoUrl());
        if (dados.sub() != null) {
            usuario.setGoogleSub(dados.sub());
        }

        return UsuarioResponse.from(usuarioRepository.save(usuario));
    }

    private Usuario novoUsuario(GoogleTokenVerifier.DadosGoogle dados, String email, TipoPerfil perfil) {
        Usuario usuario = new Usuario(
                dados.nome() == null ? email : dados.nome(),
                email,
                dados.fotoUrl(),
                perfil,
                codigoGenerator.gerar());
        usuario.setGoogleSub(dados.sub());
        return usuario;
    }
}
