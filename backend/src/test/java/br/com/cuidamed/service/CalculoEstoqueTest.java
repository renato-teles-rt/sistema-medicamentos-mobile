package br.com.cuidamed.service;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.cuidamed.domain.StatusEstoque;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Estes testes espelham {@code test/verificar_estoque_test.dart}. Se a regra
 * divergir entre app e backend, um dos dois suites falha.
 */
class CalculoEstoqueTest {

    @Test
    @DisplayName("30 unidades com 1 por dose = 30 dias, estoque normal")
    void trintaUnidadesNormal() {
        assertThat(CalculoEstoque.diasRestantes(30, 1)).isEqualTo(30);
        assertThat(CalculoEstoque.status(30, 1, 3)).isEqualTo(StatusEstoque.NORMAL);
    }

    @Test
    @DisplayName("2 unidades entram na faixa de alerta (3 dias)")
    void duasUnidadesBaixo() {
        assertThat(CalculoEstoque.status(2, 1, 3)).isEqualTo(StatusEstoque.BAIXO);
        assertThat(CalculoEstoque.diasRestantes(2, 1)).isEqualTo(2);
    }

    @Test
    @DisplayName("estoque zero e esgotado, nao baixo")
    void zeroEsgotado() {
        assertThat(CalculoEstoque.status(0, 1, 3)).isEqualTo(StatusEstoque.ESGOTADO);
    }

    @Test
    @DisplayName("6 unidades com 2 por dose = 3 dias")
    void seisUnidadesDuasPorDose() {
        assertThat(CalculoEstoque.diasRestantes(6, 2)).isEqualTo(3);
    }

    @Test
    @DisplayName("estoque menor que uma dose = 0 dias e nunca negativo")
    void estoqueMenorQueDose() {
        assertThat(CalculoEstoque.diasRestantes(1, 3)).isZero();
        assertThat(CalculoEstoque.diasRestantes(-5, 1)).isZero();
        assertThat(CalculoEstoque.diasRestantes(10, 0)).isZero();
    }

    @Test
    @DisplayName("piso zero para qualquer quantidade gravada")
    void normalizarNuncaNegativo() {
        assertThat(CalculoEstoque.normalizar(-5)).isZero();
        assertThat(CalculoEstoque.normalizar(0)).isZero();
        assertThat(CalculoEstoque.normalizar(7)).isEqualTo(7);
    }
}
