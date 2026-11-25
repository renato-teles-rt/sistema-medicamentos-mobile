package br.com.cuidamed.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;

/**
 * Body de criacao/atualizacao de medicamento ({@code POST}/{@code PUT}).
 *
 * <p>
 * Os limites espelham a validacao do formulario do app
 * ({@code _FormularioMedicamento._salvar}): nome e dosagem obrigatorios,
 * dose maior que zero, estoque nunca negativo. O backend nao confia apenas na
 * validacao do cliente (RN04).
 * </p>
 */
public record MedicamentoRequest(
                String id,
                @NotBlank(message = "Informe o nome do medicamento.") String nome,
                @NotBlank(message = "Informe a dosagem (ex: 50mg).") String dosagem,
                @NotBlank(message = "Informe o horario da dose.") @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$", message = "Horario deve estar no formato HH:mm.") String horario,
                @NotNull(message = "Informe a quantidade usada por dose.") @Positive(message = "Uso por dose deve ser maior que zero.") Integer quantidadePorDose,
                @NotNull(message = "Informe a quantidade total em estoque.") Integer quantidadeTotal,
                Integer diasAlerta,
                String observacao) {
}
