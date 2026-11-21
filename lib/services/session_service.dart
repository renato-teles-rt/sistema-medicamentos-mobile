import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario_model.dart';
import 'auth_vinculo_service.dart';

class SessionService {
  static const String _chaveUsuario = 'cuidamed_usuario_sessao';

  static Future<void> salvarSessao(UsuarioModel usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final String usuarioJson = jsonEncode(usuario.toJson());
    await prefs.setString(_chaveUsuario, usuarioJson);
  }

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

  static Future<int?> obterUsuarioIdAtivo() async {
    final UsuarioModel? usuario = await obterSessaoAtiva();
    return usuario?.id;
  }

  static Future<Map<String, String>> headersAutenticados({
    bool incluirJson = true,
  }) async {
    final int? usuarioId = await obterUsuarioIdAtivo();
    final headers = <String, String>{};

    if (incluirJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }

    if (usuarioId != null) {
      headers['X-Usuario-Id'] = usuarioId.toString();
    }

    return headers;
  }

  static Future<void> encerrarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveUsuario);

    try {
      await AuthVinculoService().sairGoogle();
    } catch (_) {
      // Sessao local removida mesmo sem conexao
    }
  }
}