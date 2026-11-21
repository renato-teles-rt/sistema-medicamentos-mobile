import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario_model.dart';
import 'auth_vinculo_service.dart';

class SessionService {
  static const String _chaveUsuario = 'cuidamed_usuario_sessao';

  /// Salva a sessão do usuário localmente após o login (RN02)
  static Future<void> salvarSessao(UsuarioModel usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final String usuarioJson = jsonEncode(usuario.toJson());
    await prefs.setString(_chaveUsuario, usuarioJson);
  }

  /// Recupera o usuário logado ao abrir o aplicativo (RN02)
  static Future<UsuarioModel?> obterSessaoAtiva() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usuarioJson = prefs.getString(_chaveUsuario);

    if (usuarioJson == null || usuarioJson.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> mapa = jsonDecode(usuarioJson);
      return UsuarioModel.fromJson(mapa);
    } catch (_) {
      await prefs.remove(_chaveUsuario);
      return null;
    }
  }

  /// Encerra a sessão apenas mediante ação explícita de "Sair" (RN02)
  static Future<void> encerrarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveUsuario);

    try {
      await AuthVinculoService().sairGoogle();
    } catch (_) {
      // Garante que a sessão local seja limpa mesmo sem internet no momento
    }
  }
}
