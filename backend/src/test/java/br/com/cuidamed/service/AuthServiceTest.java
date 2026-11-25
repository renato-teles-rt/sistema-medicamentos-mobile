package br.com.cuidamed.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.cuidamed.dto.UsuarioResponse;
import br.com.cuidamed.exception.NaoAutorizadoException;
import br.com.cuidamed.repository.UsuarioRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * Login: contrato do {@code /google-token} e isolamento entre perfis.
 *
 * <p>
 * Regressao: no modo DEV todos os logins compartilhavam o mesmo e-mail e o
 * segundo usuario recebia 401 "ja cadastrada como outro perfil".
 * </p>
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class AuthServiceTest {

    @Autowired
    private AuthService authService;

    @Autowired
    private UsuarioRepository usuarioRepository;

    @Test
    @DisplayName("tokens diferentes criam usuarios diferentes (paciente e cuidador)")
    void tokensDiferentesUsuariosDiferentes() {
        UsuarioResponse paciente = authService.autenticar("token-paciente", "PACIENTE");
        UsuarioResponse cuidador = authService.autenticar("token-cuidador", "CUIDADOR");

        assertThat(paciente.id()).isNotEqualTo(cuidador.id());
        assertThat(paciente.tipoPerfil()).isEqualTo("PACIENTE");
        assertThat(cuidador.tipoPerfil()).isEqualTo("CUIDADOR");
        assertThat(paciente.email()).isNotEqualTo(cuidador.email());
    }

    @Test
    @DisplayName("o mesmo e-mail nao troca de perfil")
    void mesmoEmailNaoTrocaPerfil() {
        authService.autenticar("token-x", "PACIENTE");

        assertThatThrownBy(() -> authService.autenticar("token-x", "CUIDADOR"))
                .isInstanceOf(NaoAutorizadoException.class)
                .hasMessageContaining("PACIENTE");
    }

    @Test
    @DisplayName("login repetido reaproveita o usuario e mantem o codigo de vinculo")
    void loginReaproveitaUsuario() {
        String email = "token-repetido@cuidamed.local";
        UsuarioResponse primeiro = authService.autenticar("token-repetido", "PACIENTE");
        UsuarioResponse segundo = authService.autenticar("token-repetido", "PACIENTE");

        assertThat(segundo.id()).isEqualTo(primeiro.id());
        assertThat(segundo.codigoVinculo()).isEqualTo(primeiro.codigoVinculo());
        assertThat(usuarioRepository.count()).isEqualTo(1);
        assertThat(usuarioRepository.findByEmail(email)).isPresent();
    }

    @Test
    @DisplayName("perfil invalido e recusado com mensagem amigavel")
    void perfilInvalido() {
        assertThatThrownBy(() -> authService.autenticar("token-z", "ADMIN"))
                .hasMessageContaining("Tipo de perfil invalido");
    }

    @Test
    @DisplayName("codigo de vinculo tem 6 caracteres e e unico")
    void codigoDeVinculoUnico() {
        UsuarioResponse a = authService.autenticar("token-a", "PACIENTE");
        UsuarioResponse b = authService.autenticar("token-b", "PACIENTE");

        assertThat(a.codigoVinculo()).hasSize(6);
        assertThat(a.codigoVinculo()).isNotEqualTo(b.codigoVinculo());
        assertThat(a.codigoVinculo()).matches("[A-Z0-9]{6}");
    }
}
