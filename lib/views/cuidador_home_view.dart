import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario_model.dart';
import '../models/vinculo_familiar_model.dart';
import '../services/agendamento_dose_service.dart';
import '../services/auth_vinculo_service.dart';
import '../services/session_service.dart';
import 'agendamentos_doses_view.dart';
import 'login_view.dart';
import 'painel_vinculo_view.dart';

class ItemDoseCuidador {
  final int? doseId;
  final int? agendamentoId;
  final String nomeMedicamento;
  String medida;
  String horario;
  String status; // PENDENTE, ADIADO, TOMADO

  ItemDoseCuidador({
    this.doseId,
    this.agendamentoId,
    required this.nomeMedicamento,
    required this.medida,
    required this.horario,
    this.status = 'PENDENTE',
  });
}

class CuidadorHomeView extends StatefulWidget {
  final UsuarioModel usuario;
  final VinculoFamiliarModel? vinculoInicial;

  const CuidadorHomeView({
    super.key,
    required this.usuario,
    this.vinculoInicial,
  });

  @override
  State<CuidadorHomeView> createState() => _CuidadorHomeViewState();
}

class _CuidadorHomeViewState extends State<CuidadorHomeView> {
  static const Color _corPrimaria = Color(0xFF1E3A5F);
  static const Color _corDestaque = Color(0xFF2B6CB0);

  // Cache estático em memória para preservar TOMADO e ADIADO ao atualizar/recarregar
  static final Set<String> _chavesTomadasCache = <String>{};
  static final Map<String, ({String horario, String status})>
      _ajustesAtivosCache = <String, ({String horario, String status})>{};

  final AuthVinculoService _authService = AuthVinculoService();
  final AgendamentoDoseService _agendamentoService = AgendamentoDoseService();

  List<VinculoFamiliarModel> _pacientesVinculados = [];
  VinculoFamiliarModel? _pacienteSelecionado;

  bool _carregando = true;
  String? _erro;
  List<ItemDoseCuidador> _dosesAtivas = [];
  List<ItemDoseCuidador> _dosesTomadas = [];

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  String _chaveDose(ItemDoseCuidador item) {
    if (item.doseId != null) return 'dose_${item.doseId}';
    if (item.agendamentoId != null) return 'ag_${item.agendamentoId}';
    return '${item.nomeMedicamento.trim().toLowerCase()}|${item.horario.trim()}';
  }

  Future<void> _inicializarTela() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final lista = await _authService.listarPacientesDoCuidador(
        widget.usuario.id,
      );
      if (!mounted) return;

      VinculoFamiliarModel? escolhido = widget.vinculoInicial;
      if (escolhido != null && lista.isNotEmpty) {
        final match = lista.where(
          (v) => v.paciente.id == escolhido!.paciente.id || v.id == escolhido.id,
        );
        if (match.isNotEmpty) {
          escolhido = match.first;
        }
      }
      escolhido ??= lista.isNotEmpty ? lista.first : null;

      setState(() {
        _pacientesVinculados = lista;
        _pacienteSelecionado = escolhido;
      });

      await _carregarMedicacoesDoPaciente();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  String _formatarHoraCurta(String? hora) {
    if (hora == null || hora.trim().isEmpty) return '--:--';
    final partes = hora.trim().split(':');
    if (partes.length >= 2) {
      return '${partes[0].padLeft(2, '0')}:${partes[1].padLeft(2, '0')}';
    }
    return hora.trim();
  }

  String _adicionarMinutos(String horaHhMm, int minutosExtra) {
    final partes = horaHhMm.split(':');
    final h = int.tryParse(partes.isNotEmpty ? partes[0] : '8') ?? 8;
    final m = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    final total =
        ((h * 60 + m + minutosExtra) % (24 * 60) + (24 * 60)) % (24 * 60);
    final nh = (total ~/ 60).toString().padLeft(2, '0');
    final nm = (total % 60).toString().padLeft(2, '0');
    return '$nh:$nm';
  }

