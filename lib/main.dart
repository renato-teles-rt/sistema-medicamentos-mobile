import 'package:flutter/material.dart';

import 'models/usuario_model.dart';
import 'services/session_service.dart';
import 'views/home_paciente_view.dart';
import 'views/login_view.dart';
import 'views/painel_vinculo_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final UsuarioModel? usuarioSalvo = await SessionService.obterSessaoAtiva();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F4C81)),
        useMaterial3: true,
      ),
      home: telaInicial,
    );
  }
}
