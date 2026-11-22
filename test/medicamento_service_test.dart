import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:cuidamed_mobile/models/medicamento_model.dart';
import 'package:cuidamed_mobile/services/medicamento_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Simula o armazenamento do dispositivo sem precisar de Android/iOS.
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
  });

  test(
    'service persiste, ordena, repoe, remove e isola por paciente',
    () async {
      final service = MedicamentoService();
      const pacienteId = 9001;

      expect(await service.listar(pacienteId), isEmpty);

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

      var lista = await service.listar(pacienteId);
      expect(lista.length, 2);
      expect(lista.first.nome, 'AAS', reason: 'lista ordenada por nome');
      expect(
        lista.where((m) => m.estoqueBaixo).length,
        1,
        reason: 'somente AAS (2 un) em alerta',
      );

      await service.atualizar(
        pacienteId,
        lista.first.copyWith(quantidadeTotal: 40),
      );
      lista = await service.listar(pacienteId);
      expect(lista.firstWhere((m) => m.id == 'b').quantidadeTotal, 40);
      expect(
        lista.where((m) => m.estoqueBaixo),
        isEmpty,
        reason: 'alerta desliga apos reposicao',
      );

      await service.remover(pacienteId, 'a');
      lista = await service.listar(pacienteId);
      expect(lista.length, 1);
      expect(lista.first.id, 'b');

      expect(await service.listar(9002), isEmpty);
    },
  );

  test('persistencia cruza instancias do service (reinicio do app)', () async {
    await MedicamentoService().adicionar(
      9003,
      MedicamentoModel(
        id: 'x',
        nome: 'Metformina',
        dosagem: '850mg',
        horario: '07:00',
        quantidadeTotal: 10,
      ),
    );

    final aposReiniciar = await MedicamentoService().listar(9003);
    expect(aposReiniciar.single.nome, 'Metformina');
  });
}
