import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario_model.dart';
import '../services/agendamento_dose_service.dart';
import '../services/session_service.dart';
import 'agendamentos_doses_view.dart';
import 'login_view.dart';
import 'painel_vinculo_view.dart';

class ItemDoseHome {
  final int? doseId;
  final int? agendamentoId;
  final String nomeMedicamento;
  String comprimidos;
  String horario;
  String status; // PENDENTE, ADIADO, TOMADO

  ItemDoseHome({
    this.doseId,
    this.agendamentoId,
    required this.nomeMedicamento,
    required this.comprimidos,
    required this.horario,
    this.status = 'PENDENTE',
  });

  String get chaveUnica =>
      '${agendamentoId ?? 'sem_id'}_${nomeMedicamento.toLowerCase()}_$horario';
}

class HomePacienteView extends StatefulWidget {
  final UsuarioModel usuario;

  const HomePacienteView({super.key, required this.usuario});

  @override
  State<HomePacienteView> createState() => _HomePacienteViewState();
}

class _HomePacienteViewState extends State<HomePacienteView> {
  static const Color _corPrimaria = Color(0xFF0F4C81);

  // Cache estático em memória para preservar TOMADO e ADIADO ao voltar de outras telas
  static final Map<String, ({String status, String horario})>
      _ajustesRecentes = {};

  final AgendamentoDoseService _agendamentoService = AgendamentoDoseService();

