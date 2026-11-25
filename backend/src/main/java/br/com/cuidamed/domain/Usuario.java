package br.com.cuidamed.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

/**
 * Usuario autenticado. {@code codigoVinculo} e o codigo de 6 caracteres usado
 * pelo paciente para ser localizado por um cuidador.
 */
@Entity
@Table(name = "usuarios", uniqueConstraints = {
        @UniqueConstraint(name = "uk_usuario_email", columnNames = "email"),
        @UniqueConstraint(name = "uk_usuario_codigo", columnNames = "codigo_vinculo")
})
public class Usuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String nome;

    @Column(nullable = false, length = 180)
    private String email;

    @Column(name = "foto_url", length = 500)
    private String fotoUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_perfil", nullable = false, length = 20)
    private TipoPerfil tipoPerfil;

    @Column(name = "codigo_vinculo", nullable = false, length = 6)
    private String codigoVinculo;

    @Column(name = "google_sub", length = 120)
    private String googleSub;

    protected Usuario() {
        // exigido pelo JPA
    }

    public Usuario(String nome, String email, String fotoUrl, TipoPerfil tipoPerfil, String codigoVinculo) {
        this.nome = nome;
        this.email = email;
        this.fotoUrl = fotoUrl;
        this.tipoPerfil = tipoPerfil;
        this.codigoVinculo = codigoVinculo;
    }

    public Long getId() {
        return id;
    }

    public String getNome() {
        return nome;
    }

    public void setNome(String nome) {
        this.nome = nome;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getFotoUrl() {
        return fotoUrl;
    }

    public void setFotoUrl(String fotoUrl) {
        this.fotoUrl = fotoUrl;
    }

    public TipoPerfil getTipoPerfil() {
        return tipoPerfil;
    }

    public void setTipoPerfil(TipoPerfil tipoPerfil) {
        this.tipoPerfil = tipoPerfil;
    }

    public String getCodigoVinculo() {
        return codigoVinculo;
    }

    public void setCodigoVinculo(String codigoVinculo) {
        this.codigoVinculo = codigoVinculo;
    }

    public String getGoogleSub() {
        return googleSub;
    }

    public void setGoogleSub(String googleSub) {
        this.googleSub = googleSub;
    }
}
