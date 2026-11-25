import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Configuração de rede centralizada.
///
/// A URL base pode ser trocada SEM editar código:
///
/// ```powershell
/// flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.0.5:8080
/// ```
///
/// Sem `--dart-define`, usa-se um padrão por plataforma:
/// - **Web**: `localhost` — o navegador e o backend rodam na mesma máquina.
/// - **Android**: `10.0.2.2` aponta para o host visto de dentro do emulador.
/// - **Outros (celular físico)**: a URL precisa ser informada via
///   `--dart-define`, porque o aparelho não conhece o IP do PC.
class ApiConfig {
  static const String _baseDefinida = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseDefinida.isNotEmpty) {
      // Remove barra final para evitar "//api" nas concatenações.
      return _baseDefinida.endsWith('/')
          ? _baseDefinida.substring(0, _baseDefinida.length - 1)
          : _baseDefinida;
    }

    if (kIsWeb) return 'http://localhost:8080';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      default:
        return 'http://localhost:8080';
    }
  }

  static Uri auth(String caminho) => Uri.parse('$baseUrl/api/auth$caminho');

  static Uri medicamentos(String caminho) =>
      Uri.parse('$baseUrl/api/medicamentos$caminho');
}
