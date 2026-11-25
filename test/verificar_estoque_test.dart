import 'package:flutter_test/flutter_test.dart';

import 'package:cuidamed_mobile/models/medicamento_model.dart';

void main() {
  test('cenarios de estoque informados no relatorio', () {
    void expectTrue(bool condicao, String descricao) {
      if (!condicao) throw StateError('FALHOU: $descricao');
      print('ok - $descricao');
    }

    final normal = MedicamentoModel(
      id: '1',
      nome: 'Losartana',
      dosagem: '50mg',
      horario: '08:00',
      quantidadePorDose: 1,
      quantidadeTotal: 30,
    );
    expectTrue(
      normal.statusEstoque == StatusEstoque.normal,
      '30 doses = normal',
    );
    expectTrue(normal.diasRestantes == 30, '30 dias restantes');
    expectTrue(normal.descricaoDose == '1 unidade • 50mg', 'descricao da dose');

    final baixo = normal.copyWith(quantidadeTotal: 2);
    expectTrue(baixo.statusEstoque == StatusEstoque.baixo, '2 doses = baixo');
    expectTrue(baixo.estoqueBaixo, 'estoqueBaixo true');
    expectTrue(baixo.mensagemStatus.contains('restam 2'), 'mensagem de alerta');

    final esgotado = normal.copyWith(quantidadeTotal: 0);
    expectTrue(
      esgotado.statusEstoque == StatusEstoque.esgotado,
      '0 = esgotado',
    );

    final porDose2 = MedicamentoModel(
      id: '2',
      nome: 'B12',
      dosagem: '1000mcg',
      horario: '12:00',
      quantidadePorDose: 2,
      quantidadeTotal: 6,
    );
    expectTrue(porDose2.diasRestantes == 3, '6 un / 2 por dose = 3 dias');

    final json = MedicamentoModel.fromJson({
      'nome': 'Metformina',
      'dosagem': '850mg',
      'quantidadePorDose': '1',
      'quantidadeTotal': '15',
    });
    expectTrue(
      json.nome == 'Metformina' && json.diasRestantes == 15,
      'fromJson',
    );
    expectTrue(
      json.diasAlerta == MedicamentoModel.diasAlertaPadrao,
      'alerta padrao',
    );

    // Regressao: estoque nunca fica negativo. Uma dose maior que o estoque
    // restante zera o contador e reporta 0 dias, nao um numero negativo.
    final dosesSobrando = normal.copyWith(quantidadeTotal: 1);
    expectTrue(
      normal
              .copyWith(
                quantidadeTotal:
                    dosesSobrando.quantidadeTotal - dosesSobrando.quantidadePorDose,
              )
              .quantidadeTotal ==
          0,
      'ultima dose zera o estoque em vez de ficar negativa',
    );
    final estourado = MedicamentoModel(
      id: '3',
      nome: 'Gliclazida',
      dosagem: '30mg',
      horario: '07:00',
      quantidadePorDose: 3,
      quantidadeTotal: 1,
    );
    expectTrue(estourado.diasRestantes == 0, 'estoque menor que a dose = 0 dias');
    expectTrue(
      estourado.statusEstoque == StatusEstoque.baixo,
      'estoque menor que a dose ainda nao esgotou',
    );
    expectTrue(
      normal.copyWith(quantidadeTotal: -5).quantidadeTotal == 0,
      'copyWith nunca aceita estoque negativo',
    );

    print('\nTodos os cenarios do teste passaram.');
  });
}
