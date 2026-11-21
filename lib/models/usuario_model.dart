class UsuarioModel {
  final int id;
  final String nome;
  final String email;
  final String? fotoUrl;
  final String tipoPerfil;
  final String codigoVinculo;

  UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    this.fotoUrl,
    required this.tipoPerfil,
    required this.codigoVinculo,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      fotoUrl: json['fotoUrl'],
      tipoPerfil: json['tipoPerfil'],
      codigoVinculo: json['codigoVinculo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'fotoUrl': fotoUrl,
      'tipoPerfil': tipoPerfil,
      'codigoVinculo': codigoVinculo,
    };
  }
}
