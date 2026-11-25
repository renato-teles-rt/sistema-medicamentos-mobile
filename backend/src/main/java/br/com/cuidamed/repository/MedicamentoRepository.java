package br.com.cuidamed.repository;

import br.com.cuidamed.domain.Medicamento;
import br.com.cuidamed.domain.MedicamentoId;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MedicamentoRepository extends JpaRepository<Medicamento, MedicamentoId> {

    List<Medicamento> findByPacienteIdOrderByNomeAsc(Long pacienteId);

    Optional<Medicamento> findByChavePacienteIdAndChaveId(Long pacienteId, String id);

    void deleteByChavePacienteIdAndChaveId(Long pacienteId, String id);
}
