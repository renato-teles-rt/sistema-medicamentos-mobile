package br.com.cuidamed.dto;

import jakarta.validation.constraints.Min;

/**
 * Body de {@code POST /api/medicamentos/paciente/{id}/{medicamentoId}/repor}.
 */
public record ReporEstoqueRequest(
                @Min(value = 1, message = "Informe a quantidade recebida (maior que zero).") int quantidade) {
}
