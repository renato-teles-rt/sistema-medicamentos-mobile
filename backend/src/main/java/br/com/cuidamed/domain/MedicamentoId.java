package br.com.cuidamed.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;

/**
 * Chave primaria composta de {@link Medicamento}: (paciente, id).
 *
 * <p>
 * O {@code id} sozinho NAO pode ser chave primaria. O app gera ids por
 * timestamp ({@code DateTime.now().millisecondsSinceEpoch}), e dois pacientes
 * podem gerar o mesmo valor. Com id como PK unica, o segundo paciente
 * sobrescrevia o registro do primeiro — perda de dados de saude, silenciosa.
 * </p>
 */
@Embeddable
public class MedicamentoId implements Serializable {

    @Column(name = "paciente_id", nullable = false)
    private Long pacienteId;

    @Column(name = "id", nullable = false, length = 64)
    private String id;

    protected MedicamentoId() {
        // exigido pelo JPA
    }

    public MedicamentoId(Long pacienteId, String id) {
        this.pacienteId = pacienteId;
        this.id = id;
    }

    public Long getPacienteId() {
        return pacienteId;
    }

    public String getId() {
        return id;
    }

    @Override
    public boolean equals(Object outro) {
        if (this == outro) {
            return true;
        }
        if (!(outro instanceof MedicamentoId that)) {
            return false;
        }
        return Objects.equals(pacienteId, that.pacienteId) && Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(pacienteId, id);
    }
}
