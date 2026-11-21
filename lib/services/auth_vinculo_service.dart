import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/usuario_model.dart';
import '../models/vinculo_familiar_model.dart';

class AuthVinculoService {
  static const String _baseUrl = 'http://192.168.0.5:8080/api/auth';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '889196260347-s3j3o28mi0atsb01tqdsj4v4m23hlcrj.apps.googleusercontent.com',
  );

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
      Uri.parse('$_baseUrl/google-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken, 'tipoPerfil': tipoPerfil}),
    );

    final dados = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return UsuarioModel.fromJson(dados);
    } else {
      throw Exception(dados['erro'] ?? 'Falha ao autenticar no servidor.');
    }
  }

  Future<void> sairGoogle() async {
    await _googleSignIn.signOut();
  }

  Future<void> criarVinculoFamiliar(
    int cuidadorId,
    String codigoPaciente,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/vincular'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cuidadorId': cuidadorId,
        'codigoVinculo': codigoPaciente.trim().toUpperCase(),
      }),
    );

    if (response.statusCode != 200) {
      final dados = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(dados['erro'] ?? 'Erro ao vincular perfil.');
    }
  }

  // RN01: Lista os cuidadores ativos de um paciente (máximo 2)
  Future<List<VinculoFamiliarModel>> listarCuidadoresDoPaciente(
    int pacienteId,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/paciente/$pacienteId/cuidadores'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((item) => VinculoFamiliarModel.fromJson(item)).toList();
    } else {
      throw Exception('Não foi possível carregar os cuidadores vinculados.');
    }
  }

  // Lista os pacientes ativos acompanhados por um cuidador
  Future<List<VinculoFamiliarModel>> listarPacientesDoCuidador(
    int cuidadorId,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/cuidador/$cuidadorId/pacientes'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
      return lista.map((item) => VinculoFamiliarModel.fromJson(item)).toList();
    } else {
      throw Exception('Não foi possível carregar os pacientes vinculados.');
    }
  }

  // RN01: Desvincula um cuidador/paciente para liberar vaga
  Future<void> desvincularFamiliar(int vinculoId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/vincular/$vinculoId'),
    );

    if (response.statusCode != 200) {
      final dados = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(dados['erro'] ?? 'Erro ao encerrar vínculo.');
    }
  }
}
