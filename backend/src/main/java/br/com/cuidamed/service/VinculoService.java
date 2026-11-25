package br.com.cuidamed.service;

import br.com.cuidamed.domain.TipoPerfil;
import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.domain.VinculoFamiliar;
import br.com.cuidamed.dto.VinculoFamiliarResponse;
import br.com.cuidamed.exception.NaoAutorizadoException;
import br.com.cuidamed.exception.NaoEncontradoException;
import br.com.cuidamed.exception.RegraNegocioException;
import br.com.cuidamed.repository.UsuarioRepository;
import br.com.cuidamed.repository.VinculoFamiliarRepository;
import java.util.List;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Vinculo paciente ↔ cuidador.
 *
 * <p>
 * <b>RN01</b> — um paciente tem no maximo N cuidadores ativos
 * ({@code cuidamed.vinculo.max-cuidadores-por-paciente}, padrao 2). Esta
 * validacao vive AQUI, no servidor: no app ela era apenas cosmetico (texto e
 * contador), e um cliente adulterado conseguia o terceiro cuidador.
 * </p>
 *
 * <p>
 * <b>RN03</b> — o cuidador so pode vincular a si mesmo: o
 * {@code cuidadorId} do corpo precisa ser igual ao {@code X-Usuario-Id} do
 * header.
 * </p>
 */
@Service
public class VinculoService {

    private final VinculoFamiliarRepository vinculoRepository;
    private final UsuarioRepository usuarioRepository;
    private final int limiteCuidadores;

    public VinculoService(
            VinculoFamiliarRepository vinculoRepository,
            UsuarioRepository usuarioRepository,
            @Value("${cuidamed.vinculo.max-cuidadores-por-paciente:2}") int limiteCuidadores) {
        this.vinculoRepository = vinculoRepository;
        this.usuarioRepository = usuarioRepository;
        this.limiteCuidadores = limiteCuidadores;
    }

    @Transactional
    public void vincular(Long cuidadorIdCorpo, Long usuarioLogadoId, String codigoVinculo) {
        if (cuidadorIdCorpo == null) {
            throw new RegraNegocioException("Informe o cuidadorId.");
        }
        if (usuarioLogadoId != null && !cuidadorIdCorpo.equals(usuarioLogadoId)) {
            throw new NaoAutorizadoException("Voce so pode vincular a sua propria conta.");
        }
        if (codigoVinculo == null || codigoVinculo.isBlank()) {
            throw new RegraNegocioException("Informe o codigo de vinculo do paciente.");
        }

        Usuario cuidador = usuarioRepository.findById(cuidadorIdCorpo)
                .orElseThrow(() -> new NaoEncontradoException("Cuidador nao encontrado."));
        if (cuidador.getTipoPerfil() != TipoPerfil.CUIDADOR) {
            throw new RegraNegocioException("Apenas perfis de CUIDADOR podem vincular a um paciente.");
        }

        String codigo = codigoVinculo.trim().toUpperCase(Locale.ROOT);
        Usuario paciente = usuarioRepository.findByCodigoVinculo(codigo)
                .orElseThrow(() -> new RegraNegocioException("Codigo de vinculo invalido. Confira com o paciente."));

        if (paciente.getTipoPerfil() != TipoPerfil.PACIENTE) {
            throw new RegraNegocioException("O codigo informado nao pertence a um paciente.");
        }
        if (paciente.getId().equals(cuidador.getId())) {
            throw new RegraNegocioException("Nao e possivel vincular a propria conta.");
        }

        // Vinculo ja ativo: idempotente, nao conta como novo cuidador.
        if (vinculoRepository.existsByPacienteIdAndCuidadorIdAndAtivoTrue(paciente.getId(), cuidador.getId())) {
            throw new RegraNegocioException("Este paciente ja esta vinculado a voce.");
        }

        // RN01 — limite de cuidadores ativos por paciente.
        long ativos = vinculoRepository.countByPacienteIdAndAtivoTrue(paciente.getId());
        if (ativos >= limiteCuidadores) {
            throw new RegraNegocioException(
                    "Este paciente ja possui " + limiteCuidadores
                            + " cuidadores ativos. Peca a ele para desvincular alguem antes.");
        }

        // Se o cuidador ja teve este vinculo encerrado antes, reaproveita a linha
        // preservando o historico em vez de criar duplicata.
        VinculoFamiliar vinculo = vinculoRepository.findByPacienteAndCuidador(paciente, cuidador)
                .map(existente -> {
                    existente.reativar();
                    return existente;
                })
                .orElseGet(() -> new VinculoFamiliar(paciente, cuidador));

        vinculoRepository.save(vinculo);
    }

    @Transactional(readOnly = true)
    public List<VinculoFamiliarResponse> listarCuidadoresDoPaciente(Long pacienteId) {
        return vinculoRepository.findByPacienteIdAndAtivoTrueOrderByCriadoEmAsc(pacienteId)
                .stream()
                .map(VinculoFamiliarResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<VinculoFamiliarResponse> listarPacientesDoCuidador(Long cuidadorId) {
        return vinculoRepository.findByCuidadorIdAndAtivoTrueOrderByCriadoEmAsc(cuidadorId)
                .stream()
                .map(VinculoFamiliarResponse::from)
                .toList();
    }

    /**
     * Desvincula liberando a vaga de RN01. Paciente ou cuidador envolvido no
     * vinculo podem encerrar; qualquer outro usuario recebe 401.
     */
    @Transactional
    public void desvincular(Long vinculoId, Long usuarioLogadoId) {
        VinculoFamiliar vinculo = vinculoRepository.findById(vinculoId)
                .orElseThrow(() -> new NaoEncontradoException("Vinculo nao encontrado."));

        if (!vinculo.isAtivo()) {
            throw new RegraNegocioException("Este vinculo ja foi encerrado.");
        }

        boolean participante = usuarioLogadoId != null
                && (vinculo.getPaciente().getId().equals(usuarioLogadoId)
                        || vinculo.getCuidador().getId().equals(usuarioLogadoId));
        if (!participante) {
            throw new NaoAutorizadoException("Voce nao participa deste vinculo.");
        }

        vinculo.encerrar();
        vinculoRepository.save(vinculo);
    }

    public int getLimiteCuidadores() {
        return limiteCuidadores;
    }
}
