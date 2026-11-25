import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/usuario_model.dart';
import '../models/vinculo_familiar_model.dart';
import 'session_service.dart';

class AuthVinculoService {
  static const String _googleClientId =
      String.fromEnvironment(
        'GOOGLE_CLIENT_ID',
        defaultValue:
            '889196260347-s3j3o28mi0atsb01tqdsj4v4m23hlcrj.apps.googleusercontent.com',
      );

  // Na web o client ID vem do <meta name="google-signin-client_id"> em
  // web/index.html; o plugin web rejeita a propriedade serverClientId.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: kIsWeb ? null : _googleClientId,
  );

  String _extrairMensagemErro(http.Response response, String fallback) {
    try {
      if (response.bodyBytes.isNotEmpty) {
        final dynamic decodificado = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodificado is Map<String, dynamic> && decodificado['erro'] != null) {
          return decodificado['erro'].toString();
        }
      }
    } catch (_) {
      // Ignora falha de parse caso o corpo não seja JSON válido
    }
    return fallback;
  }

  // Abre o seletor nativo com as contas Google já cadastradas no telefone
  Future<UsuarioModel?> entrarComContaGoogleNativa(String tipoPerfil) async {
    final GoogleSignInAccount? contaGoogle = await _googleSignIn.signIn();
    if (contaGoogle == null) {
      return null; // Usuário fechou a janela sem escolher
    }

    final GoogleSignInAuthentication auth = await contaGoogle.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null) {
      throw Exception(
        'Não foi possível obter o token de segurança da conta Google.',
      );
    }

    final response = await http.post(
      ApiConfig.auth('/google-token'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'idToken': idToken, 'tipoPerfil': tipoPerfil}),
    );

    if (response.statusCode == 200) {
      // Resposta pode vir vazia ou sem JSON (proxy, página de erro): nesse
      // caso mostramos mensagem amigável em vez de estourar FormatException.
      final dynamic dados = _corpoJson(response);
      if (dados is Map<String, dynamic>) {
        return UsuarioModel.fromJson(dados);
      }
      throw Exception('Resposta inesperada do servidor de autenticação.');
    }

    final dynamic erro = _corpoJson(response);
    final Object? mensagem = erro is Map<String, dynamic> ? erro['erro'] : null;
    throw Exception(mensagem ?? 'Falha ao autenticar no servidor.');
  }

  /// Decodifica o corpo como JSON sem lançar exceção quando o conteúdo não é
  /// JSON válido (ex.: HTML de erro de proxy). Retorna `null` nesses casos.
  dynamic _corpoJson(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Future<void> sairGoogle() async {
    await _googleSignIn.signOut();
  }

  Future<void> criarVinculoFamiliar(
    int cuidadorId,
    String codigoPaciente,
  ) async {
    final Map<String, String> headers = await SessionService.headersAutenticados();
    headers['X-Usuario-Id'] = cuidadorId.toString();

    final response = await http.post(
      ApiConfig.auth('/vincular'),
      headers: headers,
      body: jsonEncode({
        'cuidadorId': cuidadorId,
        'codigoVinculo': codigoPaciente.trim().toUpperCase(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extrairMensagemErro(response, 'Erro ao vincular perfil.'),
      );
    }
  }

  // RN01: Lista os cuidadores ativos de um paciente (máximo 2)
  Future<List<VinculoFamiliarModel>> listarCuidadoresDoPaciente(
    int pacienteId,
  ) async {
    final Map<String, String> headers = await SessionService.headersAutenticados(
      incluirJson: false,
    );

    final response = await http.get(
      ApiConfig.auth('/paciente/$pacienteId/cuidadores'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((item) => VinculoFamiliarModel.fromJson(item)).toList();
    } else {
      throw Exception(
        _extrairMensagemErro(
          response,
          'Não foi possível carregar os cuidadores vinculados.',
        ),
      );
    }
  }

  // Lista os pacientes ativos acompanhados por um cuidador
  Future<List<VinculoFamiliarModel>> listarPacientesDoCuidador(
    int cuidadorId,
  ) async {
    final Map<String, String> headers = await SessionService.headersAutenticados(
      incluirJson: false,
    );

    final response = await http.get(
      ApiConfig.auth('/cuidador/$cuidadorId/pacientes'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((item) => VinculoFamiliarModel.fromJson(item)).toList();
    } else {
      throw Exception(
        _extrairMensagemErro(
          response,
          'Não foi possível carregar os pacientes vinculados.',
        ),
      );
    }
  }

  // RN01: Desvincula um cuidador/paciente para liberar vaga
  Future<void> desvincularFamiliar(int vinculoId) async {
    final Map<String, String> headers = await SessionService.headersAutenticados(
      incluirJson: false,
    );

    final response = await http.delete(
      ApiConfig.auth('/vincular/$vinculoId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extrairMensagemErro(response, 'Erro ao encerrar vínculo.'),
      );
    }
  }
}