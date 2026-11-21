import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario_model.dart';
import '../models/vinculo_familiar_model.dart';
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
  static const int _limiteMaximoCuidadores = 2;

  final AuthVinculoService _authService = AuthVinculoService();
  final TextEditingController _codigoController = TextEditingController();

  List<VinculoFamiliarModel> _vinculos = [];
  bool _carregandoVinculos = true;
  String? _mensagem;
  bool _sucesso = false;

  @override
  void initState() {
    super.initState();
    _carregarVinculos();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _carregarVinculos() async {
    setState(() => _carregandoVinculos = true);
    try {
      final lista = widget.usuario.tipoPerfil == 'PACIENTE'
          ? await _authService.listarCuidadoresDoPaciente(widget.usuario.id)
          : await _authService.listarPacientesDoCuidador(widget.usuario.id);

      if (mounted) {
        setState(() {
          _vinculos = lista;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sucesso = false;
          _mensagem = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoVinculos = false);
      }
    }
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
    setState(() => _mensagem = null);
    try {
      await _authService.criarVinculoFamiliar(
        widget.usuario.id,
        _codigoController.text,
      );
      _codigoController.clear();
      await _carregarVinculos();
      if (mounted) {
        setState(() {
          _sucesso = true;
          _mensagem = 'Paciente vinculado com sucesso!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sucesso = false;
          _mensagem = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _confirmarDesvinculacao(VinculoFamiliarModel vinculo) async {
    final bool isPaciente = widget.usuario.tipoPerfil == 'PACIENTE';
    final String nomeAlvo = isPaciente
        ? vinculo.cuidador.nome
        : vinculo.paciente.nome;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar desvinculação'),
        content: Text(
          'Deseja realmente remover o vínculo com $nomeAlvo?',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _authService.desvincularFamiliar(vinculo.id);
      await _carregarVinculos();
      if (mounted) {
        setState(() {
          _sucesso = true;
          _mensagem = 'Vínculo com $nomeAlvo encerrado com sucesso.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sucesso = false;
          _mensagem = e.toString().replaceFirst('Exception: ', '');
        });
      }
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
    final bool limiteAtingido =
        isPaciente && _vinculos.length >= _limiteMaximoCuidadores;

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
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar vínculos',
            onPressed: _carregarVinculos,
          ),
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
                    Text(
                      limiteAtingido
                          ? 'Você atingiu o limite máximo de $_limiteMaximoCuidadores cuidadores ativos. Desvincule um abaixo se quiser adicionar outro.'
                          : 'Informe este código ao seu cuidador (você pode ter até $_limiteMaximoCuidadores cuidadores ativos).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: limiteAtingido
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: limiteAtingido
                            ? Colors.orange.shade900
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Meus Cuidadores',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: limiteAtingido
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_vinculos.length} de $_limiteMaximoCuidadores ativos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: limiteAtingido
                            ? Colors.orange.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _construirListaVinculos(isPaciente: true),
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
              const SizedBox(height: 28),
              const Text(
                'Pacientes Acompanhados',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _construirListaVinculos(isPaciente: false),
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

  Widget _construirListaVinculos({required bool isPaciente}) {
    if (_carregandoVinculos) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_vinculos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          isPaciente
              ? 'Nenhum cuidador vinculado no momento (0 de $_limiteMaximoCuidadores).'
              : 'Você ainda não está acompanhando nenhum paciente.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return Column(
      children: _vinculos.map((vinculo) {
        final pessoa = isPaciente ? vinculo.cuidador : vinculo.paciente;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE3F0FA),
                child: Icon(
                  isPaciente ? Icons.volunteer_activism : Icons.person,
                  color: const Color(0xFF0F4C81),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pessoa.nome,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      pessoa.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _confirmarDesvinculacao(vinculo),
                icon: Icon(Icons.link_off, color: Colors.red.shade700),
                label: Text(
                  'Desvincular',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
