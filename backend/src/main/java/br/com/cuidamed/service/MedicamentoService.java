package br.com.cuidamed.service;

import br.com.cuidamed.domain.Medicamento;
import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.dto.MedicamentoRequest;
import br.com.cuidamed.dto.MedicamentoResponse;
import br.com.cuidamed.exception.NaoAutorizadoException;
import br.com.cuidamed.exception.NaoEncontradoException;
import br.com.cuidamed.exception.RegraNegocioException;
import br.com.cuidamed.repository.MedicamentoRepository;
import br.com.cuidamed.repository.UsuarioRepository;
import br.com.cuidamed.repository.VinculoFamiliarRepository;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Catalogo de medicamentos por paciente.
 *
 * <p>
 * <b>Autorizacao:</b> o paciente acessa o proprio catalogo; o cuidador
 * vinculado pode LER o catalogo do paciente. Escrita (criar/editar/repor/
 * remover) e exclusiva do paciente — o cuidador acompanha, nao prescreve.
 * </p>
 *
 * <p>
 * <b>RN05</b> — duplicidade: nome + dosagem iguais no mesmo catalogo sao
 * recusados, mesma comparacao case-insensitive do formulario do app.
 * </p>
 */
@Service
public class MedicamentoService {

    private final MedicamentoRepository medicamentoRepository;
    private final UsuarioRepository usuarioRepository;
    private final VinculoFamiliarRepository vinculoRepository;

    public MedicamentoService(
            MedicamentoRepository medicamentoRepository,
            UsuarioRepository usuarioRepository,
            VinculoFamiliarRepository vinculoRepository) {
        this.medicamentoRepository = medicamentoRepository;
        this.usuarioRepository = usuarioRepository;
        this.vinculoRepository = vinculoRepository;
    }

