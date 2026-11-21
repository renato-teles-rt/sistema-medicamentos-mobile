import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario_model.dart';
import '../services/auth_vinculo_service.dart';
import '../services/session_service.dart';
import 'escolha_cuidador_view.dart';
import 'home_paciente_view.dart';
import 'login_view.dart';

class PainelVinculoView extends StatefulWidget {
  final UsuarioModel usuario;
  const PainelVinculoView({super.key, required this.usuario});

  @override
  State<PainelVinculoView> createState() => _PainelVinculoViewState();
}

class _PainelVinculoViewState extends State<PainelVinculoView> {
  final AuthVinculoService _authService = AuthVinculoService();
  final TextEditingController _codigoController = TextEditingController();
  String? _mensagem;
  bool _sucesso = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogout() async {
    await SessionService.encerrarSessao();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  Future<void> _vincular() async {
    try {
      await _authService.criarVinculoFamiliar(
        widget.usuario.id,
        _codigoController.text,
      );
      setState(() {
        _sucesso = true;
        _mensagem = 'Paciente vinculado com sucesso!';
        _codigoController.clear();
      });
    } catch (e) {
      setState(() {
        _sucesso = false;
        _mensagem = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _copiarCodigo() {
    Clipboard.setData(ClipboardData(text: widget.usuario.codigoVinculo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Código copiado! Cole no WhatsApp para enviar ao cuidador.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaciente = widget.usuario.tipoPerfil == 'PACIENTE';
    const corPrimaria = Color(0xFF0F4C81);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vínculo Familiar'),
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        leading: isPaciente
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EscolhaCuidadorView(usuario: widget.usuario),
                    ),
                  );
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _fazerLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Olá, ${widget.usuario.nome}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Perfil: ${widget.usuario.tipoPerfil} • ${widget.usuario.email}',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (isPaciente) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: corPrimaria, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Seu Código de Vínculo Familiar:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.usuario.codigoVinculo,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copiarCodigo,
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: corPrimaria,
                      ),
                      label: const Text(
                        'Copiar Código',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: corPrimaria,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: corPrimaria),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Informe este código ao seu cuidador para que ele acompanhe seus horários.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePacienteView(usuario: widget.usuario),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrimaria,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Concluir e ir para meus medicamentos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              const Text(
                'Digite o código de 6 letras do Paciente:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codigoController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'EX: A9K2M4',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _vincular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrimaria,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Vincular Paciente',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (_mensagem != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _sucesso ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _sucesso ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  _mensagem!,
                  style: TextStyle(
                    fontSize: 16,
                    color: _sucesso
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
