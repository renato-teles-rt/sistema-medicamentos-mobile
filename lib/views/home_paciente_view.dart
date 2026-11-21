import 'package:flutter/material.dart';

import '../models/usuario_model.dart';
import '../services/session_service.dart';
import 'login_view.dart';
import 'painel_vinculo_view.dart';

class MedicamentoItem {
  final String id;
  final String nome;
  final String dosagem;
  final String horario;
  bool tomadoHoje;

  MedicamentoItem({
    required this.id,
    required this.nome,
    required this.dosagem,
    required this.horario,
    this.tomadoHoje = false,
  });
}

class HomePacienteView extends StatefulWidget {
  final UsuarioModel usuario;

  const HomePacienteView({super.key, required this.usuario});

  @override
  State<HomePacienteView> createState() => _HomePacienteViewState();
}

class _HomePacienteViewState extends State<HomePacienteView> {
  final List<MedicamentoItem> _medicamentos = [];

  Future<void> _fazerLogout() async {
    await SessionService.encerrarSessao();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  void _abrirFormularioNovoRemedio() {
    final nomeController = TextEditingController();
    final dosagemController = TextEditingController();
    TimeOfDay horarioSelecionado = const TimeOfDay(hour: 8, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final horarioFormatado =
                '${horarioSelecionado.hour.toString().padLeft(2, '0')}:${horarioSelecionado.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Adicionar Medicamento',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F4C81),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Nome do remédio',
                      hintText: 'Ex: Losartana',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dosagemController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Dosagem / Quantidade',
                      hintText: 'Ex: 50mg - 1 comprimido',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final escolhido = await showTimePicker(
                        context: context,
                        initialTime: horarioSelecionado,
                      );
                      if (escolhido != null) {
                        setModalState(() => horarioSelecionado = escolhido);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade500),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Horário da dose:',
                            style: TextStyle(fontSize: 18),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFF0F4C81),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                horarioFormatado,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F4C81),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final nome = nomeController.text.trim();
                      final dosagem = dosagemController.text.trim();
                      if (nome.isEmpty) return;

                      setState(() {
                        _medicamentos.add(
                          MedicamentoItem(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            nome: nome,
                            dosagem: dosagem.isEmpty ? 'Dose única' : dosagem,
                            horario: horarioFormatado,
                          ),
                        );
                        _medicamentos.sort(
                          (a, b) => a.horario.compareTo(b.horario),
                        );
                      });

                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Salvar Medicamento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const corPrimaria = Color(0xFF0F4C81);
    final totalTomados = _medicamentos.where((m) => m.tomadoHoje).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('Meus Medicamentos'),
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Vincular Cuidador',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PainelVinculoView(usuario: widget.usuario),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _fazerLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Olá, ${widget.usuario.nome}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _medicamentos.isEmpty
                  ? 'Acompanhe seus horários de medicação de hoje:'
                  : 'Progresso de hoje: $totalTomados de ${_medicamentos.length} tomados',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _medicamentos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medication_liquid,
                            size: 72,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum medicamento cadastrado ainda.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toque no botão + abaixo para adicionar seu primeiro remédio.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _medicamentos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = _medicamentos[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: item.tomadoHoje
                                ? Colors.green.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.tomadoHoje
                                  ? Colors.green.shade400
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: item.tomadoHoje
                                      ? Colors.green.shade100
                                      : const Color(0xFFE3F0FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.horario,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: item.tomadoHoje
                                        ? Colors.green.shade900
                                        : corPrimaria,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nome,
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        decoration: item.tomadoHoje
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.dosagem,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                iconSize: 34,
                                color: item.tomadoHoje
                                    ? Colors.green.shade700
                                    : Colors.grey.shade400,
                                tooltip: item.tomadoHoje
                                    ? 'Desmarcar'
                                    : 'Marcar como tomado',
                                icon: Icon(
                                  item.tomadoHoje
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                ),
                                onPressed: () {
                                  setState(() {
                                    item.tomadoHoje = !item.tomadoHoje;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red.shade400,
                                tooltip: 'Remover',
                                onPressed: () {
                                  setState(() {
                                    _medicamentos.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioNovoRemedio,
        backgroundColor: corPrimaria,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Novo Remédio',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
