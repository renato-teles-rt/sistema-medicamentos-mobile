package br.com.cuidamed.repository;

import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.domain.VinculoFamiliar;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VinculoFamiliarRepository extends JpaRepository<VinculoFamiliar, Long> {

    List<VinculoFamiliar> findByPacienteIdAndAtivoTrueOrderByCriadoEmAsc(Long pacienteId);

    List<VinculoFamiliar> findByCuidadorIdAndAtivoTrueOrderByCriadoEmAsc(Long cuidadorId);

    Optional<VinculoFamiliar> findByPacienteAndCuidador(Usuario paciente, Usuario cuidador);

    long countByPacienteIdAndAtivoTrue(Long pacienteId);

    boolean existsByPacienteIdAndCuidadorIdAndAtivoTrue(Long pacienteId, Long cuidadorId);

    boolean existsByPacienteIdAndCuidadorId(Long pacienteId, Long cuidadorId);
}
