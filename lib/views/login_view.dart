import 'package:flutter/material.dart';

import '../models/usuario_model.dart';
import '../services/auth_vinculo_service.dart';
import 'painel_vinculo_view.dart';
import 'escolha_cuidador_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthVinculoService _authService = AuthVinculoService();
  String _tipoPerfil = 'PACIENTE';
  bool _carregando = false;
  String? _erro;

  Future<void> _fazerLoginGoogle() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final UsuarioModel? usuario = await _authService
          .entrarComContaGoogleNativa(_tipoPerfil);

      if (usuario != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _tipoPerfil == 'PACIENTE'
                ? EscolhaCuidadorView(usuario: usuario)
                : PainelVinculoView(usuario: usuario),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.medication_rounded,
                size: 72,
                color: Color(0xFF0F4C81),
              ),
              const SizedBox(height: 16),
              const Text(
                'CuidaMed 50+',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F4C81),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha como você vai usar o aplicativo:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _botaoPerfil(
                      'PACIENTE',
                      'Sou Paciente',
                      Icons.person,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _botaoPerfil(
                      'CUIDADOR',
                      'Sou Cuidador',
                      Icons.volunteer_activism,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_erro != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _erro!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 16),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _carregando ? null : _fazerLoginGoogle,
                icon: const Icon(Icons.account_circle, size: 28),
                label: Text(
                  _carregando ? 'Conectando...' : 'Entrar com Conta Google',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoPerfil(String valor, String titulo, IconData icone) {
    final bool selecionado = _tipoPerfil == valor;
    return InkWell(
      onTap: () => setState(() => _tipoPerfil = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFE3F0FA) : Colors.white,
          border: Border.all(
            color: selecionado ? const Color(0xFF0F4C81) : Colors.grey.shade400,
            width: selecionado ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icone, size: 32, color: const Color(0xFF0F4C81)),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