  String _formatarTimeOfDay(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  String _formatarMedida(String valorBruto, {required bool usarComprimidos}) {
    final limpo = valorBruto.trim().replaceAll(',', '.');
    if (limpo.isEmpty) {
      return usarComprimidos ? '1 comprimido' : '50 mg';
    }
    final numero = double.tryParse(limpo);
    if (numero == null) {
      return usarComprimidos ? '1 comprimido' : '50 mg';
    }
    final textoNum =
        numero == numero.truncateToDouble() ? numero.toInt().toString() : limpo;
    if (usarComprimidos) {
      return numero == 1 ? '1 comprimido' : '$textoNum comprimidos';
    }
    return '$textoNum mg';
  }

  Future<void> _carregarMedicacoesDoPaciente() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    List<RegistroDoseModel> doses = [];
    List<AgendamentoModel> agendamentos = [];

    try {
      doses = await _agendamentoService.listarDosesHoje();
    } catch (_) {}

    try {
      agendamentos = await _agendamentoService.listarAgendamentos();
    } catch (e) {
      if (doses.isEmpty) {
        if (!mounted) return;
        setState(() {
          _erro =
              'Não foi possível carregar as medicações do paciente: ${e.toString().replaceFirst('Exception: ', '')}';
          _carregando = false;
        });
        return;
      }
    }

    final List<ItemDoseCuidador> ativas = [];
    final List<ItemDoseCuidador> tomadas = [];

    for (final dose in doses) {
      final hora = _formatarHoraCurta(dose.agendamento.horario);
      final medida = (dose.agendamento.dosagem != null &&
              dose.agendamento.dosagem!.trim().isNotEmpty)
          ? dose.agendamento.dosagem!.trim()
          : '1 comprimido';
      final status = dose.status.toUpperCase();

      final item = ItemDoseCuidador(
        doseId: dose.id,
        agendamentoId: dose.agendamento.id,
        nomeMedicamento: dose.agendamento.nomeMedicamento,
        medida: medida,
        horario: hora,
        status: status,
      );

      if (status == 'TOMADO') {
        tomadas.add(item);
      } else {
        ativas.add(item);
      }
    }

    for (final ag in agendamentos) {
      if (!ag.ativo) continue;
      final hora = _formatarHoraCurta(ag.horario);
      final medida = (ag.dosagem != null && ag.dosagem!.trim().isNotEmpty)
          ? ag.dosagem!.trim()
          : '1 comprimido';

      final jaExiste = ativas.any(
            (i) =>
                (ag.id != null && i.agendamentoId == ag.id) ||
                (i.nomeMedicamento.toLowerCase() ==
                        ag.nomeMedicamento.toLowerCase() &&
                    i.horario == hora),
          ) ||
          tomadas.any(
            (i) =>
                (ag.id != null && i.agendamentoId == ag.id) ||
                (i.nomeMedicamento.toLowerCase() ==
                        ag.nomeMedicamento.toLowerCase() &&
                    i.horario == hora),
          );

      if (!jaExiste) {
        ativas.add(
          ItemDoseCuidador(
            agendamentoId: ag.id,
            nomeMedicamento: ag.nomeMedicamento,
            medida: medida,
            horario: hora,
            status: 'PENDENTE',
          ),
        );
      }
    }

    // Aplica o cache estático para preservar TOMADO e ADIADO ao atualizar
    for (final item in [...ativas]) {
      final chave = _chaveDose(item);
      if (_chavesTomadasCache.contains(chave)) {
        item.status = 'TOMADO';
        ativas.remove(item);
        final jaEmTomadas = tomadas.any((t) => _chaveDose(t) == chave);
        if (!jaEmTomadas) {
          tomadas.add(item);
        }
        continue;
      }
      final ajuste = _ajustesAtivosCache[chave];
      if (ajuste != null) {
        item.horario = ajuste.horario;
        item.status = ajuste.status;
      }
    }

    ativas.sort((a, b) => a.horario.compareTo(b.horario));
    tomadas.sort((a, b) => a.horario.compareTo(b.horario));

    if (!mounted) return;
    setState(() {
      _dosesAtivas = ativas;
      _dosesTomadas = tomadas;
      _carregando = false;
    });
  }

