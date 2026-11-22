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

    print('\nTodos os cenarios do teste passaram.');
  });
}
