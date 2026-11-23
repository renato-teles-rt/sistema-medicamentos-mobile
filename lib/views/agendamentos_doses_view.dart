import 'package:flutter/material.dart';
import '../services/agendamento_dose_service.dart';

class AgendamentosDosesView extends StatefulWidget {
  final List<String> nomesTomadosHoje;

  const AgendamentosDosesView({
    super.key,
    this.nomesTomadosHoje = const [],
  });

  @override
  State<AgendamentosDosesView> createState() => _AgendamentosDosesViewState();
}

class _ConfiguracaoAlarme {
  final int? agendamentoId;
  final String nomeMedicamento;
  final String? dosagem;
  String horario;
  String? horarioPreAviso;
  bool recorrente;
  List<int> diasSemana;
  bool ativo;

  _ConfiguracaoAlarme({
    this.agendamentoId,
    required this.nomeMedicamento,
    this.dosagem,
    required this.horario,
    this.horarioPreAviso,
    this.recorrente = true,
    List<int>? diasSemana,
    this.ativo = true,
  }) : diasSemana = diasSemana ?? [1, 2, 3, 4, 5, 6, 7];
}

class _AgendamentosDosesViewState extends State<AgendamentosDosesView> {
  static const Color _corPrimaria = Color(0xFF0F4C81);

  static const Map<int, String> _nomesDiasCurtos = {
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  final AgendamentoDoseService _service = AgendamentoDoseService();

  bool _carregando = true;
  String? _erro;
  List<RegistroDoseModel> _dosesPendentesHoje = [];
  List<String> _historicoHoje = [];
  List<_ConfiguracaoAlarme> _alarmesAtivos = [];

  @override
  void initState() {
    super.initState();
    try {
      _historicoHoje = List<String>.from(widget.nomesTomadosHoje);
    } catch (_) {
      _historicoHoje = [];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarTudo();
    });
  }

  String _formatarHoraCurta(String? hora) {
    try {
      if (hora == null || hora.trim().isEmpty) return '--:--';
      final partes = hora.trim().split(':');
      if (partes.length >= 2) {
        return '${partes[0].padLeft(2, '0')}:${partes[1].padLeft(2, '0')}';
      }
      return hora.trim();
    } catch (_) {
      return '--:--';
    }
  }

  String _calcularPreAvisoCincoMin(String horarioHhMm) {
    try {
      final partes = horarioHhMm.split(':');
      if (partes.length < 2) return '--:--';
      final h = int.tryParse(partes[0]) ?? 0;
      final m = int.tryParse(partes[1]) ?? 0;
      final totalMinutos =
          ((h * 60 + m - 5) % (24 * 60) + (24 * 60)) % (24 * 60);
      final preH = (totalMinutos ~/ 60).toString().padLeft(2, '0');
      final preM = (totalMinutos % 60).toString().padLeft(2, '0');
      return '$preH:$preM';
    } catch (_) {
      return '--:--';
    }
  }

  String _resumoFrequencia(_ConfiguracaoAlarme alarme) {
    try {
      if (!alarme.recorrente) {
        return 'Somente 1 vez';
      }
      if (alarme.diasSemana.length == 7) {
        return 'Todos os dias';
      }
      final ordenados = [...alarme.diasSemana]..sort();
      if (ordenados.isEmpty) return 'Recorrente';
      return ordenados.map((d) => _nomesDiasCurtos[d] ?? '').join(', ');
    } catch (_) {
      return 'Todos os dias';
    }
  }

  Future<void> _carregarTudo() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    List<RegistroDoseModel> dosesApi = [];
    List<AgendamentoModel> agendamentosApi = [];
    String? mensagemErro;

    try {
      dosesApi = await _service.listarDosesHoje();
    } on ApiException catch (e) {
      mensagemErro = e.message;
    } catch (e) {
      mensagemErro = 'Falha ao buscar doses de hoje: $e';
    }

    try {
      agendamentosApi = await _service.listarAgendamentos();
      mensagemErro = null;
    } on ApiException catch (e) {
      if (dosesApi.isEmpty) mensagemErro = e.message;
    } catch (e) {
      if (dosesApi.isEmpty) {
        mensagemErro =
            'Não foi possível conectar ao servidor (${AgendamentoDoseService.baseUrl}). Detalhe: $e';
      }
    }

