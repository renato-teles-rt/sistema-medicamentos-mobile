import 'usuario_model.dart';

class VinculoFamiliarModel {
  final int id;
  final UsuarioModel paciente;
  final UsuarioModel cuidador;
  final bool ativo;

  VinculoFamiliarModel({
    required this.id,
    required this.paciente,
    required this.cuidador,
    required this.ativo,
  });

  factory VinculoFamiliarModel.fromJson(Map<String, dynamic> json) {
    return VinculoFamiliarModel(
      id: json['id'],
      paciente: UsuarioModel.fromJson(json['paciente']),
      cuidador: UsuarioModel.fromJson(json['cuidador']),
      ativo: json['ativo'] ?? true,
    );
  }
}
