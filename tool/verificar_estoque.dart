import 'package:cuidamed_mobile/models/medicamento_model.dart';

// ignore_for_file: avoid_print
void main() {
  void expect(bool condicao, String descricao) {
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
  expect(normal.statusEstoque == StatusEstoque.normal, '30 doses = normal');
  expect(normal.diasRestantes == 30, '30 dias restantes');
  expect(normal.descricaoDose == '1 unidade • 50mg', 'descricao da dose');

  final baixo = normal.copyWith(quantidadeTotal: 2);
  expect(baixo.statusEstoque == StatusEstoque.baixo, '2 doses = baixo');
  expect(baixo.estoqueBaixo, 'estoqueBaixo true');
  expect(baixo.mensagemStatus.contains('restam 2'), 'mensagem de alerta');

  final esgotado = normal.copyWith(quantidadeTotal: 0);
  expect(esgotado.statusEstoque == StatusEstoque.esgotado, '0 = esgotado');

  final porDose2 = MedicamentoModel(
    id: '2',
    nome: 'B12',
    dosagem: '1000mcg',
    horario: '12:00',
    quantidadePorDose: 2,
    quantidadeTotal: 6,
  );
  expect(porDose2.diasRestantes == 3, '6 un / 2 por dose = 3 dias');

  final json = MedicamentoModel.fromJson({
    'nome': 'Metformina',
    'dosagem': '850mg',
    'quantidadePorDose': '1',
    'quantidadeTotal': '15',
  });
  expect(json.nome == 'Metformina' && json.diasRestantes == 15, 'fromJson');
  expect(json.diasAlerta == MedicamentoModel.diasAlertaPadrao, 'alerta padrao');

  print('\nTodos os cenarios do teste passaram.');
}