  Future<void> _marcarTomado(ItemDoseCuidador item, int index) async {
    try {
      if (item.doseId != null) {
        await _agendamentoService.confirmarDoseTomada(
          item.doseId!,
          observacao: 'Confirmado pelo cuidador ${widget.usuario.nome}',
        );
      }
      final chave = _chaveDose(item);
      _chavesTomadasCache.add(chave);
      _ajustesAtivosCache.remove(chave);

      if (!mounted) return;
      setState(() {
        item.status = 'TOMADO';
        _dosesAtivas.removeAt(index);
        _dosesTomadas.add(item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.nomeMedicamento} marcado como TOMADO (refletido ao paciente).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao confirmar dose no servidor: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _abrirOpcoesAdiar(ItemDoseCuidador item) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        Future<void> aplicarNovoHorario(String novoHorario, String rotulo) async {
          Navigator.pop(sheetCtx);
          try {
            if (item.agendamentoId != null) {
              final googleToken =
                  await AuthVinculoService.obterTokenGoogleAgenda();
              await _agendamentoService.atualizarAgendamento(
                item.agendamentoId!,
                AgendamentoModel(
                  id: item.agendamentoId,
                  nomeMedicamento: item.nomeMedicamento,
                  dosagem: item.medida,
                  horario: novoHorario,
                  ativo: true,
                ),
                googleToken: googleToken,
              );
            }
            final chaveAntiga = _chaveDose(item);
            _ajustesAtivosCache.remove(chaveAntiga);

            if (!mounted) return;
            setState(() {
              item.horario = novoHorario;
              item.status = 'ADIADO';
              _ajustesAtivosCache[_chaveDose(item)] = (
                horario: novoHorario,
                status: 'ADIADO',
              );
              _dosesAtivas.sort((a, b) => a.horario.compareTo(b.horario));
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${item.nomeMedicamento} adiado ($rotulo) para $novoHorario.',
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erro ao sincronizar novo horário: ${e.toString().replaceFirst('Exception: ', '')}',
                ),
              ),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adiar ${item.nomeMedicamento}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: _corPrimaria,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Horário atual: ${item.horario}',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corDestaque,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => aplicarNovoHorario(
                  _adicionarMinutos(item.horario, 15),
                  '15 min',
                ),
                child: const Text('Adiar em 15 minutos'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corDestaque,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => aplicarNovoHorario(
                  _adicionarMinutos(item.horario, 30),
                  '30 min',
                ),
                child: const Text('Adiar em 30 minutos'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corDestaque,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => aplicarNovoHorario(
                  _adicionarMinutos(item.horario, 60),
                  '1 hora',
                ),
                child: const Text('Adiar em 1 hora'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.schedule),
                label: const Text('Escolher horário personalizado'),
                onPressed: () async {
                  final partes = item.horario.split(':');
                  final inicial = TimeOfDay(
                    hour: (int.tryParse(partes.isNotEmpty ? partes[0] : '8') ??
                            8)
                        .clamp(0, 23),
                    minute:
                        (int.tryParse(partes.length > 1 ? partes[1] : '0') ??
                                0)
                            .clamp(0, 59),
                  );
                  final escolhido = await showTimePicker(
                    context: sheetCtx,
                    initialTime: inicial,
                  );
                  if (escolhido == null || !sheetCtx.mounted) return;
                  await aplicarNovoHorario(
                    _formatarTimeOfDay(escolhido),
                    'horário personalizado',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirModalNovoRemedio() {
    final nomeController = TextEditingController();
    final medidaController = TextEditingController();
    bool usarComprimidos = true;
    TimeOfDay horarioSelecionado = const TimeOfDay(hour: 8, minute: 0);
    bool salvando = false;
    String? erroModal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final horaFormatada = _formatarTimeOfDay(horarioSelecionado);

            Future<void> salvar() async {
              final nome = nomeController.text.trim();
              final medidaRaw = medidaController.text.trim();

              if (nome.isEmpty) {
                setModalState(() => erroModal = 'Informe o nome do medicamento.');
                return;
              }
              if (medidaRaw.isEmpty) {
                setModalState(
                  () => erroModal = usarComprimidos
                      ? 'Informe a quantidade de comprimidos.'
                      : 'Informe a dose em mg.',
                );
                return;
              }

              setModalState(() {
                salvando = true;
                erroModal = null;
              });

              final medidaFormatada = _formatarMedida(
                medidaRaw,
                usarComprimidos: usarComprimidos,
              );

              try {
                final googleToken =
                    await AuthVinculoService.obterTokenGoogleAgenda();
                await _agendamentoService.criarAgendamento(
                  AgendamentoModel(
                    nomeMedicamento: nome,
                    dosagem: medidaFormatada,
                    horario: horaFormatada,
                    ativo: true,
                  ),
                  googleToken: googleToken,
                );

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);

                if (!mounted) return;
                await _carregarMedicacoesDoPaciente();
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$nome ($medidaFormatada) agendado para $horaFormatada e enviado para sincronização.',
                    ),
                  ),
                );
              } catch (e) {
                setModalState(() {
                  salvando = false;
                  erroModal = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Novo remédio para o paciente',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: _corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Salva no sistema (visível ao paciente) e sincroniza com o Google Agenda.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nomeController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Nome do medicamento',
                        hintText: 'Ex.: Losartana',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Comprimidos')),
                            selected: usarComprimidos,
                            onSelected: salvando
                                ? null
                                : (_) => setModalState(() {
                                      usarComprimidos = true;
                                      medidaController.clear();
                                    }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Dose (mg)')),
                            selected: !usarComprimidos,
                            onSelected: salvando
                                ? null
                                : (_) => setModalState(() {
                                      usarComprimidos = false;
                                      medidaController.clear();
                                    }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: medidaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: usarComprimidos
                            ? 'Comprimidos (somente número)'
                            : 'Dose em mg (somente número)',
                        hintText: usarComprimidos ? 'Ex.: 1 ou 0.5' : 'Ex.: 50',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(Icons.access_time, color: _corPrimaria),
                      title: const Text('Horário da dose'),
                      trailing: Text(
                        horaFormatada,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _corPrimaria,
                        ),
                      ),
                      onTap: salvando
                          ? null
                          : () async {
                              final escolhido = await showTimePicker(
                                context: sheetContext,
                                initialTime: horarioSelecionado,
                              );
                              if (escolhido != null) {
                                setModalState(() => horarioSelecionado = escolhido);
                              }
                            },
                    ),
                    if (erroModal != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        erroModal!,
                        style: TextStyle(
                          color: Theme.of(sheetContext).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corPrimaria,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: salvando ? null : salvar,
                      child: Text(
                        salvando ? 'Salvando...' : 'Salvar e sincronizar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sair() async {
    await _authService.sairGoogle();
    await SessionService.encerrarSessao();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _dosesAtivas.length + _dosesTomadas.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Painel do Cuidador',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Gerenciar vínculos',
            icon: const Icon(Icons.people_alt),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PainelVinculoView(usuario: widget.usuario),
                ),
              );
              if (mounted) {
                await _inicializarTela();
              }
            },
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _sair,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuidador: ${widget.usuario.nome}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_pacientesVinculados.length > 1)
                      DropdownButton<VinculoFamiliarModel>(
                        isExpanded: true,
                        value: _pacienteSelecionado,
                        items: _pacientesVinculados.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              'Paciente: ${v.paciente.nome} (ID ${v.paciente.id}) • Código: ${v.paciente.codigoVinculo}',
                            ),
                          );
                        }).toList(),
                        onChanged: (novo) async {
                          setState(() => _pacienteSelecionado = novo);
                          await _carregarMedicacoesDoPaciente();
                        },
                      )
                    else
                      Text(
                        _pacienteSelecionado != null
                            ? 'Paciente: ${_pacienteSelecionado!.paciente.nome} (ID ${_pacienteSelecionado!.paciente.id}) • Código ${_pacienteSelecionado!.paciente.codigoVinculo}'
                            : 'Nenhum paciente vinculado ainda',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _carregando
                          ? 'Sincronizando doses...'
                          : 'Doses de hoje: ${_dosesTomadas.length}/$total tomadas • Google Agenda ativo',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _corPrimaria,
                side: const BorderSide(color: _corPrimaria),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final nomesTomados = _dosesTomadas
                    .map((d) => '${d.nomeMedicamento} (${d.horario})')
                    .toList();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgendamentosDosesView(
                      nomesTomadosHoje: nomesTomados,
                    ),
                  ),
                );
                if (mounted) {
                  await _carregarMedicacoesDoPaciente();
                }
              },
              icon: const Icon(Icons.alarm),
              label: const Text('Horários e doses de hoje'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _erro != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_erro!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _carregarMedicacoesDoPaciente,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : _dosesAtivas.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhuma dose pendente ou adiada no momento.',
                                style: TextStyle(fontSize: 15),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _carregarMedicacoesDoPaciente,
                              child: ListView.separated(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: _dosesAtivas.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _dosesAtivas[index];
                                  final adiado = item.status == 'ADIADO';

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: adiado
                                            ? Colors.orange.shade400
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.horario,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: adiado
                                                    ? Colors.orange.shade800
                                                    : _corPrimaria,
                                              ),
                                            ),
                                            Chip(
                                              label: Text(item.status),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.nomeMedicamento,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Medida: ${item.medida}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade700,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    _marcarTomado(item, index),
                                                child: const Text('TOMADO'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.orange.shade800,
                                                ),
                                                onPressed: () =>
                                                    _abrirOpcoesAdiar(item),
                                                child: const Text('ADIADO'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo remédio'),
        onPressed: _abrirModalNovoRemedio,
      ),
    );
  }
}