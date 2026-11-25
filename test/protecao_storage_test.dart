import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:cuidamed_mobile/main.dart';
import 'package:cuidamed_mobile/services/medicamento_service.dart';
import 'package:cuidamed_mobile/services/session_service.dart';

/// Regressão do incidente de tela branca: um valor com tipo inesperado em
/// SharedPreferences derrubava o bootstrap do app antes do runApp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    SharedPreferences.resetStatic();
  });

  /// Deixa no storage o valor com o TIPO ERRADO (Map em vez de String) — é o
  /// cenário que o plugin web produz quando o JSON é serializado uma vez só.
  void envenenar(String chave, Object valor) {
    final Map<String, Object> dados = <String, Object>{chave: valor};
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.withData(dados);
    SharedPreferences.resetStatic();
  }

  test('sessão com tipo inesperado devolve null em vez de lançar', () async {
    envenenar('flutter.cuidamed_usuario_sessao', <String, Object>{'id': 1});

    expect(await SessionService.obterSessaoAtiva(), isNull);
  });

  test('sessão com JSON inválido é descartada', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuidamed_usuario_sessao', '{nao-e-json');
    SharedPreferences.resetStatic();

    expect(await SessionService.obterSessaoAtiva(), isNull);
  });

  test('sessão com JSON que não é objeto é descartada', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuidamed_usuario_sessao', '[1,2,3]');
    SharedPreferences.resetStatic();

    expect(await SessionService.obterSessaoAtiva(), isNull);
  });

  test('sessão sem id/email é descartada', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cuidamed_usuario_sessao',
      '{"id":0,"nome":"X","email":"","tipoPerfil":"PACIENTE","codigoVinculo":"AAA"}',
    );
    SharedPreferences.resetStatic();

    expect(await SessionService.obterSessaoAtiva(), isNull);
  });

  test('catálogo com tipo inesperado devolve lista vazia', () async {
    envenenar('flutter.cuidamed_medicamentos_7', <String, Object>{'id': 'x'});

    expect(await MedicamentoService().listar(7), isEmpty);
  });

  test('catálogo com JSON que não é lista devolve vazio', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cuidamed_medicamentos_8', '{"id":"x"}');
    SharedPreferences.resetStatic();

    expect(await MedicamentoService().listar(8), isEmpty);
  });

  testWidgets('app abre no login mesmo com sessão corrompida no storage', (
    tester,
  ) async {
    envenenar('flutter.cuidamed_usuario_sessao', <String, Object>{
      'nome': 'quebrado',
    });

    // Substitui o main(): o teste precisa do resultado do bootstrap.
    final sessao = await SessionService.obterSessaoAtiva();
    await tester.pumpWidget(CuidaMedApp(usuarioInicial: sessao));
    await tester.pumpAndSettle();

    expect(sessao, isNull);
    expect(find.text('CuidaMed 50+'), findsOneWidget);
    expect(find.text('Entrar com Conta Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
