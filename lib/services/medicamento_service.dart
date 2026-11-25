import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/medicamento_model.dart';
import 'session_service.dart';

/// Catálogo de medicações e controle de estoque do paciente.
///
/// Os dados ficam salvos localmente (SharedPreferences), por paciente, para
/// funcionar mesmo sem conexão. Quando a API estiver disponível, basta
/// substituir a leitura/escrita local por chamadas HTTP — a interface
/// pública desta classe já é assíncrona para permitir essa troca.
class MedicamentoService {
  static const String _prefixoChave = 'cuidamed_medicamentos_';

  String _chave(int pacienteId) => '$_prefixoChave$pacienteId';

  Future<List<MedicamentoModel>> listar(int pacienteId) async {
    final prefs = await SharedPreferences.getInstance();

    // Na web, uma chave com tipo inesperado (Map/List gravado por engano) faz
    // `getString` lançar TypeError antes de qualquer try/catch de parse.
    final String? json;
    try {
      json = prefs.getString(_chave(pacienteId));
    } catch (_) {
      await prefs.remove(_chave(pacienteId));
      return [];
    }

    if (json == null || json.isEmpty) return [];

    try {
      final dynamic decodificado = jsonDecode(json);
      if (decodificado is! List) return [];
      return decodificado
          .whereType<Map<String, dynamic>>()
          .map((item) => MedicamentoModel.fromJson(item))
          .toList();
    } catch (_) {
      // Dados corrompidos: começa um catálogo vazio em vez de travar a tela.
      return [];
    }
  }

  Future<void> salvarLista(int pacienteId, List<MedicamentoModel> itens) async {
    final prefs = await SharedPreferences.getInstance();
    final ordenados = List<MedicamentoModel>.from(itens)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    await prefs.setString(
      _chave(pacienteId),
      jsonEncode(ordenados.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> adicionar(int pacienteId, MedicamentoModel medicamento) async {
    final itens = await listar(pacienteId);
    itens.add(medicamento);
    await salvarLista(pacienteId, itens);
  }

  Future<void> atualizar(int pacienteId, MedicamentoModel medicamento) async {
    final itens = await listar(pacienteId);
    final indice = itens.indexWhere((m) => m.id == medicamento.id);
    if (indice >= 0) {
      itens[indice] = medicamento;
      await salvarLista(pacienteId, itens);
    }
  }

  Future<void> remover(int pacienteId, String medicamentoId) async {
    final itens = await listar(pacienteId);
    itens.removeWhere((m) => m.id == medicamentoId);
    await salvarLista(pacienteId, itens);
  }

  /// Importa medicações já cadastradas em outro dispositivo/backend.
  /// Mantido preparado para integração futura; falhas de rede são ignoradas
  /// para não bloquear o uso local do aplicativo.
  Future<List<MedicamentoModel>> sincronizar(int pacienteId) async {
    try {
      final headers = await SessionService.headersAutenticados(
        incluirJson: false,
      );
      final response = await http.get(
        ApiConfig.medicamentos('/paciente/$pacienteId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> lista = jsonDecode(utf8.decode(response.bodyBytes));
        final remotos = lista
            .map(
              (item) => MedicamentoModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        await salvarLista(pacienteId, remotos);
        return remotos;
      }
    } catch (_) {
      // Sem conexão ou endpoint ainda não publicado: usa o catálogo local.
    }

    return listar(pacienteId);
  }
}
