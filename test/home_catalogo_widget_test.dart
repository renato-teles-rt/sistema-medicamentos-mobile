import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:cuidamed_mobile/models/usuario_model.dart';
import 'package:cuidamed_mobile/views/home_paciente_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final usuario = UsuarioModel(
    id: 4242,
    nome: 'Dona Maria',
    email: 'maria@exemplo.com',
    tipoPerfil: 'PACIENTE',
    codigoVinculo: 'A9K2M4',
  );

  Future<void> abrirTela(WidgetTester tester) async {
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    // O SharedPreferences guarda um cache estatico entre testes; limpamos
    // para cada cenario começar do zero, como um app recém-instalado.
    SharedPreferences.resetStatic();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: HomePacienteView(usuario: usuario)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra estado vazio do catalogo', (tester) async {
    await abrirTela(tester);
    expect(find.text('Catálogo de Medicações'), findsOneWidget);
    expect(find.text('Nenhum medicamento cadastrado ainda.'), findsOneWidget);
    expect(find.text('Novo Remédio'), findsOneWidget);
  });

  testWidgets('cadastra pelo botao Novo Remedio e exibe alerta de estoque', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.tap(find.text('Novo Remédio'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar Medicamento'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Losartana');
    await tester.enterText(find.byType(TextField).at(1), '50mg');
    await tester.enterText(find.byType(TextField).at(3), '2');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Estoque baixo!'),
      findsOneWidget,
      reason: 'previa em tempo real avisa estoque baixo',
    );

    await tester.tap(find.text('Salvar Medicamento'));
    await tester.pumpAndSettle();

    expect(find.text('Losartana'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text(
        '1 medicamento está com o estoque baixo. Reponha antes de acabar.',
      ),
      findsOneWidget,
    );
    expect(find.text('ALERTA DE ESTOQUE'), findsOneWidget);
  });

  testWidgets('erro de validacao quando nome e dosagem ficam vazios', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.tap(find.text('Novo Remédio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar Medicamento'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do medicamento.'), findsOneWidget);
    expect(find.text('Informe a dosagem (ex: 50mg).'), findsOneWidget);
    expect(find.text('Losartana'), findsNothing);
  });
}
