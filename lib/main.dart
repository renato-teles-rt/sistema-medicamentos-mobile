import 'package:flutter/material.dart';

import 'models/usuario_model.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';
import 'views/home_paciente_view.dart';
import 'views/login_view.dart';
import 'views/painel_vinculo_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A restauração da sessão NÃO pode derrubar o app. Um dado corrompido em
  // SharedPreferences (ou uma plataforma que falhe ao inicializar o storage)
  // levantava antes do runApp e deixava a tela branca, sem nenhuma pista.
  // Agora qualquer falha cai na tela de login.
  UsuarioModel? usuarioSalvo;
  try {
    usuarioSalvo = await SessionService.obterSessaoAtiva();
  } catch (erro, pilha) {
    debugPrint('Falha ao restaurar a sessão: $erro\n$pilha');
    usuarioSalvo = null;
  }

  runApp(CuidaMedApp(usuarioInicial: usuarioSalvo));
}

class CuidaMedApp extends StatelessWidget {
  final UsuarioModel? usuarioInicial;

  const CuidaMedApp({super.key, this.usuarioInicial});

  @override
  Widget build(BuildContext context) {
    Widget telaInicial;
    if (usuarioInicial == null) {
      telaInicial = const LoginView();
    } else if (usuarioInicial!.tipoPerfil == 'PACIENTE') {
      telaInicial = HomePacienteView(usuario: usuarioInicial!);
    } else {
      telaInicial = PainelVinculoView(usuario: usuarioInicial!);
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
      home: telaInicial,
    );
  }
}
