/// Faixas de criticidade do estoque de um medicamento.
enum StatusEstoque { normal, baixo, esgotado }

/// Item do catálogo de medicações com controle de estoque.
///
/// O estoque é controlado em "unidades" (ex.: comprimidos, gotas, cápsulas).
/// Cada dose de uso diário consome [quantidadePorDose] unidades, permitindo
/// calcular quantos dias de tratamento ainda existem.
class MedicamentoModel {
  /// Limite padrão de dias restantes para disparar o alerta de estoque baixo.
  static const int diasAlertaPadrao = 3;

  final String id;
  final String nome;
  final String dosagem;
  final String horario;
  final int quantidadePorDose;
  final int quantidadeTotal;
  final int diasAlerta;
  final String observacao;

  MedicamentoModel({
    required this.id,
    required this.nome,
    required this.dosagem,
    required this.horario,
    this.quantidadePorDose = 1,
    required this.quantidadeTotal,
    this.diasAlerta = diasAlertaPadrao,
    this.observacao = '',
  });

  /// Quantidade que será consumida em um único dia.
  int get consumoDiario => quantidadePorDose;

  /// Dias completos de tratamento até o estoque acabar.
  int get diasRestantes =>
      consumoDiario <= 0 ? 0 : quantidadeTotal ~/ consumoDiario;

  StatusEstoque get statusEstoque {
    if (quantidadeTotal <= 0) return StatusEstoque.esgotado;
    if (diasRestantes <= diasAlerta) return StatusEstoque.baixo;
    return StatusEstoque.normal;
  }

  bool get estoqueBaixo => statusEstoque != StatusEstoque.normal;

  /// Descrição da dosagem no formato "1 comprimido • 50mg".
  String get descricaoDose {
    final String unidades = quantidadePorDose == 1 ? 'unidade' : 'unidades';
    if (dosagem.isEmpty) return '$quantidadePorDose $unidades por dose';
    return '$quantidadePorDose $unidades • $dosagem';
  }

  /// Texto curto para o alerta de estoque.
  String get mensagemStatus {
    switch (statusEstoque) {
      case StatusEstoque.esgotado:
        return 'Estoque esgotado. Compre ou reponha antes da próxima dose.';
      case StatusEstoque.baixo:
        return diasRestantes == 0
            ? 'Estoque baixo: dura menos de 1 dia.'
            : 'Estoque baixo: restam $diasRestantes dia(s) de tratamento.';
      case StatusEstoque.normal:
        return 'Restam $diasRestantes dia(s) de tratamento.';
    }
  }

  MedicamentoModel copyWith({int? quantidadeTotal}) {
    return MedicamentoModel(
      id: id,
      nome: nome,
      dosagem: dosagem,
      horario: horario,
      quantidadePorDose: quantidadePorDose,
      quantidadeTotal: quantidadeTotal ?? this.quantidadeTotal,
      diasAlerta: diasAlerta,
      observacao: observacao,
    );
  }

  factory MedicamentoModel.fromJson(Map<String, dynamic> json) {
    return MedicamentoModel(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      nome: json['nome'] ?? '',
      dosagem: json['dosagem'] ?? '',
      horario: json['horario'] ?? '08:00',
      quantidadePorDose: _paraInteiro(json['quantidadePorDose'], padrao: 1),
      quantidadeTotal: _paraInteiro(json['quantidadeTotal']),
      diasAlerta: _paraInteiro(json['diasAlerta'], padrao: diasAlertaPadrao),
      observacao: json['observacao'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'dosagem': dosagem,
      'horario': horario,
      'quantidadePorDose': quantidadePorDose,
      'quantidadeTotal': quantidadeTotal,
      'diasAlerta': diasAlerta,
      'observacao': observacao,
    };
  }

  static int _paraInteiro(dynamic valor, {int padrao = 0}) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? padrao;
  }
}
