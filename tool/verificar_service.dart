import 'package:cuidamed_mobile/models/medicamento_model.dart';
import 'package:cuidamed_mobile/services/medicamento_service.dart';

// ignore_for_file: avoid_print
Future<void> main() async {
  void expect(bool condicao, String descricao) {
    if (!condicao) throw StateError('FALHOU: $descricao');
    print('ok - $descricao');
  }

  final service = MedicamentoService();
  const pacienteId = 9001;

  // Estado inicial limpo
  var lista = await service.listar(pacienteId);
  expect(lista.isEmpty, 'catálogo começa vazio');

  await service.adicionar(
    pacienteId,
    MedicamentoModel(
      id: 'a',
      nome: 'Losartana',
      dosagem: '50mg',
      horario: '08:00',
      quantidadeTotal: 30,
    ),
  );
  await service.adicionar(
    pacienteId,
    MedicamentoModel(
      id: 'b',
      nome: 'AAS',
      dosagem: '100mg',
      horario: '12:00',
      quantidadeTotal: 2,
    ),
  );

  lista = await service.listar(pacienteId);
  expect(lista.length == 2, 'adicionar persiste 2 itens');
  expect(lista.first.nome == 'AAS', 'lista fica ordenada por nome');
  expect(
    lista.where((m) => m.estoqueBaixo).length == 1,
    'somente AAS (2 un) está em alerta',
  );

  await service.atualizar(
    pacienteId,
    lista.first.copyWith(quantidadeTotal: 40),
  );
  lista = await service.listar(pacienteId);
  final aas = lista.firstWhere((m) => m.id == 'b');
  expect(aas.quantidadeTotal == 40, 'reposição grava no estoque');
  expect(
    lista.where((m) => m.estoqueBaixo).length == 0,
    'alerta desliga após reposição',
  );

  await service.remover(pacienteId, 'a');
  lista = await service.listar(pacienteId);
  expect(lista.length == 1 && lista.first.id == 'b', 'remover exclui o item');

  // Isolamento por paciente
  final outro = await service.listar(9002);
  expect(outro.isEmpty, 'catálogo é separado por paciente');

  print('\nTodos os cenarios do medicamento_service passaram.');
}
