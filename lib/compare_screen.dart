import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'background.dart';
import 'adjust_smile_screen.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen>
    with SingleTickerProviderStateMixin {
  double _sliderValue = 0.5; // 0.0 = Original, 1.0 = Com IA
  final TextEditingController _notesController = TextEditingController();

  String? _originalPath;
  String? _processedPath;
  String? _selectedColor;
  String? _selectedShape;
  String? _simulationId;
  String? _simulationDate; // Guarda o timestamp exato (ISO8601 ou data) da simulacao
  String? _userEmail;

  bool _isInit = true;
  bool _idInicializado = false;
  bool _salvouAutomatico = false;
  bool _saindoPeloPopScope = false;

  OverlayEntry? _tipOverlayEntry;
  Timer? _tipDismissTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const String _kHideHistoryPdfTipKey = 'ocultar_aviso_historico';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<Box> _obterBoxSimulacoes() async {
    if (Hive.isBoxOpen('simulacoes')) {
      return Hive.box('simulacoes');
    }
    return await Hive.openBox('simulacoes');
  }

  Future<Box> _obterBoxUsuario() async {
    if (Hive.isBoxOpen('box_usuario')) {
      return Hive.box('box_usuario');
    }
    return await Hive.openBox('box_usuario');
  }

  // Incrementa estritamente de 1 em 1 (ex.: 110, 111, 112, 113, 114)
  Future<String> _gerarProximoIdSimulacao() async {
    final boxUser = await _obterBoxUsuario();
    final int ultimoId =
    (boxUser.get('ultimo_id_simulacao', defaultValue: 100) as int);
    final int proximoId = ultimoId < 100 ? 101 : ultimoId + 1;
    await boxUser.put('ultimo_id_simulacao', proximoId);
    return 'DS-$proximoId';
  }

  Future<void> _prepararNovoIdUnico() async {
    if (_idInicializado) return;
    _idInicializado = true;
    final novoId = await _gerarProximoIdSimulacao();
    if (mounted) {
      setState(() {
        _simulationId = novoId;
      });
    }
    await _executarSalvamentoAutomaticoInicial();
  }

  Future<void> _executarSalvamentoAutomaticoInicial() async {
    if (_salvouAutomatico) return;
    if (_processedPath == null || _processedPath!.isEmpty) return;

    final notaInicial = _notesController.text.trim().isEmpty
        ? 'Sem observações'
        : _notesController.text.trim();

    await _salvarNoHistorico(notaInicial);
    _salvouAutomatico = true;

    if (mounted) {
      await _exibirAvisoHistorico5Segundos();
    }
  }

  Future<void> _garantirSalvoAntesDeSair() async {
    if (_processedPath == null || _processedPath!.isEmpty) return;
    if (_simulationId == null || _simulationId!.isEmpty) {
      _simulationId = await _gerarProximoIdSimulacao();
    }
    final notaAtual = _notesController.text.trim().isEmpty
        ? 'Sem observações'
        : _notesController.text.trim();
    await _salvarNoHistorico(notaAtual);
    _salvouAutomatico = true;
  }

  Future<void> _exibirAvisoHistorico5Segundos() async {
    final boxUser = await _obterBoxUsuario();
    final bool ocultarAviso =
    (boxUser.get(_kHideHistoryPdfTipKey, defaultValue: false) as bool);

    if (ocultarAviso || !mounted) return;

    _removerAvisoHistorico();

    bool dontShowAgain = false;
    final overlay = Overlay.of(context);

    void fecharAviso() {
      _tipDismissTimer?.cancel();
      _tipDismissTimer = null;
      if (_tipOverlayEntry != null && _tipOverlayEntry!.mounted) {
        _tipOverlayEntry!.remove();
      }
      _tipOverlayEntry = null;
    }

    _tipOverlayEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: StatefulBuilder(
            builder: (ctx, setBannerState) {
              return AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (ctx, child) {
                  final alpha = _pulseAnimation.value;
                  return Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF1E293B),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(alpha),
                          width: 2.0,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FadeTransition(
                          opacity: _pulseAnimation,
                          child: const Icon(
                            Icons.notifications_active,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Salvo no histórico! Você pode gerar o PDF posteriormente.',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: fecharAviso,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final novoValor = !dontShowAgain;
                        setBannerState(() {
                          dontShowAgain = novoValor;
                        });
                        await boxUser.put(_kHideHistoryPdfTipKey, novoValor);
                        if (novoValor) {
                          _tipDismissTimer?.cancel();
                          _tipDismissTimer = Timer(
                            const Duration(milliseconds: 500),
                            fecharAviso,
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: dontShowAgain,
                            activeColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.white70),
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) async {
                              final marcado = val ?? false;
                              setBannerState(() {
                                dontShowAgain = marcado;
                              });
                              await boxUser.put(_kHideHistoryPdfTipKey, marcado);
                              if (marcado) {
                                _tipDismissTimer?.cancel();
                                _tipDismissTimer = Timer(
                                  const Duration(milliseconds: 500),
                                  fecharAviso,
                                );
                              }
                            },
                          ),
                          const Text(
                            'Não mostrar novamente',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    overlay.insert(_tipOverlayEntry!);
    _tipDismissTimer = Timer(const Duration(seconds: 5), fecharAviso);
  }

  void _removerAvisoHistorico() {
    _tipDismissTimer?.cancel();
    _tipDismissTimer = null;
    if (_tipOverlayEntry != null && _tipOverlayEntry!.mounted) {
      _tipOverlayEntry!.remove();
    }
    _tipOverlayEntry = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String? idRecebido;

      if (args is Map<String, dynamic>) {
        _originalPath = args['originalPath'] ?? args['original'];
        _processedPath = args['processedPath'] ??
            args['processed'] ??
            args['image'] ??
            args['resultPath'];

        _selectedColor = args['color'] ?? 'BL3';
        _selectedShape = args['shape'] ?? 'Natural';
        idRecebido = args['simulationId'] as String?;

        // Recupera a data/hora original salva no historico, se existir
        final rawDate = args['date'] ?? args['createdAt'] ?? args['dataHora'];
        if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
          _simulationDate = rawDate.toString().trim();
        }

        _userEmail = args['userEmail'];

        final existingNotes = args['notes'] ?? args['note'];
        if (existingNotes != null) {
          _notesController.text = existingNotes;
        }
      }

      if (_simulationDate == null || _simulationDate!.isEmpty) {
        _simulationDate = DateTime.now().toIso8601String();
      }

      if (_userEmail == null || _userEmail!.isEmpty) {
        if (Hive.isBoxOpen('box_usuario')) {
          _userEmail =
          Hive.box('box_usuario').get('email', defaultValue: '') as String;
        }
      }

      if (idRecebido != null && idRecebido.trim().isNotEmpty) {
        _simulationId = idRecebido.trim();
        _idInicializado = true;
        // Se veio do histórico, não precisa re-exibir o aviso de "salvo no histórico"
        _salvouAutomatico = true;
      } else {
        _prepararNovoIdUnico();
      }

      _isInit = false;
    }
  }

  @override
  void dispose() {
    _removerAvisoHistorico();
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Formata a data/hora da simulacao (nunca usa DateTime.now() ao gerar PDF de item salvo)
  String _formatarDataHoraSimulacao(String? dataIsoOuTexto) {
    if (dataIsoOuTexto != null && dataIsoOuTexto.trim().isNotEmpty) {
      final texto = dataIsoOuTexto.trim();
      final parsed = DateTime.tryParse(texto);
      if (parsed != null) {
        final local = parsed.toLocal();
        final dia = local.day.toString().padLeft(2, '0');
        final mes = local.month.toString().padLeft(2, '0');
        final ano = local.year.toString();
        final hora = local.hour.toString().padLeft(2, '0');
        final min = local.minute.toString().padLeft(2, '0');
        return '$dia/$mes/$ano às $hora:$min';
      }
      return texto;
    }

    final now = DateTime.now();
    return "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} às ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  // Converte o codigo Bleach no nome profissional correspondente
  String _obterNomeEscalaBleach(String? corCodigo) {
    if (corCodigo == null) return 'Natural';
    final codigo = corCodigo.toUpperCase().trim();
    if (codigo.contains('BL1') || codigo.contains('ULTRA')) return 'BL1 - Ultra';
    if (codigo.contains('BL2') || codigo.contains('INTENSO')) return 'BL2 - Intenso';
    if (codigo.contains('BL3') || codigo.contains('NATURAL')) return 'BL3 - Natural';
    if (codigo.contains('BL4') || codigo.contains('SUAVE')) return 'BL4 - Suave';
    return corCodigo;
  }

  Future<pw.MemoryImage?> _carregarImagemSegura(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
    } catch (e) {
      debugPrint('Erro ao carregar imagem para o PDF: $e');
    }
    return null;
  }

  // Copia a imagem para o diretorio permanente do app para evitar que o cache apague
  Future<String?> _salvarImagemPermanente(
      String? caminhoTemporario, String prefixoId) async {
    if (caminhoTemporario == null || caminhoTemporario.isEmpty) return null;
    try {
      final arquivoTemp = File(caminhoTemporario);
      if (!arquivoTemp.existsSync()) return caminhoTemporario;

      if (caminhoTemporario.contains('DentalSmileHistorico')) {
        return caminhoTemporario;
      }

      final diretorioApp = await getApplicationDocumentsDirectory();
      final caminhoAppPath = diretorioApp.path;
      final pastaDestino = Directory('$caminhoAppPath/DentalSmileHistorico');

      if (!await pastaDestino.exists()) {
        await pastaDestino.create(recursive: true);
      }

      final extensao = pathExtensao(caminhoTemporario);
      final caminhoFinal =
          '${pastaDestino.path}/${prefixoId}_${DateTime.now().millisecondsSinceEpoch}.$extensao';

      await arquivoTemp.copy(caminhoFinal);
      return caminhoFinal;
    } catch (e) {
      debugPrint('Erro ao tornar imagem permanente: $e');
      return caminhoTemporario;
    }
  }

  String pathExtensao(String path) {
    try {
      return path.split('.').last;
    } catch (_) {
      return 'jpg';
    }
  }

  Future<pw.Document> _gerarDocumentoPdf({
    required String? originalPath,
    required String? adjustedPath,
    String? color,
    String? shape,
    String? note,
    String? simulationId,
    String? simulationDate,
  }) async {
    final pdf = pw.Document();

    final beforeImage = await _carregarImagemSegura(originalPath);
    final afterImage = await _carregarImagemSegura(adjustedPath);

    final corFormatada = _obterNomeEscalaBleach(color);
    final dataHoraFormatada =
    _formatarDataHoraSimulacao(simulationDate ?? _simulationDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relatório de Simulação - Dental Smile',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'ID da Simulação: ${simulationId ?? "DS-101"}',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Data: $dataHoraFormatada',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(height: 16, thickness: 1, color: PdfColors.grey400),
            pw.Text(
              'Parâmetros do Planejamento:',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('- Cor / Escala: $corFormatada',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('- Observações do Dentista: ${note ?? 'Sem observações'}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                if (beforeImage != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Antes (Original)",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Image(beforeImage,
                          width: 160, height: 190, fit: pw.BoxFit.contain),
                    ],
                  ),
                if (afterImage != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Depois (Simulação IA)",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Image(afterImage,
                          width: 160, height: 190, fit: pw.BoxFit.contain),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Observação Importante:',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Esta imagem representa apenas uma simulação digital com finalidade ilustrativa e não garante o resultado clínico final do tratamento odontológico. O resultado real pode variar de acordo com as condições clínicas, planejamento profissional e execução do tratamento.',
                    style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(height: 10, thickness: 0.5, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Dental Smile © 2026',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600),
                ),
                pw.Text(
                  'Documento gerado digitalmente',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  Future<void> _salvarNoHistorico(String noteText) async {
    final box = await _obterBoxSimulacoes();
    final boxUser = await _obterBoxUsuario();

    final String emailDono = (_userEmail != null && _userEmail!.isNotEmpty)
        ? _userEmail!
        : (boxUser.get('email', defaultValue: '') as String);

    final idSimulacao = (_simulationId != null && _simulationId!.isNotEmpty)
        ? _simulationId!
        : await _gerarProximoIdSimulacao();

    _simulationId = idSimulacao;

    final dataHoraRegistro =
    (_simulationDate != null && _simulationDate!.isNotEmpty)
        ? _simulationDate!
        : DateTime.now().toIso8601String();
    _simulationDate = dataHoraRegistro;

    final caminhoOriginalPerm =
    await _salvarImagemPermanente(_originalPath, '${idSimulacao}_orig');
    final caminhoProcessadoPerm =
    await _salvarImagemPermanente(_processedPath, '${idSimulacao}_proc');

    final simulationData = {
      'simulationId': idSimulacao,
      'date': dataHoraRegistro,
      'originalPath': caminhoOriginalPerm,
      'processedPath': caminhoProcessadoPerm,
      'color': _selectedColor,
      'shape': _selectedShape,
      'notes': noteText,
      'userEmail': emailDono,
    };

    int? indiceExistente;
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item is Map && item['simulationId']?.toString() == idSimulacao) {
        indiceExistente = i;
        break;
      }
    }

    if (indiceExistente != null) {
      await box.putAt(indiceExistente, simulationData);
    } else {
      await box.add(simulationData);
    }
  }

  void _abrirPreviewPdf() async {
    _removerAvisoHistorico();

    final noteText = _notesController.text.trim().isEmpty
        ? 'Sem observações'
        : _notesController.text.trim();

    await _salvarNoHistorico(noteText);
    _salvouAutomatico = true;

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Pré-visualização do Relatório'),
            backgroundColor: const Color(0xFF5C6BC0),
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) async {
              final doc = await _gerarDocumentoPdf(
                originalPath: _originalPath,
                adjustedPath: _processedPath,
                color: _selectedColor,
                shape: _selectedShape,
                note: noteText,
                simulationId: _simulationId,
                simulationDate: _simulationDate,
              );
              return doc.save();
            },
            allowSharing: true,
            allowPrinting: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName:
            'Relatorio_Dental_Smile_${_simulationId ?? "simulacao"}.pdf',
          ),
        ),
      ),
    );

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final originalFile = (_originalPath != null && _originalPath!.isNotEmpty)
        ? File(_originalPath!)
        : null;
    final processedFile =
    (_processedPath != null && _processedPath!.isNotEmpty)
        ? File(_processedPath!)
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saindoPeloPopScope) return;
        _saindoPeloPopScope = true;
        _removerAvisoHistorico();
        await _garantirSalvoAntesDeSair();
        if (!mounted) return;
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resultado da Simulação'),
          backgroundColor: const Color(0xFF5C6BC0),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () async {
                _removerAvisoHistorico();
                await _garantirSalvoAntesDeSair();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
          ],
        ),
        body: Background(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_simulationId != null)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: $_simulationId',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ),
                const SizedBox(height: 12),

                Center(
                  child: ConstrainedBox(
                    constraints:
                    const BoxConstraints(maxHeight: 400, maxWidth: 400),
                    child: AspectRatio(
                      aspectRatio: 1 / 1,
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final containerWidth = constraints.maxWidth;
                            final containerHeight = constraints.maxHeight;

                            return GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _sliderValue +=
                                      details.delta.dx / containerWidth;
                                  if (_sliderValue < 0.0) _sliderValue = 0.0;
                                  if (_sliderValue > 1.0) _sliderValue = 1.0;
                                });
                              },
                              onTapDown: (details) {
                                final localX = details.localPosition.dx;
                                setState(() {
                                  _sliderValue =
                                      (localX / containerWidth).clamp(0.0, 1.0);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.black,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (processedFile != null &&
                                          processedFile.existsSync())
                                        Image.file(
                                          processedFile,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        )
                                      else
                                        const Center(
                                            child: Text(
                                                'Erro ao carregar imagem processada',
                                                style: TextStyle(
                                                    color: Colors.white))),

                                      if (originalFile != null &&
                                          originalFile.existsSync())
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: _sliderValue,
                                            alignment: Alignment.topLeft,
                                            child: ClipRect(
                                              child: OverflowBox(
                                                alignment: Alignment.topLeft,
                                                minWidth: containerWidth,
                                                maxWidth: containerWidth,
                                                minHeight: containerHeight,
                                                maxHeight: containerHeight,
                                                child: Image.file(
                                                  originalFile,
                                                  width: containerWidth,
                                                  height: containerHeight,
                                                  fit: BoxFit.cover,
                                                  alignment: Alignment.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      Positioned(
                                        top: 0,
                                        bottom: 0,
                                        left: (containerWidth * _sliderValue) - 1.5,
                                        child: Container(
                                          width: 3,
                                          color: Colors.white,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                height: 38,
                                                width: 38,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                    )
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.compare_arrows,
                                                  size: 22,
                                                  color: Colors.indigo,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.65),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Original',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),

                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Com IA',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Observações do Dentista',
                    hintText: 'Insira as notas clínicas ou recomendações...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          _removerAvisoHistorico();
                          await _garantirSalvoAntesDeSair();
                          if (!mounted) return;
                          if (_originalPath != null &&
                              _originalPath!.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdjustSmileScreen(
                                  image: File(_originalPath!),
                                  userEmail: _userEmail,
                                  initialColor: _selectedColor?.toLowerCase(),
                                ),
                              ),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Ajustar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF5C6BC0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _abrirPreviewPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Gerar PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}