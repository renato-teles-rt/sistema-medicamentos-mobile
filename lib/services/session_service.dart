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

    // `prefs.getString` lança TypeError quando a chave guarda outro tipo (ex.:
    // um Map gravado por engano). Na web isso acontece antes de qualquer
    // try/catch de parse e derrubava o bootstrap com tela branca.
    final String? usuarioJson = _lerString(prefs, _chaveUsuario);

    if (usuarioJson == null || usuarioJson.isEmpty) {
      return null;
    }

    try {
      final dynamic decodificado = jsonDecode(usuarioJson);
      if (decodificado is! Map<String, dynamic>) {
        await prefs.remove(_chaveUsuario);
        return null;
      }
      final UsuarioModel usuario = UsuarioModel.fromJson(decodificado);
      // fromJson aceita campos ausentes como `null`; uma sessão sem id não
      // serve para autenticar nada, então é descartada.
      if (usuario.id <= 0 || usuario.email.isEmpty) {
        await prefs.remove(_chaveUsuario);
        return null;
      }
      return usuario;
    } catch (_) {
      await prefs.remove(_chaveUsuario);
      return null;
    }
  }

  /// Lê uma string do SharedPreferences sem lançar quando o tipo armazenado
  /// não é compatível. Devolve `null` e limpa a chave corrompida.
  static String? _lerString(SharedPreferences prefs, String chave) {
    try {
      final dynamic valor = prefs.get(chave);
      if (valor == null) return null;
      if (valor is String) return valor;
      // Tipo inesperado (Map/List/int): descarta para o app voltar ao login.
      prefs.remove(chave);
      return null;
    } catch (_) {
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