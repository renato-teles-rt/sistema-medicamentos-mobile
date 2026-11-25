package br.com.cuidamed.dto;

import jakarta.validation.constraints.NotBlank;

public record GoogleTokenRequest(
                @NotBlank(message = "idToken e obrigatorio") String idToken,
                @NotBlank(message = "tipoPerfil e obrigatorio") String tipoPerfil) {
}
