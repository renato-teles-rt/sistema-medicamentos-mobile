import 'package:flutter/material.dart';

import '../models/usuario_model.dart';
import 'home_paciente_view.dart';
import 'painel_vinculo_view.dart';

class EscolhaCuidadorView extends StatelessWidget {
  final UsuarioModel usuario;

  const EscolhaCuidadorView({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    const corPrimaria = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('Acompanhamento'),
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.diversity_1_rounded,
                size: 80,
                color: corPrimaria,
              ),
              const SizedBox(height: 24),
              Text(
                'Olá, ${usuario.nome}!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C2833),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Você deseja compartilhar sua rotina de medicamentos com um cuidador ou familiar?',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.45,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Essa opção é totalmente opcional. Você pode começar usando o aplicativo sozinho e vincular alguém depois, se quiser.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Color(0xFF566573),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: corPrimaria,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePacienteView(usuario: usuario),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline, size: 26),
                label: const Text(
                  'Não agora, usar sozinho',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(color: corPrimaria, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PainelVinculoView(usuario: usuario),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.person_add_alt_1,
                  size: 26,
                  color: corPrimaria,
                ),
                label: const Text(
                  'Sim, vincular um cuidador',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: corPrimaria,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
