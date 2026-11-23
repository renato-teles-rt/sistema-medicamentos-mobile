import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_vinculo_service.dart';
import 'session_service.dart';

class AgendamentoModel {
  final int? id;
  final int? estoqueId;
  final String nomeMedicamento;
  final String? dosagem;
  final String horario;
  final String? horarioPreAviso;
  final bool ativo;
  final String? googleEventId;

  AgendamentoModel({
    this.id,
    this.estoqueId,
    required this.nomeMedicamento,
    this.dosagem,
    required this.horario,
    this.horarioPreAviso,
    this.ativo = true,
    this.googleEventId,
  });

  factory AgendamentoModel.fromJson(Map<String, dynamic> json) {
    return AgendamentoModel(
      id: json['id'] as int?,
      estoqueId: json['estoqueId'] as int?,
      nomeMedicamento: (json['nomeMedicamento'] ?? '') as String,
      dosagem: json['dosagem'] as String?,
      horario: (json['horario'] ?? '') as String,
      horarioPreAviso: json['horarioPreAviso'] as String?,
      ativo: (json['ativo'] as bool?) ?? true,
      googleEventId: json['googleEventId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final h = horario.trim();
    final horarioFormatado = RegExp(r'^\d{2}:\d{2}$').hasMatch(h) ? '$h:00' : h;
    return {
      if (id != null) 'id': id,
      if (estoqueId != null) 'estoqueId': estoqueId,
      'nomeMedicamento': nomeMedicamento.trim(),
      if (dosagem != null && dosagem!.trim().isNotEmpty) 'dosagem': dosagem!.trim(),
      'horario': horarioFormatado,
      'ativo': ativo,
      if (googleEventId != null) 'googleEventId': googleEventId,
    };
  }
}

class RegistroDoseModel {
  final int id;
  final AgendamentoModel agendamento;
  final String dataHoraPrevista;
  final String? dataHoraTomada;
  final String status;
  final String? observacao;

  RegistroDoseModel({
    required this.id,
    required this.agendamento,
    required this.dataHoraPrevista,
    this.dataHoraTomada,
    required this.status,
    this.observacao,
  });

  factory RegistroDoseModel.fromJson(Map<String, dynamic> json) {
    return RegistroDoseModel(
      id: json['id'] as int,
      agendamento: AgendamentoModel.fromJson(
        (json['agendamento'] as Map<String, dynamic>? ?? const {}),
      ),
      dataHoraPrevista: (json['dataHoraPrevista'] ?? '') as String,
      dataHoraTomada: json['dataHoraTomada'] as String?,
      status: (json['status'] ?? 'PENDENTE') as String,
      observacao: json['observacao'] as String?,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class AgendamentoDoseService {
  // Ajuste para o IP da sua máquina na rede local ao rodar no Samsung Galaxy A13
  static const String baseUrl = 'http://192.168.0.5:8080/api';

  Future _headers({
    String? googleToken,
    bool incluirGoogleToken = false,
  }) async {
    final headers = await SessionService.headersAutenticados(incluirJson: true);

    String? tokenFinal = googleToken;
    if (incluirGoogleToken && (tokenFinal == null || tokenFinal.trim().isEmpty)) {
      tokenFinal = await AuthVinculoService.obterTokenGoogleAgenda();
    }

    if (tokenFinal != null && tokenFinal.trim().isNotEmpty) {
      headers['X-Google-Token'] = tokenFinal.trim();
    }
    return headers;
  }

  Never _throwHttpError(http.Response res, String fallback) {
    String msg = fallback;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['erro'] is String) {
          msg = decoded['erro'] as String;
        } else if (decoded['message'] is String) {
          msg = decoded['message'] as String;
        }
      }
    } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }

  Future<List<AgendamentoModel>> listarAgendamentos() async {
    final res = await http.get(
      Uri.parse('$baseUrl/agendamentos'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(res, 'Erro ao buscar agendamentos.');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AgendamentoModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AgendamentoModel> criarAgendamento(
    AgendamentoModel model, {
    String? googleToken,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/agendamentos'),
      headers: await _headers(googleToken: googleToken, incluirGoogleToken: true),
      body: jsonEncode(model.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(
        res,
        res.statusCode == 409
            ? 'Conflito de horário com outro agendamento ativo.'
            : 'Erro ao criar agendamento.',
      );
    }
    return AgendamentoModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AgendamentoModel> atualizarAgendamento(
    int id,
    AgendamentoModel model, {
    String? googleToken,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/agendamentos/$id'),
      headers: await _headers(googleToken: googleToken, incluirGoogleToken: true),
      body: jsonEncode(model.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(
        res,
        res.statusCode == 409
            ? 'Conflito de horário com outro agendamento ativo.'
            : 'Erro ao atualizar agendamento.',
      );
    }
    return AgendamentoModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> desativarAgendamento(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/agendamentos/$id'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(res, 'Erro ao desativar agendamento.');
    }
  }

  Future<List<RegistroDoseModel>> listarDosesHoje() async {
    final res = await http.get(
      Uri.parse('$baseUrl/doses/hoje'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(res, 'Erro ao carregar as doses de hoje.');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => RegistroDoseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RegistroDoseModel> confirmarDoseTomada(int doseId, {String? observacao}) async {
    final uri = Uri.parse('$baseUrl/doses/$doseId/tomar').replace(
      queryParameters: (observacao != null && observacao.trim().isNotEmpty)
          ? {'observacao': observacao.trim()}
          : null,
    );
    final res = await http.put(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(res, 'Erro ao confirmar dose.');
    }
    return RegistroDoseModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<RegistroDoseModel> marcarDosePulada(int doseId, {String? observacao}) async {
    final uri = Uri.parse('$baseUrl/doses/$doseId/pular').replace(
      queryParameters: (observacao != null && observacao.trim().isNotEmpty)
          ? {'observacao': observacao.trim()}
          : null,
    );
    final res = await http.put(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(res, 'Erro ao marcar dose como pulada.');
    }
    return RegistroDoseModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<RegistroDoseModel>> listarHistoricoDose(int agendamentoId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/doses/agendamento/$agendamentoId'),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwHttpError(res, 'Erro ao carregar histórico de doses.');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => RegistroDoseModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}