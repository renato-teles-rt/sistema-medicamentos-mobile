package br.com.cuidamed.dto;

import br.com.cuidamed.domain.Medicamento;
import br.com.cuidamed.domain.StatusEstoque;
import br.com.cuidamed.service.CalculoEstoque;

/**
 * Formato exato que {@code MedicamentoModel.fromJson} consome.
 *
 * <p>
 * Os campos extras ({@code diasRestantes}, {@code statusEstoque}) sao
 * informativos: o app ignora propriedades desconhecidas no fromJson e recalcula
 * localmente. Servem para outros clientes (relatorios, web admin) que nao
 * queiram repetir a regra.
 * </p>
 */
public record MedicamentoResponse(
                String id,
                String nome,
                String dosagem,
                String horario,
                int quantidadePorDose,
                int quantidadeTotal,
                int diasAlerta,
                String observacao,
                int diasRestantes,
                StatusEstoque statusEstoque) {

        public static MedicamentoResponse from(Medicamento medicamento) {
                int dias = CalculoEstoque.diasRestantes(
                                medicamento.getQuantidadeTotal(), medicamento.getQuantidadePorDose());
                StatusEstoque status = CalculoEstoque.status(
                                medicamento.getQuantidadeTotal(),
                                medicamento.getQuantidadePorDose(),
                                medicamento.getDiasAlerta());

                return new MedicamentoResponse(
                                medicamento.getId(),
                                medicamento.getNome(),
                                medicamento.getDosagem(),
                                medicamento.getHorario(),
                                medicamento.getQuantidadePorDose(),
                                medicamento.getQuantidadeTotal(),
                                medicamento.getDiasAlerta(),
                                medicamento.getObservacao() == null ? "" : medicamento.getObservacao(),
                                dias,
                                status);
        }
}
