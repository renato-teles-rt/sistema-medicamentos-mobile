package br.com.cuidamed.domain;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MapsId;
import jakarta.persistence.Table;

/**
 * Medicamento do catalogo de um paciente.
 *
 * <p>
 * A chave primaria e composta: (paciente, id). O {@code id} textual e gerado
 * pelo app (timestamp) quando o item e criado offline, entao NAO e unico entre
 * pacientes — ver {@link MedicamentoId}.
 * </p>
 */
@Entity
@Table(name = "medicamentos")
public class Medicamento {

    @EmbeddedId
    private MedicamentoId chave;

    @MapsId("pacienteId")
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "paciente_id", nullable = false)
    private Usuario paciente;

    @Column(nullable = false, length = 120)
    private String nome;

    @Column(nullable = false, length = 60)
    private String dosagem;

    @Column(nullable = false, length = 5)
    private String horario;

    @Column(name = "quantidade_por_dose", nullable = false)
    private int quantidadePorDose;

    @Column(name = "quantidade_total", nullable = false)
    private int quantidadeTotal;

    @Column(name = "dias_alerta", nullable = false)
    private int diasAlerta;

    @Column(length = 500)
    private String observacao;

    protected Medicamento() {
        // exigido pelo JPA
    }

    public Medicamento(
            String id,
            Usuario paciente,
            String nome,
            String dosagem,
            String horario,
            int quantidadePorDose,
            int quantidadeTotal,
            int diasAlerta,
            String observacao) {
        this.chave = new MedicamentoId(paciente.getId(), id);
        this.paciente = paciente;
        this.nome = nome;
        this.dosagem = dosagem;
        this.horario = horario;
        this.quantidadePorDose = quantidadePorDose;
        this.quantidadeTotal = quantidadeTotal;
        this.diasAlerta = diasAlerta;
        this.observacao = observacao;
    }

    /**
     * Normaliza o estoque para o piso zero — mesma regra do app, que nunca
     * deixa o total negativo (RN02/RN04).
     */
    public static int normalizarQuantidade(int quantidade) {
        return Math.max(quantidade, 0);
    }

    public String getId() {
        return chave.getId();
    }

    public Usuario getPaciente() {
        return paciente;
    }

    public String getNome() {
        return nome;
    }

    public void setNome(String nome) {
        this.nome = nome;
    }

    public String getDosagem() {
        return dosagem;
    }

    public void setDosagem(String dosagem) {
        this.dosagem = dosagem;
    }

    public String getHorario() {
        return horario;
    }

    public void setHorario(String horario) {
        this.horario = horario;
    }

    public int getQuantidadePorDose() {
        return quantidadePorDose;
    }

    public void setQuantidadePorDose(int quantidadePorDose) {
        this.quantidadePorDose = quantidadePorDose;
    }

    public int getQuantidadeTotal() {
        return quantidadeTotal;
    }

    public void setQuantidadeTotal(int quantidadeTotal) {
        this.quantidadeTotal = normalizarQuantidade(quantidadeTotal);
    }

    public int getDiasAlerta() {
        return diasAlerta;
    }

    public void setDiasAlerta(int diasAlerta) {
        this.diasAlerta = diasAlerta;
    }

    public String getObservacao() {
        return observacao;
    }

    public void setObservacao(String observacao) {
        this.observacao = observacao;
    }
}
