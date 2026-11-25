package br.com.cuidamed.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Body de {@code POST /api/auth/vincular}. O {@code cuidadorId} vai no corpo
 * (o app envia) e tambem pode vir no header {@code X-Usuario-Id}; quando os
 * dois existem precisam coincidir, senao o vinculo e recusado (RN03).
 */
public record VincularRequest(Long cuidadorId,
        @NotBlank(message = "codigoVinculo e obrigatorio") String codigoVinculo) {
}
