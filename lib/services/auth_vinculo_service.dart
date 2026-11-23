import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/usuario_model.dart';
import '../models/vinculo_familiar_model.dart';
import 'session_service.dart';

class AuthVinculoService {
  static const String _baseUrl = 'http://192.168.0.5:8080/api/auth';
  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.events';

  // Guarda o accessToken OAuth para o AgendamentoDoseService enviar em X-Google-Token
  static String? googleCalendarAccessToken;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', _calendarScope],
    serverClientId:
        '889196260347-s3j3o28mi0atsb01tqdsj4v4m23hlcrj.apps.googleusercontent.com',
  );

  String _extrairMensagemErro(http.Response response, String fallback) {
    try {
      if (response.bodyBytes.isNotEmpty) {
        final dynamic decodificado = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodificado is Map<String, dynamic> &&
            decodificado['erro'] != null) {
          return decodificado['erro'].toString();
        }
      }
    } catch (_) {}
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
    googleCalendarAccessToken = auth.accessToken;

    if (idToken == null) {
      throw Exception(
        'Não foi possível obter o token de segurança da conta Google.',
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/google-token'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'idToken': idToken, 'tipoPerfil': tipoPerfil}),
    );

    final String corpoTexto = utf8.decode(response.bodyBytes);
    dynamic dados;
    if (corpoTexto.isNotEmpty) {
      try {
        dados = jsonDecode(corpoTexto);
      } catch (_) {
        dados = null;
      }
    }

    if (response.statusCode == 200 && dados is Map<String, dynamic>) {
      return UsuarioModel.fromJson(dados);
    } else {
      final dynamic detalhe = dados is Map
          ? (dados['erro'] ?? dados['message'] ?? corpoTexto)
          : (corpoTexto.isNotEmpty ? corpoTexto : 'sem corpo na resposta');
      throw Exception('HTTP ${response.statusCode}: $detalhe');
    }
  }

  // Garante um accessToken atualizado com permissão da Google Agenda antes de salvar remédios
  static Future<String?> obterTokenGoogleAgenda() async {
    try {
      GoogleSignInAccount? conta =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (conta == null) {
        return googleCalendarAccessToken;
      }

      final bool autorizado =
          await _googleSignIn.requestScopes([_calendarScope]);
      if (!autorizado) {
        return googleCalendarAccessToken;
      }

      final GoogleSignInAuthentication auth = await conta.authentication;
      if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
        googleCalendarAccessToken = auth.accessToken;
      }
      return googleCalendarAccessToken;
    } catch (_) {
      return googleCalendarAccessToken;
    }
  }

  Future<void> sairGoogle() async {
    googleCalendarAccessToken = null;
    await _googleSignIn.signOut();
  }

  Future<void> criarVinculoFamiliar(
    int cuidadorId,
    String codigoPaciente,
  ) async {
    final Map<String, String> headers =
        await SessionService.headersAutenticados();
    headers['X-Usuario-Id'] = cuidadorId.toString();

    final response = await http.post(
      Uri.parse('$_baseUrl/vincular'),
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
    final Map<String, String> headers =
        await SessionService.headersAutenticados(incluirJson: false);

    final response = await http.get(
      Uri.parse('$_baseUrl/paciente/$pacienteId/cuidadores'),
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
    final Map<String, String> headers =
        await SessionService.headersAutenticados(incluirJson: false);

    final response = await http.get(
      Uri.parse('$_baseUrl/cuidador/$cuidadorId/pacientes'),
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
    final Map<String, String> headers =
        await SessionService.headersAutenticados(incluirJson: false);

    final response = await http.delete(
      Uri.parse('$_baseUrl/vincular/$vinculoId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        _extrairMensagemErro(response, 'Erro ao encerrar vínculo.'),
      );
    }
  }
}