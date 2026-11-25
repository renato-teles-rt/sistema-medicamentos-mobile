package br.com.cuidamed.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.cuidamed.domain.TipoPerfil;
import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.exception.RegraNegocioException;
import br.com.cuidamed.repository.UsuarioRepository;
import br.com.cuidamed.repository.VinculoFamiliarRepository;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * RN01 — limite de cuidadores ativos por paciente, validado no servidor.
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class VinculoServiceTest {

    @Autowired
    private VinculoService vinculoService;

    @Autowired
    private UsuarioRepository usuarioRepository;

    @Autowired
    private VinculoFamiliarRepository vinculoRepository;

    @Autowired
    private CodigoVinculoGenerator codigoGenerator;

    private Usuario paciente;
    private final List<Usuario> cuidadores = new ArrayList<>();

    @BeforeEach
    void preparar() {
        paciente = usuarioRepository.save(
                new Usuario("Dona Maria", "maria@teste.com", null, TipoPerfil.PACIENTE, codigoGenerator.gerar()));

        cuidadores.clear();
        for (int i = 0; i < 3; i++) {
            cuidadores.add(usuarioRepository.save(new Usuario(
                    "Cuidador " + i,
                    "cuidador" + i + "@teste.com",
                    null,
                    TipoPerfil.CUIDADOR,
                    codigoGenerator.gerar())));
        }
    }

    @Test
    @DisplayName("aceita ate 2 cuidadores ativos e recusa o terceiro")
    void limiteDeDoisCuidadores() {
        vinculoService.vincular(cuidadores.get(0).getId(), cuidadores.get(0).getId(), paciente.getCodigoVinculo());
        vinculoService.vincular(cuidadores.get(1).getId(), cuidadores.get(1).getId(), paciente.getCodigoVinculo());

        assertThat(vinculoRepository.countByPacienteIdAndAtivoTrue(paciente.getId())).isEqualTo(2);

        assertThatThrownBy(() -> vinculoService.vincular(
                cuidadores.get(2).getId(), cuidadores.get(2).getId(), paciente.getCodigoVinculo()))
                .isInstanceOf(RegraNegocioException.class)
                .hasMessageContaining("2 cuidadores ativos");

        assertThat(vinculoRepository.countByPacienteIdAndAtivoTrue(paciente.getId())).isEqualTo(2);
    }

    @Test
    @DisplayName("desvincular libera a vaga para um novo cuidador")
    void desvincularLiberaVaga() {
        vinculoService.vincular(cuidadores.get(0).getId(), cuidadores.get(0).getId(), paciente.getCodigoVinculo());
        vinculoService.vincular(cuidadores.get(1).getId(), cuidadores.get(1).getId(), paciente.getCodigoVinculo());

        Long vinculoDoPrimeiro = vinculoService.listarCuidadoresDoPaciente(paciente.getId()).get(0).id();
        vinculoService.desvincular(vinculoDoPrimeiro, paciente.getId());

        assertThat(vinculoRepository.countByPacienteIdAndAtivoTrue(paciente.getId())).isEqualTo(1);

        vinculoService.vincular(cuidadores.get(2).getId(), cuidadores.get(2).getId(), paciente.getCodigoVinculo());
        assertThat(vinculoRepository.countByPacienteIdAndAtivoTrue(paciente.getId())).isEqualTo(2);
    }

    @Test
    @DisplayName("codigo inexistente e recusado com mensagem amigavel")
    void codigoInvalido() {
        assertThatThrownBy(() -> vinculoService.vincular(
                cuidadores.get(0).getId(), cuidadores.get(0).getId(), "ZZZZZZ"))
                .isInstanceOf(RegraNegocioException.class)
                .hasMessageContaining("Codigo de vinculo invalido");
    }

    @Test
    @DisplayName("nao permite vincular em nome de outro cuidador")
    void naoPodeVincularOutro() {
        assertThatThrownBy(() -> vinculoService.vincular(
                cuidadores.get(0).getId(), cuidadores.get(1).getId(), paciente.getCodigoVinculo()))
                .hasMessageContaining("sua propria conta");
    }

    @Test
    @DisplayName("paciente nao pode vincular cuidador como se fosse ele")
    void perfilInvalidoParaVincular() {
        assertThatThrownBy(() -> vinculoService.vincular(
                paciente.getId(), paciente.getId(), paciente.getCodigoVinculo()))
                .isInstanceOf(RegraNegocioException.class)
                .hasMessageContaining("CUIDADOR");
    }
}
