package br.com.cuidamed.dto;

import br.com.cuidamed.domain.VinculoFamiliar;

public record VinculoFamiliarResponse(
        Long id,
        UsuarioResponse paciente,
        UsuarioResponse cuidador,
        boolean ativo) {

    public static VinculoFamiliarResponse from(VinculoFamiliar vinculo) {
        return new VinculoFamiliarResponse(
                vinculo.getId(),
                UsuarioResponse.from(vinculo.getPaciente()),
                UsuarioResponse.from(vinculo.getCuidador()),
                vinculo.isAtivo());
    }
}