    try {
      final List<RegistroDoseModel> pendentes = [];
      final Set<String> historicoSet = {..._historicoHoje};

      for (final dose in dosesApi) {
        try {
          final hora = _formatarHoraCurta(dose.agendamento.horario);
          final nome = dose.agendamento.nomeMedicamento;
          final rotulo = '$nome ($hora)';
          if (dose.status.toUpperCase() == 'TOMADO') {
            historicoSet.add(rotulo);
          } else {
            pendentes.add(dose);
          }
        } catch (_) {}
      }

      final List<_ConfiguracaoAlarme> mapeados = [];
      for (final ag in agendamentosApi) {
        try {
          final horaCurta = _formatarHoraCurta(ag.horario);
          mapeados.add(
            _ConfiguracaoAlarme(
              agendamentoId: ag.id,
              nomeMedicamento: ag.nomeMedicamento,
              dosagem: ag.dosagem,
              horario: horaCurta,
              horarioPreAviso: ag.horarioPreAviso != null
                  ? _formatarHoraCurta(ag.horarioPreAviso)
                  : _calcularPreAvisoCincoMin(horaCurta),
              ativo: ag.ativo,
            ),
          );
        } catch (_) {}
      }

      for (final anterior in _alarmesAtivos) {
        try {
          final jaExiste = mapeados.any(
            (m) =>
                m.nomeMedicamento.toLowerCase() ==
                    anterior.nomeMedicamento.toLowerCase() &&
                m.horario == anterior.horario,
          );
          if (!jaExiste) {
            mapeados.add(anterior);
          }
        } catch (_) {}
      }

      mapeados.sort((a, b) => a.horario.compareTo(b.horario));

      if (!mounted) return;
      setState(() {
        _dosesPendentesHoje = pendentes;
        _historicoHoje = historicoSet.toList();
        _alarmesAtivos = mapeados;
        _erro = (mensagemErro != null && mapeados.isEmpty && pendentes.isEmpty)
            ? mensagemErro
            : null;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao montar a tela de horários: $e';
        _carregando = false;
      });
    }
  }

  Future<void> _confirmarTomada(RegistroDoseModel dose, int index) async {
    try {
      final hora = _formatarHoraCurta(dose.agendamento.horario);
      final registroHistorico = '${dose.agendamento.nomeMedicamento} ($hora)';

      try {
        await _service.confirmarDoseTomada(dose.id);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _dosesPendentesHoje.removeAt(index);
        if (!_historicoHoje.contains(registroHistorico)) {
          _historicoHoje.add(registroHistorico);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${dose.agendamento.nomeMedicamento} marcado como TOMADO e enviado ao histórico.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível confirmar: $e')),
      );
    }
  }

  TimeOfDay _parseTimeOfDay(String horaHhMm) {
    try {
      final partes = horaHhMm.split(':');
      final h = int.tryParse(partes.isNotEmpty ? partes[0] : '8') ?? 8;
      final m = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  String _formatarTimeOfDay(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _abrirModalEditarAlarme(_ConfiguracaoAlarme alarme) async {
    try {
      TimeOfDay horaEditada = _parseTimeOfDay(alarme.horario);
      bool recorrenteEditado = alarme.recorrente;
      final List<int> diasEditados = [...alarme.diasSemana];
      String? erroModal;

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              final novaHoraTexto = _formatarTimeOfDay(horaEditada);
              final novoPreAviso = _calcularPreAvisoCincoMin(novaHoraTexto);

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Editar horário • ${alarme.nomeMedicamento}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () async {
                          final escolhido = await showTimePicker(
                            context: ctx,
                            initialTime: horaEditada,
                          );
                          if (escolhido != null) {
                            setModalState(() => horaEditada = escolhido);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Novo horário',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                novaHoraTexto,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _corPrimaria,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lembrete às $novoPreAviso (5 min antes).',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Recorrente')),
                              selected: recorrenteEditado,
                              onSelected: (_) => setModalState(
                                () => recorrenteEditado = true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Somente 1 vez')),
                              selected: !recorrenteEditado,
                              onSelected: (_) => setModalState(
                                () => recorrenteEditado = false,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (recorrenteEditado) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _nomesDiasCurtos.entries.map((e) {
                            final marcado = diasEditados.contains(e.key);
                            return FilterChip(
                              label: Text(e.value),
                              selected: marcado,
                              onSelected: (_) {
                                setModalState(() {
                                  if (marcado) {
                                    diasEditados.remove(e.key);
                                  } else {
                                    diasEditados.add(e.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (erroModal != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          erroModal!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: _corPrimaria),
                    onPressed: () {
                      if (recorrenteEditado && diasEditados.isEmpty) {
                        setModalState(() {
                          erroModal = 'Escolha pelo menos um dia.';
                        });
                        return;
                      }
                      setState(() {
                        alarme.horario = novaHoraTexto;
                        alarme.horarioPreAviso = novoPreAviso;
                        alarme.recorrente = recorrenteEditado;
                        alarme.diasSemana = recorrenteEditado
                            ? ([...diasEditados]..sort())
                            : [];
                        _alarmesAtivos
                            .sort((a, b) => a.horario.compareTo(b.horario));
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (_) {}
  }

  Future<void> _abrirModalNovoAgendamento() async {
    try {
      final nomeController = TextEditingController();
      final dosagemController = TextEditingController();
      final List<TimeOfDay> horariosSelecionados = [
        const TimeOfDay(hour: 8, minute: 0),
      ];
      bool recorrente = true;
      final List<int> diasSelecionados = [1, 2, 3, 4, 5, 6, 7];
      String? erroModal;
      bool salvando = false;

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              Future<void> adicionarOutroHorario() async {
                final ultimo = horariosSelecionados.last;
                final escolhido = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay(
                    hour: (ultimo.hour + 8) % 24,
                    minute: ultimo.minute,
                  ),
                );
                if (escolhido != null) {
                  final texto = _formatarTimeOfDay(escolhido);
                  final repetido = horariosSelecionados.any(
                    (h) => _formatarTimeOfDay(h) == texto,
                  );
                  setModalState(() {
                    if (!repetido) {
                      horariosSelecionados.add(escolhido);
                      erroModal = null;
                    } else {
                      erroModal = 'Esse horário já está na lista.';
                    }
                  });
                }
              }

              Future<void> salvar() async {
                final nome = nomeController.text.trim();
                if (nome.isEmpty) {
                  setModalState(() => erroModal = 'Digite o nome do remédio.');
                  return;
                }
                if (recorrente && diasSelecionados.isEmpty) {
                  setModalState(() => erroModal = 'Escolha ao menos um dia.');
                  return;
                }

                setModalState(() {
                  salvando = true;
                  erroModal = null;
                });

                final dosagemLimpa = dosagemController.text.trim().isEmpty
                    ? null
                    : dosagemController.text.trim();

                for (final tod in horariosSelecionados) {
                  final hTexto = _formatarTimeOfDay(tod);
                  try {
                    await _service.criarAgendamento(
                      AgendamentoModel(
                        nomeMedicamento: nome,
                        dosagem: dosagemLimpa,
                        horario: hTexto,
                        ativo: true,
                      ),
                    );
                  } catch (_) {}
                  _alarmesAtivos.add(
                    _ConfiguracaoAlarme(
                      nomeMedicamento: nome,
                      dosagem: dosagemLimpa,
                      horario: hTexto,
                      horarioPreAviso: _calcularPreAvisoCincoMin(hTexto),
                      recorrente: recorrente,
                      diasSemana:
                          recorrente ? ([...diasSelecionados]..sort()) : [],
                    ),
                  );
                }

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                await _carregarTudo();
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  'Novo horário',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nomeController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Nome do remédio',
                          hintText: 'Ex.: Losartana',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dosagemController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Comprimidos ou dose (opcional)',
                          hintText: 'Ex.: 1 comprimido ou 50 mg',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(horariosSelecionados.length, (idx) {
                        final tod = horariosSelecionados[idx];
                        final hTexto = _formatarTimeOfDay(tod);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final escolhido = await showTimePicker(
                                      context: ctx,
                                      initialTime: tod,
                                    );
                                    if (escolhido != null) {
                                      setModalState(
                                        () => horariosSelecionados[idx] =
                                            escolhido,
                                      );
                                    }
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hTexto,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _corPrimaria,
                                        ),
                                      ),
                                      Text(
                                        'Lembrete às ${_calcularPreAvisoCincoMin(hTexto)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (horariosSelecionados.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setModalState(
                                    () => horariosSelecionados.removeAt(idx),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: adicionarOutroHorario,
                        icon: const Icon(Icons.add_alarm),
                        label: const Text('Adicionar outro horário'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Recorrente')),
                              selected: recorrente,
                              onSelected: (_) =>
                                  setModalState(() => recorrente = true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Somente 1 vez')),
                              selected: !recorrente,
                              onSelected: (_) =>
                                  setModalState(() => recorrente = false),
                            ),
                          ),
                        ],
                      ),
                      if (recorrente) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _nomesDiasCurtos.entries.map((e) {
                            final marcado = diasSelecionados.contains(e.key);
                            return FilterChip(
                              label: Text(e.value),
                              selected: marcado,
                              onSelected: (_) {
                                setModalState(() {
                                  if (marcado) {
                                    diasSelecionados.remove(e.key);
                                  } else {
                                    diasSelecionados.add(e.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (erroModal != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          erroModal!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: salvando ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: _corPrimaria),
                    onPressed: salvando ? null : salvar,
                    child: Text(salvando ? 'Salvando...' : 'Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        appBar: AppBar(
          backgroundColor: _corPrimaria,
          foregroundColor: Colors.white,
          title: const Text(
            'Horários e doses de hoje',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: _carregando ? null : _carregarTudo,
              icon: const Icon(Icons.refresh, size: 26),
              tooltip: 'Atualizar',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _abrirModalNovoAgendamento,
          backgroundColor: _corPrimaria,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 14,
          ),
          icon: const Icon(Icons.add_alarm, size: 31),
          label: const Text(
            'Novo horário',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _erro!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _corPrimaria,
                            ),
                            onPressed: _carregarTudo,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carregarTudo,
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        const Text(
                          'Para tomar hoje',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_dosesPendentesHoje.isEmpty)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'Nenhuma dose pendente para hoje.',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                          )
                        else
                          ...List.generate(_dosesPendentesHoje.length, (idx) {
                            try {
                              final dose = _dosesPendentesHoje[idx];
                              final horaFormatada =
                                  _formatarHoraCurta(dose.agendamento.horario);
                              final preAviso =
                                  dose.agendamento.horarioPreAviso != null
                                      ? _formatarHoraCurta(
                                          dose.agendamento.horarioPreAviso,
                                        )
                                      : _calcularPreAvisoCincoMin(horaFormatada);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE3F0FA),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              horaFormatada,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: _corPrimaria,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dose.agendamento
                                                      .nomeMedicamento,
                                                  style: const TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (dose.agendamento.dosagem !=
                                                    null)
                                                  Text(
                                                    dose.agendamento.dosagem!,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                Text(
                                                  'Lembrete às $preAviso',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade700,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _confirmarTomada(dose, idx),
                                          child: const Text(
                                            'TOMADO',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } catch (_) {
                              return const SizedBox.shrink();
                            }
                          }),
                        const SizedBox(height: 20),
                        const Text(
                          'Meus horários ativos (editar aqui)',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_alarmesAtivos.isEmpty)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'Nenhum horário cadastrado ainda.',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                          )
                        else
                          ..._alarmesAtivos.map((alarme) {
                            try {
                              final preAviso = alarme.horarioPreAviso ??
                                  _calcularPreAvisoCincoMin(alarme.horario);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${alarme.nomeMedicamento} • ${alarme.horario}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (alarme.dosagem != null)
                                                  alarme.dosagem!,
                                                'Lembrete às $preAviso',
                                              ].join(' • '),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              _resumoFrequencia(alarme),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _corPrimaria,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 40,
                                          maxWidth: 110,
                                        ),
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _abrirModalEditarAlarme(alarme),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit, size: 16),
                                              SizedBox(width: 4),
                                              Text('Editar'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } catch (_) {
                              return const SizedBox.shrink();
                            }
                          }),
                        const SizedBox(height: 20),
                        const Text(
                          'Histórico de hoje (tomados)',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_historicoHoje.isEmpty)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Nenhuma dose tomada hoje ainda.',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          )
                        else
                          ..._historicoHoje.map(
                            (registro) => Card(
                              color: Colors.green.shade50,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                ),
                                title: Text(
                                  registro,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text('Tomado hoje'),
                              ),
                            ),
                          ),
                        const SizedBox(height: 84),
                      ],
                    ),
                  ),
      );
    } catch (e) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        appBar: AppBar(
          backgroundColor: _corPrimaria,
          foregroundColor: Colors.white,
          title: const Text('Horários e doses de hoje'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ocorreu um erro ao exibir a tela: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _corPrimaria),
                  onPressed: _carregarTudo,
                  child: const Text('Recarregar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}