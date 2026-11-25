import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medicamento_model.dart';
import '../models/usuario_model.dart';
import '../services/medicamento_service.dart';
import '../services/session_service.dart';
import 'login_view.dart';
import 'painel_vinculo_view.dart';

class HomePacienteView extends StatefulWidget {
  final UsuarioModel usuario;

  const HomePacienteView({super.key, required this.usuario});

  @override
  State<HomePacienteView> createState() => _HomePacienteViewState();
}

class _HomePacienteViewState extends State<HomePacienteView> {
  static const Color _corPrimaria = Color(0xFF0F4C81);

  final MedicamentoService _medicamentoService = MedicamentoService();
  final TextEditingController _buscaController = TextEditingController();

  List<MedicamentoModel> _medicamentos = [];
  bool _carregando = true;
  String _filtro = '';
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _carregarCatalogo();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarCatalogo() async {
    final lista = await _medicamentoService.listar(widget.usuario.id);
    if (!mounted) return;
    setState(() {
      _medicamentos = lista;
      _carregando = false;
    });
    // Tenta buscar a versão do backend em segundo plano. Sem rede (ou sem o
    // endpoint publicado) o catálogo local continua valendo — nada quebra.
    _sincronizarEmSegundoPlano();
  }

  Future<void> _sincronizarEmSegundoPlano() async {
    if (_sincronizando) return;
    _sincronizando = true;
    try {
      final remotos = await _medicamentoService.sincronizar(widget.usuario.id);
      if (!mounted) return;
      // Proteção contra perda de dados: se o backend responder vazio enquanto
      // o paciente tem itens salvos localmente (ex.: endpoint recém-publicado
      // ou usuário criado só no aparelho), mantemos o catálogo local.
      if (remotos.isEmpty && _medicamentos.isNotEmpty) return;
      // Só re-renderiza quando a sincronização trouxe algo diferente do que já
      // está na tela, para não piscar a lista nem perder o foco da busca.
      if (_assinatura(remotos) != _assinatura(_medicamentos)) {
        setState(() => _medicamentos = remotos);
      }
    } finally {
      _sincronizando = false;
    }
  }

  /// Identifica o conteúdo do catálogo (nome + estoque + horário) para
  /// comparar o resultado do backend com o que já está renderezado.
  String _assinatura(List<MedicamentoModel> itens) => itens
      .map((m) => '${m.id}|${m.nome}|${m.dosagem}|${m.horario}|${m.quantidadeTotal}')
      .join(';');

  Future<void> _fazerLogout() async {
    await SessionService.encerrarSessao();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  List<MedicamentoModel> get _medicamentosFiltrados {
    final termo = _filtro.trim().toLowerCase();
    if (termo.isEmpty) return _medicamentos;
    return _medicamentos
        .where(
          (m) =>
              m.nome.toLowerCase().contains(termo) ||
              m.dosagem.toLowerCase().contains(termo),
        )
        .toList();
  }

  int get _totalEmAlerta => _medicamentos.where((m) => m.estoqueBaixo).length;

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------------------------------------------------------------------
  // Cadastro / edição
  // ---------------------------------------------------------------------------

  void _abrirFormulario([MedicamentoModel? existente]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormularioMedicamento(
        medicamento: existente,
        existentes: _medicamentos,
        onSalvar: (medicamento) async {
          if (existente == null) {
            await _medicamentoService.adicionar(widget.usuario.id, medicamento);
          } else {
            await _medicamentoService.atualizar(widget.usuario.id, medicamento);
          }
          await _carregarCatalogo();
          if (mounted && medicamento.estoqueBaixo) {
            _mostrarMensagem(
              '${medicamento.nome} cadastrado com estoque baixo!',
            );
          }
        },
      ),
    );
  }

