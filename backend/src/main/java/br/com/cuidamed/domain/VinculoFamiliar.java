package br.com.cuidamed.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDateTime;

/**
 * Vinculo paciente ↔ cuidador. Um vinculo encerrado permanece no banco com
 * {@code ativo = false} para preservar historico; apenas os ativos contam na
 * regra RN01 (maximo de cuidadores por paciente).
 */
@Entity
@Table(name = "vinculos_familiares")
public class VinculoFamiliar {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "paciente_id", nullable = false)
    private Usuario paciente;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "cuidador_id", nullable = false)
    private Usuario cuidador;

    @Column(nullable = false)
    private boolean ativo;

    @Column(name = "criado_em", nullable = false)
    private LocalDateTime criadoEm;

    @Column(name = "encerrado_em")
    private LocalDateTime encerradoEm;

    protected VinculoFamiliar() {
        // exigido pelo JPA
    }

    public VinculoFamiliar(Usuario paciente, Usuario cuidador) {
        this.paciente = paciente;
        this.cuidador = cuidador;
        this.ativo = true;
        this.criadoEm = LocalDateTime.now();
    }

    public void encerrar() {
        this.ativo = false;
        this.encerradoEm = LocalDateTime.now();
    }

    public void reativar() {
        this.ativo = true;
        this.encerradoEm = null;
        this.criadoEm = LocalDateTime.now();
    }

    public Long getId() {
        return id;
    }

    public Usuario getPaciente() {
        return paciente;
    }

    public Usuario getCuidador() {
        return cuidador;
    }

    public boolean isAtivo() {
        return ativo;
    }

    public LocalDateTime getCriadoEm() {
        return criadoEm;
    }

    public LocalDateTime getEncerradoEm() {
        return encerradoEm;
    }
}
