import 'dart:async';

import 'package:flutter/material.dart';

import 'models/usuario_model.dart';
import 'services/session_service.dart';
import 'services/alarme_notificacao_service.dart';
import 'theme/app_theme.dart';
import 'views/home_paciente_view.dart';
import 'views/login_view.dart';
import 'views/painel_vinculo_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmeNotificacaoService.inicializar();
  final UsuarioModel? usuarioSalvo = await SessionService.obterSessaoAtiva();
  runApp(CuidaMedApp(usuarioInicial: usuarioSalvo));
}

class CuidaMedApp extends StatelessWidget {
  final UsuarioModel? usuarioInicial;

  const CuidaMedApp({super.key, this.usuarioInicial});

  @override
  Widget build(BuildContext context) {
    Widget telaDestino;
    if (usuarioInicial == null) {
      telaDestino = const LoginView();
    } else if (usuarioInicial!.tipoPerfil == 'PACIENTE') {
      telaDestino = HomePacienteView(usuario: usuarioInicial!);
    } else {
      telaDestino = PainelVinculoView(usuario: usuarioInicial!);
    }

    return MaterialApp(
      title: 'CuidaMed 50+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final currentScale = mediaQuery.textScaler.scale(1.0);
        final clampedScale = currentScale.clamp(1.0, 1.35);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(clampedScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: SplashLogoView(proximaTela: telaDestino),
    );
  }
}

class SplashLogoView extends StatefulWidget {
  final Widget proximaTela;
  final Duration duracao;

  const SplashLogoView({
    super.key,
    required this.proximaTela,
    this.duracao = const Duration(seconds: 2),
  });

  @override
  State<SplashLogoView> createState() => _SplashLogoViewState();
}

class _SplashLogoViewState extends State<SplashLogoView> {
  @override
  void initState() {
    super.initState();
    Timer(widget.duracao, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.proximaTela),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021330),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Image.asset(
            'assets/images/logo_cuidamed.png',
            width: 240,
            fit: BoxFit.contain,
            semanticLabel: 'CuidaMed 50+',
          ),
        ),
      ),
    );
  }
}