  Future<void> _remover(MedicamentoModel medicamento) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover medicamento'),
        content: Text(
          'Deseja realmente remover ${medicamento.nome} do catálogo?',
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
            child: const Text('Remover', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _medicamentoService.remover(widget.usuario.id, medicamento.id);
    await _carregarCatalogo();
    if (mounted) _mostrarMensagem('${medicamento.nome} removido do catálogo.');
  }

  void _abrirReposicao(MedicamentoModel medicamento) {
    final controller = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Repor estoque de ${medicamento.nome}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(
            labelText: 'Quantidade recebida',
            hintText: 'Ex: 30',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              final adicionado = int.tryParse(controller.text.trim());
              if (adicionado == null || adicionado <= 0) return;

              await _medicamentoService.atualizar(
                widget.usuario.id,
                medicamento.copyWith(
                  quantidadeTotal: medicamento.quantidadeTotal + adicionado,
                ),
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              await _carregarCatalogo();
              if (mounted) {
                _mostrarMensagem(
                  'Estoque de ${medicamento.nome} atualizado (+$adicionado).',
                );
              }
            },
            child: const Text('Repor', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lista = _medicamentosFiltrados;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text('Catálogo de Medicações'),
        backgroundColor: _corPrimaria,
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
                  ? 'Cadastre seus remédios para acompanhar horários e estoque.'
                  : '${_medicamentos.length} medicamento(s) no catálogo.',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (_totalEmAlerta > 0) _construirAlertaEstoque(),
            if (!_carregando && _medicamentos.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _buscaController,
                style: const TextStyle(fontSize: 17),
                onChanged: (valor) => setState(() => _filtro = valor),
                decoration: InputDecoration(
                  labelText: 'Buscar medicamento',
                  hintText: 'Ex: Losartana',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filtro.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _buscaController.clear();
                            setState(() => _filtro = '');
                          },
                        ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _construirConteudo(lista),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: _corPrimaria,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Novo Remédio',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _construirAlertaEstoque() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade700, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 34,
            color: Colors.orange.shade900,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _totalEmAlerta == 1
                  ? '1 medicamento está com o estoque baixo. Reponha antes de acabar.'
                  : '$_totalEmAlerta medicamentos estão com o estoque baixo. Reponha antes de acabar.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirConteudo(List<MedicamentoModel> lista) {
    if (_medicamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 72, color: Colors.grey.shade400),
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
              'Toque em "Novo Remédio" para adicionar ao catálogo informando nome, dosagem e quantidade em estoque.',
              style: TextStyle(fontSize: 15, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (lista.isEmpty) {
      return Center(
        child: Text(
          'Nenhum medicamento encontrado para "$_filtro".',
          style: const TextStyle(fontSize: 17, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = lista[index];
        return _construirCartaoMedicamento(item);
      },
    );
  }

  Widget _construirCartaoMedicamento(MedicamentoModel item) {
    final bool alerta = item.estoqueBaixo;
    final bool esgotado = item.statusEstoque == StatusEstoque.esgotado;
    final Color corStatus = esgotado
        ? Colors.red.shade800
        : alerta
        ? Colors.orange.shade900
        : Colors.green.shade800;
    final Color corFundoStatus = esgotado
        ? Colors.red.shade50
        : alerta
        ? Colors.orange.shade50
        : Colors.green.shade50;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alerta ? corStatus : Colors.grey.shade300,
          width: alerta ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 20,
                      color: _corPrimaria,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.horario,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _corPrimaria,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.descricaoDose,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              // Em telas estreitas (celulares pequenos ou texto ampliado 50+),
              // o contador e o aviso ficam em linhas separadas para evitar
              // overflow horizontal.
              final empilhado = constraints.maxWidth < 420;
              final contador = _construirContadorEstoque(item);
              final aviso = _construirAvisoEstoque(item, corStatus, corFundoStatus);

              if (empilhado) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: contador),
                    const SizedBox(height: 10),
                    aviso,
                  ],
                );
              }

              return Row(
                children: [
                  contador,
                  const SizedBox(width: 12),
                  Expanded(child: aviso),
                ],
              );
            },
          ),
          if (item.observacao.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Obs.: ${item.observacao}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _abrirReposicao(item),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text(
                  'Repor',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(foregroundColor: _corPrimaria),
              ),
              TextButton.icon(
                onPressed: () => _abrirFormulario(item),
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Editar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                ),
              ),
              TextButton.icon(
                onPressed: () => _remover(item),
                icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                label: Text(
                  'Remover',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirAvisoEstoque(
    MedicamentoModel item,
    Color corStatus,
    Color corFundoStatus,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: corFundoStatus,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corStatus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.estoqueBaixo ? 'ALERTA DE ESTOQUE' : 'ESTOQUE OK',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: corStatus,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.mensagemStatus,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: corStatus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirContadorEstoque(MedicamentoModel item) {
    // O contador trabalha com unidades: reduz por dose e nunca abaixo de zero.
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: item.quantidadeTotal > 0 ? _corPrimaria : Colors.grey,
            tooltip:
                'Registrar dose tomada (-${item.quantidadePorDose} unidade(s))',
            onPressed: item.quantidadeTotal <= 0
                ? null
                : () async {
                    // O estoque nunca fica negativo: a última dose consome o
                    // que restar (ex.: 1 unidade em estoque com 3 por dose).
                    final restante = item.quantidadeTotal - item.quantidadePorDose;
                    await _medicamentoService.atualizar(
                      widget.usuario.id,
                      item.copyWith(
                        quantidadeTotal: restante < 0 ? 0 : restante,
                      ),
                    );
                    await _carregarCatalogo();
                    if (mounted &&
                        item.quantidadeTotal <= item.quantidadePorDose) {
                      _mostrarMensagem(
                        '${item.nome} zerou o estoque. Reponha as unidades.',
                      );
                    }
                  },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Text(
                  '${item.quantidadeTotal}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'em estoque',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: _corPrimaria,
            tooltip: 'Adicionar 1 unidade ao estoque',
            onPressed: () async {
              await _medicamentoService.atualizar(
                widget.usuario.id,
                item.copyWith(quantidadeTotal: item.quantidadeTotal + 1),
              );
              await _carregarCatalogo();
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Formulário de cadastro/edição
// -----------------------------------------------------------------------------

class _FormularioMedicamento extends StatefulWidget {
  final MedicamentoModel? medicamento;
  final List<MedicamentoModel> existentes;
  final Future<void> Function(MedicamentoModel) onSalvar;

  const _FormularioMedicamento({
    required this.onSalvar,
    this.medicamento,
    this.existentes = const [],
  });

  @override
  State<_FormularioMedicamento> createState() => _FormularioMedicamentoState();
}

class _FormularioMedicamentoState extends State<_FormularioMedicamento> {
  static const Color _corPrimaria = Color(0xFF0F4C81);

  late final TextEditingController _nomeController;
  late final TextEditingController _dosagemController;
  late final TextEditingController _quantidadeController;
  late final TextEditingController _doseController;
  late final TextEditingController _observacaoController;
  late TimeOfDay _horarioSelecionado;

  final Map<String, String?> _erros = {};
  bool _salvando = false;

  bool get _editando => widget.medicamento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicamento;
    _nomeController = TextEditingController(text: m?.nome ?? '');
    _dosagemController = TextEditingController(text: m?.dosagem ?? '');
    _quantidadeController = TextEditingController(
      text: m?.quantidadeTotal.toString() ?? '',
    );
    _doseController = TextEditingController(
      text: (m?.quantidadePorDose ?? 1).toString(),
    );
    _observacaoController = TextEditingController(text: m?.observacao ?? '');
    _horarioSelecionado = _parseHorario(m?.horario);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dosagemController.dispose();
    _quantidadeController.dispose();
    _doseController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  TimeOfDay _parseHorario(String? horario) {
    if (horario == null) return const TimeOfDay(hour: 8, minute: 0);
    final partes = horario.split(':');
    if (partes.length != 2) return const TimeOfDay(hour: 8, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(partes[0]) ?? 8,
      minute: int.tryParse(partes[1]) ?? 0,
    );
  }

  String get _horarioFormatado {
    final h = _horarioSelecionado.hour.toString().padLeft(2, '0');
    final m = _horarioSelecionado.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Prévia em tempo real: quantos dias de tratamento o estoque cobre.
  String get _previsaoEstoque {
    final total = int.tryParse(_quantidadeController.text.trim());
    final porDose = int.tryParse(_doseController.text.trim()) ?? 0;
    if (total == null) return 'Informe a quantidade total em estoque.';
    if (total <= 0) return 'Sem unidades: o alerta de estoque ficará ativo.';
    if (porDose <= 0) return 'Informe a quantidade usada por dose.';

    final dias = total ~/ porDose;
    final alerta = dias <= MedicamentoModel.diasAlertaPadrao;
    final texto = dias == 0
        ? 'Dura menos de 1 dia.'
        : 'Dura cerca de $dias dia(s) com 1 dose por dia.';
    return alerta ? '$texto Estoque baixo!' : texto;
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    final dosagem = _dosagemController.text.trim();
    final quantidade = int.tryParse(_quantidadeController.text.trim());
    final porDose = int.tryParse(_doseController.text.trim());

    setState(() {
      _erros.clear();
      if (nome.isEmpty) {
        _erros['nome'] = 'Informe o nome do medicamento.';
      }
      if (_medicamentosComMesmoNome(nome)) {
        _erros['nome'] = 'Este medicamento já está no catálogo.';
      }
      if (dosagem.isEmpty) {
        _erros['dosagem'] = 'Informe a dosagem (ex: 50mg).';
      }
      if (quantidade == null || quantidade < 0) {
        _erros['quantidade'] = 'Quantidade total inválida.';
      }
      if (porDose == null || porDose <= 0) {
        _erros['dose'] = 'Uso por dose deve ser maior que zero.';
      }
    });

    if (_erros.isNotEmpty) return;

    setState(() => _salvando = true);

    final medicamento = MedicamentoModel(
      id:
          widget.medicamento?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      nome: nome,
      dosagem: dosagem,
      horario: _horarioFormatado,
      quantidadePorDose: porDose!,
      quantidadeTotal: quantidade!,
      diasAlerta:
          widget.medicamento?.diasAlerta ?? MedicamentoModel.diasAlertaPadrao,
      observacao: _observacaoController.text.trim(),
    );

    await widget.onSalvar(medicamento);
    if (mounted) Navigator.pop(context);
  }

  // Evita dois itens idênticos no catálogo, comparando nome + dosagem
  // (a mesma medicação pode aparecer em dosagens diferentes).
  bool _medicamentosComMesmoNome(String nome) {
    final nomeNormalizado = nome.toLowerCase();
    final dosagemNormalizada = _dosagemController.text.trim().toLowerCase();
    return widget.existentes.any(
      (m) =>
          m.id != widget.medicamento?.id &&
          m.nome.toLowerCase() == nomeNormalizado &&
          m.dosagem.toLowerCase() == dosagemNormalizada,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editando ? 'Editar Medicamento' : 'Cadastrar Medicamento',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _corPrimaria,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nomeController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Nome do remédio',
                hintText: 'Ex: Losartana',
                errorText: _erros['nome'],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dosagemController,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Dosagem',
                hintText: 'Ex: 50mg',
                errorText: _erros['dosagem'],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _doseController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 18),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Unid. por dose',
                      hintText: 'Ex: 1',
                      errorText: _erros['dose'],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantidadeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 18),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Total em estoque',
                      hintText: 'Ex: 30',
                      errorText: _erros['quantidade'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F0FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _previsaoEstoque,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _corPrimaria,
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final escolhido = await showTimePicker(
                  context: context,
                  initialTime: _horarioSelecionado,
                );
                if (escolhido != null) {
                  setState(() => _horarioSelecionado = escolhido);
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
                    const Expanded(
                      child: Text(
                        'Horário da dose:',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: _corPrimaria),
                        const SizedBox(width: 8),
                        Text(
                          _horarioFormatado,
                          style: const TextStyle(
                            fontSize: 20,
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
            const SizedBox(height: 16),
            TextField(
              controller: _observacaoController,
              style: const TextStyle(fontSize: 16),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                hintText: 'Ex: tomar após o almoço',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _editando ? 'Salvar Alterações' : 'Salvar Medicamento',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