    @Transactional(readOnly = true)
    public List<MedicamentoResponse> listar(Long pacienteId, Long usuarioLogadoId) {
        exigirLeitura(pacienteId, usuarioLogadoId);
        return medicamentoRepository.findByPacienteIdOrderByNomeAsc(pacienteId)
                .stream()
                .map(MedicamentoResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public MedicamentoResponse buscar(Long pacienteId, String medicamentoId, Long usuarioLogadoId) {
        exigirLeitura(pacienteId, usuarioLogadoId);
        return MedicamentoResponse.from(exigirMedicamento(pacienteId, medicamentoId));
    }

    @Transactional
    public MedicamentoResponse criar(Long pacienteId, MedicamentoRequest request, Long usuarioLogadoId) {
        Usuario paciente = exigirEscrita(pacienteId, usuarioLogadoId);
        validarDuplicidade(pacienteId, request, null);

        String id = request.id() == null || request.id().isBlank()
                ? String.valueOf(System.currentTimeMillis())
                : request.id().trim();

        if (medicamentoRepository.findByChavePacienteIdAndChaveId(pacienteId, id).isPresent()) {
            throw new RegraNegocioException("Ja existe um medicamento com este id no catalogo.");
        }

        Medicamento medicamento = new Medicamento(
                id,
                paciente,
                request.nome().trim(),
                request.dosagem().trim(),
                request.horario(),
                request.quantidadePorDose(),
                CalculoEstoque.normalizar(request.quantidadeTotal()),
                request.diasAlerta() == null ? CalculoEstoque.DIAS_ALERTA_PADRAO : request.diasAlerta(),
                request.observacao() == null ? "" : request.observacao().trim());

        return MedicamentoResponse.from(medicamentoRepository.save(medicamento));
    }

    @Transactional
    public MedicamentoResponse atualizar(
            Long pacienteId, String medicamentoId, MedicamentoRequest request, Long usuarioLogadoId) {
        exigirEscrita(pacienteId, usuarioLogadoId);
        Medicamento medicamento = exigirMedicamento(pacienteId, medicamentoId);
        validarDuplicidade(pacienteId, request, medicamentoId);

        medicamento.setNome(request.nome().trim());
        medicamento.setDosagem(request.dosagem().trim());
        medicamento.setHorario(request.horario());
        medicamento.setQuantidadePorDose(request.quantidadePorDose());
        medicamento.setQuantidadeTotal(request.quantidadeTotal());
        if (request.diasAlerta() != null) {
            medicamento.setDiasAlerta(request.diasAlerta());
        }
        if (request.observacao() != null) {
            medicamento.setObservacao(request.observacao().trim());
        }

        return MedicamentoResponse.from(medicamentoRepository.save(medicamento));
    }

    /** Repor soma unidades ao estoque — nunca subtrai (RN de reposicao). */
    @Transactional
    public MedicamentoResponse repor(Long pacienteId, String medicamentoId, int quantidade, Long usuarioLogadoId) {
        exigirEscrita(pacienteId, usuarioLogadoId);
        if (quantidade <= 0) {
            throw new RegraNegocioException("Informe a quantidade recebida (maior que zero).");
        }
        Medicamento medicamento = exigirMedicamento(pacienteId, medicamentoId);
        medicamento.setQuantidadeTotal(medicamento.getQuantidadeTotal() + quantidade);
        return MedicamentoResponse.from(medicamentoRepository.save(medicamento));
    }

    /** Registra uma dose tomada. O estoque trava em zero, nunca fica negativo. */
    @Transactional
    public MedicamentoResponse registrarDose(Long pacienteId, String medicamentoId, Long usuarioLogadoId) {
        exigirEscrita(pacienteId, usuarioLogadoId);
        Medicamento medicamento = exigirMedicamento(pacienteId, medicamentoId);
        int restante = medicamento.getQuantidadeTotal() - medicamento.getQuantidadePorDose();
        medicamento.setQuantidadeTotal(Math.max(restante, 0));
        return MedicamentoResponse.from(medicamentoRepository.save(medicamento));
    }

    @Transactional
    public void remover(Long pacienteId, String medicamentoId, Long usuarioLogadoId) {
        exigirEscrita(pacienteId, usuarioLogadoId);
        Medicamento medicamento = exigirMedicamento(pacienteId, medicamentoId);
        medicamentoRepository.delete(medicamento);
    }

    // ------------------------------------------------------------------
    // Autorizacao
    // ------------------------------------------------------------------

    private void exigirLeitura(Long pacienteId, Long usuarioLogadoId) {
        Usuario logado = exigirUsuarioLogado(usuarioLogadoId);
        if (logado.getId().equals(pacienteId)) {
            return;
        }
        boolean cuidadorVinculado = vinculoRepository
                .existsByPacienteIdAndCuidadorIdAndAtivoTrue(pacienteId, logado.getId());
        if (!cuidadorVinculado) {
            throw new NaoAutorizadoException("Voce nao tem acesso ao catalogo deste paciente.");
        }
    }

    private Usuario exigirEscrita(Long pacienteId, Long usuarioLogadoId) {
        Usuario logado = exigirUsuarioLogado(usuarioLogadoId);
        if (!logado.getId().equals(pacienteId)) {
            throw new NaoAutorizadoException("Apenas o paciente pode alterar o proprio catalogo.");
        }
        return logado;
    }

    private Usuario exigirUsuarioLogado(Long usuarioLogadoId) {
        if (usuarioLogadoId == null) {
            throw new NaoAutorizadoException("Sessao ausente: faca login novamente.");
        }
        return usuarioRepository.findById(usuarioLogadoId)
                .orElseThrow(() -> new NaoAutorizadoException("Sessao invalida: faca login novamente."));
    }

    private Medicamento exigirMedicamento(Long pacienteId, String medicamentoId) {
        return medicamentoRepository.findByChavePacienteIdAndChaveId(pacienteId, medicamentoId)
                .orElseThrow(() -> new NaoEncontradoException("Medicamento nao encontrado neste catalogo."));
    }

    private void validarDuplicidade(Long pacienteId, MedicamentoRequest request, String idIgnorado) {
        String nome = request.nome().trim().toLowerCase(Locale.ROOT);
        String dosagem = request.dosagem().trim().toLowerCase(Locale.ROOT);

        boolean duplicado = medicamentoRepository.findByPacienteIdOrderByNomeAsc(pacienteId).stream()
                .anyMatch(m -> !m.getId().equals(idIgnorado)
                        && m.getNome().toLowerCase(Locale.ROOT).equals(nome)
                        && m.getDosagem().toLowerCase(Locale.ROOT).equals(dosagem));

        if (duplicado) {
            throw new RegraNegocioException("Este medicamento ja esta no catalogo.");
        }
    }
}
