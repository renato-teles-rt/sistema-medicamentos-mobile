import 'package:flutter/material.dart';

import '../models/usuario_model.dart';
import '../services/auth_vinculo_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'escolha_cuidador_view.dart';
import 'painel_vinculo_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  static const Color _corFundoNavy = Color(0xFF021330);
  static const Color _corCardNavy = Color(0xFF081D45);
  static const Color _corDestaqueCiano = Color(0xFF38BDF8);
  static const Color _corBotaoAzul = Color(0xFF0284C7);

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
        await SessionService.salvarSessao(usuario);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => usuario.tipoPerfil == 'PACIENTE'
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
      backgroundColor: _corFundoNavy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double horizontalPadding = 24.0;
            const double verticalPadding = 24.0;
            final double minHeight =
                (constraints.maxHeight - (verticalPadding * 2)).clamp(
                  0.0,
                  double.infinity,
                );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo_cuidamed.png',
                        height: 130,
                        fit: BoxFit.contain,
                        semanticLabel: 'CuidaMed 50+',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CuidaMed 50+',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Escolha como você vai usar o aplicativo:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFCBD5E1),
                      ),
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
                          color: Colors.red.shade900.withValues(alpha: 0.45),
                          border: Border.all(
                            color: AppTheme.danger,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _erro!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: _carregando ? null : _fazerLoginGoogle,
                      icon: const Icon(Icons.account_circle, size: 28),
                      label: Text(
                        _carregando
                            ? 'Conectando...'
                            : 'Entrar com Conta Google',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corBotaoAzul,
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
            );
          },
        ),
      ),
    );
  }

  Widget _botaoPerfil(String valor, String titulo, IconData icone) {
    final bool selecionado = _tipoPerfil == valor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _carregando ? null : () => setState(() => _tipoPerfil = valor),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: selecionado
                ? _corDestaqueCiano.withValues(alpha: 0.16)
                : _corCardNavy,
            border: Border.all(
              color: selecionado
                  ? _corDestaqueCiano
                  : const Color(0xFF1E3A8A),
              width: selecionado ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(
                icone,
                size: 32,
                color: selecionado ? _corDestaqueCiano : Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}