  bool _carregando = true;
  String? _erroConexao;
  List<ItemDoseHome> _itensAtivosHome = [];
  List<ItemDoseHome> _historicoTomados = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosHome();
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
    } else {
      return '$textoNum mg';
    }
  }

  Future<void> _carregarDadosHome() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erroConexao = null;
    });

    List<RegistroDoseModel> doses = [];
    List<AgendamentoModel> agendamentos = [];

    try {
      doses = await _agendamentoService.listarDosesHoje();
    } catch (_) {}

    try {
      agendamentos = await _agendamentoService.listarAgendamentos();
    } catch (_) {
      if (doses.isEmpty && _itensAtivosHome.isEmpty && _ajustesRecentes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _erroConexao =
              'Não foi possível carregar seus remédios agora. Confira a conexão com o servidor.';
          _carregando = false;
        });
        return;
      }
    }

    final List<ItemDoseHome> ativos = [];
    final List<ItemDoseHome> tomados = [];

    for (final dose in doses) {
      final horaApi = _formatarHoraCurta(dose.agendamento.horario);
      final qtd = (dose.agendamento.dosagem != null &&
              dose.agendamento.dosagem!.trim().isNotEmpty)
          ? dose.agendamento.dosagem!.trim()
          : '1 comprimido';

      final chaveBase =
          '${dose.agendamento.id ?? 'sem_id'}_${dose.agendamento.nomeMedicamento.toLowerCase()}_$horaApi';
      final ajuste = _ajustesRecentes[chaveBase];

      final statusFinal = ajuste?.status ?? dose.status.toUpperCase();
      final horarioFinal = ajuste?.horario ?? horaApi;

      final item = ItemDoseHome(
        doseId: dose.id,
        agendamentoId: dose.agendamento.id,
        nomeMedicamento: dose.agendamento.nomeMedicamento,
        comprimidos: qtd,
        horario: horarioFinal,
        status: statusFinal,
      );

      if (item.status == 'TOMADO') {
        tomados.add(item);
      } else {
        ativos.add(item);
      }
    }

    for (final ag in agendamentos) {
      if (!ag.ativo) continue;
      final horaApi = _formatarHoraCurta(ag.horario);
      final qtd = (ag.dosagem != null && ag.dosagem!.trim().isNotEmpty)
          ? ag.dosagem!.trim()
          : '1 comprimido';

      final chaveBase =
          '${ag.id ?? 'sem_id'}_${ag.nomeMedicamento.toLowerCase()}_$horaApi';
      final ajuste = _ajustesRecentes[chaveBase];
      final statusFinal = ajuste?.status ?? 'PENDENTE';
      final horarioFinal = ajuste?.horario ?? horaApi;

      final jaExisteEmAtivos = ativos.any(
        (i) =>
            (ag.id != null && i.agendamentoId == ag.id) ||
            (i.nomeMedicamento.toLowerCase() ==
                    ag.nomeMedicamento.toLowerCase() &&
                i.horario == horarioFinal),
      );
      final jaExisteEmTomados = tomados.any(
        (i) =>
            (ag.id != null && i.agendamentoId == ag.id) ||
            (i.nomeMedicamento.toLowerCase() ==
                    ag.nomeMedicamento.toLowerCase() &&
                i.horario == horarioFinal),
      );

      if (!jaExisteEmAtivos && !jaExisteEmTomados) {
        final item = ItemDoseHome(
          agendamentoId: ag.id,
          nomeMedicamento: ag.nomeMedicamento,
          comprimidos: qtd,
          horario: horarioFinal,
          status: statusFinal,
        );
        if (statusFinal == 'TOMADO') {
          tomados.add(item);
        } else {
          ativos.add(item);
        }
      }
    }

    ativos.sort((a, b) => a.horario.compareTo(b.horario));
    tomados.sort((a, b) => a.horario.compareTo(b.horario));

    if (!mounted) return;
    setState(() {
      _itensAtivosHome = ativos;
      _historicoTomados = tomados;
      _carregando = false;
    });
  }

  Future<void> _marcarTomado(ItemDoseHome item, int index) async {
    final chave = item.chaveUnica;
    try {
      if (item.doseId != null) {
        await _agendamentoService.confirmarDoseTomada(item.doseId!);
      }
    } catch (_) {}

    if (!mounted) return;
    _ajustesRecentes[chave] = (status: 'TOMADO', horario: item.horario);

    setState(() {
      item.status = 'TOMADO';
      _itensAtivosHome.removeAt(index);
      _historicoTomados.add(item);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.nomeMedicamento} marcado como TOMADO e movido para o histórico.',
        ),
      ),
    );
  }

  Future<void> _abrirOpcoesAdiar(ItemDoseHome item) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        void aplicarNovoHorario(String novoHorario, String descricao) {
          final chave = item.chaveUnica;
          _ajustesRecentes[chave] = (status: 'ADIADO', horario: novoHorario);

          setState(() {
            item.horario = novoHorario;
            item.status = 'ADIADO';
            _itensAtivosHome.sort((a, b) => a.horario.compareTo(b.horario));
          });

          Navigator.pop(sheetCtx);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${item.nomeMedicamento} adiado ($descricao) para às $novoHorario.',
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adiar ${item.nomeMedicamento}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _corPrimaria,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Horário atual: ${item.horario}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corPrimaria,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => aplicarNovoHorario(
                  _adicionarMinutos(item.horario, 15),
                  'em 15 minutos',
                ),
                child: const Text(
                  'Adiar em 15 minutos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corPrimaria,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => aplicarNovoHorario(
                  _adicionarMinutos(item.horario, 30),
                  'em 30 minutos',
                ),
                child: const Text(
                  'Adiar em 30 minutos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corPrimaria,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => aplicarNovoHorario(
                  _adicionarMinutos(item.horario, 60),
                  'em 1 hora',
                ),
                child: const Text(
                  'Adiar em 1 hora',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _corPrimaria,
                  side: const BorderSide(color: _corPrimaria, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.schedule, size: 22),
                label: const Text(
                  'Horário personalizado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final partes = item.horario.split(':');
                  final horaInicial = TimeOfDay(
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
                    initialTime: horaInicial,
                  );
                  if (escolhido == null || !sheetCtx.mounted) return;
                  final horaFormatada = _formatarTimeOfDay(escolhido);
                  aplicarNovoHorario(
                    horaFormatada,
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

  Future<void> _fazerLogout() async {
    _ajustesRecentes.clear();
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
    final valorMedidaController = TextEditingController();
    bool usarComprimidos = true;
    TimeOfDay horarioSelecionado = const TimeOfDay(hour: 8, minute: 0);
    bool salvando = false;
    String? erroModal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final horarioFormatado = _formatarTimeOfDay(horarioSelecionado);

            Future<void> salvarNoServidor() async {
              final nome = nomeController.text.trim();
              final medidaTexto = valorMedidaController.text.trim();

              if (nome.isEmpty) {
                setModalState(() {
                  erroModal = 'Digite o nome do remédio.';
                });
                return;
              }

              if (medidaTexto.isEmpty) {
                setModalState(() {
                  erroModal = usarComprimidos
                      ? 'Digite a quantidade de comprimidos.'
                      : 'Digite a dose em mg.';
                });
                return;
              }

              setModalState(() {
                salvando = true;
                erroModal = null;
              });

              final medidaFinal = _formatarMedida(
                medidaTexto,
                usarComprimidos: usarComprimidos,
              );

              try {
                await _agendamentoService.criarAgendamento(
                  AgendamentoModel(
                    nomeMedicamento: nome,
                    dosagem: medidaFinal,
                    horario: horarioFormatado,
                    ativo: true,
                  ),
                );

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);

                if (!mounted) return;
                await _carregarDadosHome();
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$nome adicionado para hoje às $horarioFormatado.',
                    ),
                  ),
                );
              } on ApiException catch (e) {
                setModalState(() {
                  salvando = false;
                  erroModal = e.message;
                });
              } catch (_) {
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (!mounted) return;
                setState(() {
                  _itensAtivosHome.add(
                    ItemDoseHome(
                      nomeMedicamento: nome,
                      comprimidos: medidaFinal,
                      horario: horarioFormatado,
                      status: 'PENDENTE',
                    ),
                  );
                  _itensAtivosHome.sort(
                    (a, b) => a.horario.compareTo(b.horario),
                  );
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Novo remédio',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ele aparece aqui e em horários e doses de hoje.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nomeController,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 19),
                      decoration: InputDecoration(
                        labelText: 'Nome do remédio',
                        hintText: 'Ex.: Losartana',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Como deseja informar?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text(
                                'Comprimidos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            selected: usarComprimidos,
                            onSelected: salvando
                                ? null
                                : (_) {
                                    setModalState(() {
                                      usarComprimidos = true;
                                      valorMedidaController.clear();
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text(
                                'Dose (mg)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            selected: !usarComprimidos,
                            onSelected: salvando
                                ? null
                                : (_) {
                                    setModalState(() {
                                      usarComprimidos = false;
                                      valorMedidaController.clear();
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valorMedidaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: const TextStyle(fontSize: 19),
                      decoration: InputDecoration(
                        labelText: usarComprimidos
                            ? 'Quantidade de comprimidos (somente número)'
                            : 'Dose em mg (somente número)',
                        hintText: usarComprimidos ? 'Ex.: 1 ou 2' : 'Ex.: 50',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: salvando
                          ? null
                          : () async {
                              final escolhido = await showTimePicker(
                                context: sheetContext,
                                initialTime: horarioSelecionado,
                              );
                              if (escolhido != null) {
                                setModalState(
                                  () => horarioSelecionado = escolhido,
                                );
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Que horas tomar?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: _corPrimaria,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  horarioFormatado,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _corPrimaria,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (erroModal != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        erroModal!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(sheetContext).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _corPrimaria,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: salvando ? null : salvarNoServidor,
                      child: Text(
                        salvando ? 'Salvando...' : 'Salvar remédio',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final totalHoje = _itensAtivosHome.length + _historicoTomados.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          'Meus remédios',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, size: 26),
            tooltip: 'Família e cuidadores',
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
            icon: const Icon(Icons.logout, size: 26),
            tooltip: 'Sair da conta',
            onPressed: _fazerLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Olá, ${widget.usuario.nome}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _carregando
                  ? 'Carregando seus remédios de hoje...'
                  : totalHoje == 0
                      ? 'Nenhum remédio programado para hoje.'
                      : 'Tomados hoje: ${_historicoTomados.length} de $totalHoje.',
              style: const TextStyle(fontSize: 17, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _corPrimaria,
                elevation: 0,
                side: const BorderSide(color: _corPrimaria, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final List<String> nomesTomados = _historicoTomados
                    .map((t) => '${t.nomeMedicamento} (${t.horario})')
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
                  _carregarDadosHome();
                }
              },
              icon: const Icon(Icons.alarm, size: 24),
              label: const Text(
                'Horários e doses de hoje',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _erroConexao != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _erroConexao!,
                                style: const TextStyle(fontSize: 17),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _carregarDadosHome,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : _itensAtivosHome.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 72,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Tudo certo por aqui hoje!',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Toque em "+ Novo remédio" para adicionar um horário.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _carregarDadosHome,
                              child: ListView.separated(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: _itensAtivosHome.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _itensAtivosHome[index];
                                  final adiado = item.status == 'ADIADO';

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: adiado
                                            ? Colors.orange.shade400
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: adiado
                                                    ? Colors.orange.shade50
                                                    : const Color(0xFFE3F0FA),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                item.horario,
                                                style: TextStyle(
                                                  fontSize: 21,
                                                  fontWeight: FontWeight.bold,
                                                  color: adiado
                                                      ? Colors.orange.shade900
                                                      : _corPrimaria,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.nomeMedicamento,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Comprimidos: ${item.comprimidos}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  if (adiado) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Adiado para ${item.horario}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .orange.shade800,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _marcarTomado(item, index),
                                                child: const Text(
                                                  'TOMADO',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.orange.shade800,
                                                  side: BorderSide(
                                                    color:
                                                        Colors.orange.shade700,
                                                    width: 1.5,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _abrirOpcoesAdiar(item),
                                                child: const Text(
                                                  'ADIADO',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
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
        onPressed: _abrirFormularioNovoRemedio,
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Novo remédio',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}