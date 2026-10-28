import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

class _CompareScreenState extends State<CompareScreen> {
  double _sliderValue = 0.5; // 0.0 = Original, 1.0 = Com IA
  final TextEditingController _notesController = TextEditingController();

  String? _originalPath;
  String? _processedPath;
  String? _selectedColor;
  String? _selectedShape;
  String? _selectedSize;
  String? _simulationId;
  String? _userEmail;

  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _originalPath = args['originalPath'] ?? args['original'];
        _processedPath = args['processedPath'] ?? args['processed'] ?? args['image'] ?? args['resultPath'];

        _selectedColor = args['color'] ?? 'Natural';
        _selectedShape = args['shape'] ?? 'Oval';
        _selectedSize = args['size'] ?? 'Médio';
        _simulationId = args['simulationId'] ?? 'DS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

        _userEmail = args['userEmail'];

        final existingNotes = args['notes'] ?? args['note'];
        if (existingNotes != null) {
          _notesController.text = existingNotes;
        }
      }

      if (_userEmail == null || _userEmail!.isEmpty) {
        final boxUser = Hive.box('box_usuario');
        _userEmail = boxUser.get('email', defaultValue: '') as String;
      }

      _isInit = false;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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

  Future<pw.Document> _gerarDocumentoPdf({
    required String? originalPath,
    required String? adjustedPath,
    String? color,
    String? shape,
    String? size,
    String? note,
    String? simulationId,
  }) async {
    final pdf = pw.Document();

    final beforeImage = await _carregarImagemSegura(originalPath);
    final afterImage = await _carregarImagemSegura(adjustedPath);

    final now = DateTime.now();
    final dataHoraFormatada = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} às ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'ID da Simulação: ${simulationId ?? "DS-Geral"}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Data: $dataHoraFormatada',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
            pw.Text('- Cor: ${color ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('- Formato: ${shape ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('- Tamanho: ${size ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('- Observações do Dentista: ${note ?? 'Sem observações'}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                if (beforeImage != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Antes (Original)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Image(beforeImage, width: 160, height: 190, fit: pw.BoxFit.cover),
                    ],
                  ),
                if (afterImage != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Depois (Simulação IA)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Image(afterImage, width: 160, height: 190, fit: pw.BoxFit.cover),
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
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Esta imagem representa apenas uma simulação digital com finalidade ilustrativa e não garante o resultado clínico final do tratamento odontológico. O resultado real pode variar de acordo com as condições clínicas, planejamento profissional e execução do tratamento.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
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
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
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
    final box = Hive.box('simulacoes');

    final String emailDono = (_userEmail != null && _userEmail!.isNotEmpty)
        ? _userEmail!
        : Hive.box('box_usuario').get('email', defaultValue: '') as String;

    final simulationData = {
      'simulationId': _simulationId ?? 'DS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      'date': DateTime.now().toIso8601String(),
      'originalPath': _originalPath,
      'processedPath': _processedPath,
      'color': _selectedColor,
      'shape': _selectedShape,
      'size': _selectedSize,
      'notes': noteText,
      'userEmail': emailDono,
    };
    await box.add(simulationData);
  }

  void _abrirPreviewPdf() async {
    final noteText = _notesController.text.trim().isEmpty
        ? 'Sem observações'
        : _notesController.text.trim();

    await _salvarNoHistorico(noteText);

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
                size: _selectedSize,
                note: noteText,
                simulationId: _simulationId,
              );
              return doc.save();
            },
            allowSharing: true,
            allowPrinting: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: 'Relatorio_Dental_Smile_${_simulationId ?? "simulacao"}.pdf',
          ),
        ),
      ),
    );

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final originalFile = (_originalPath != null && _originalPath!.isNotEmpty) ? File(_originalPath!) : null;
    final processedFile = (_processedPath != null && _processedPath!.isNotEmpty) ? File(_processedPath!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Simulação'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: $_simulationId',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
              const SizedBox(height: 12),

              // 🖼️ ÁREA DE COMPARAÇÃO COM PROPORÇÃO 1:1 E FIT.COVER (ALINHAMENTO GEOMÉTRICO PERFEITO)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: AspectRatio(
                    aspectRatio: 1 / 1, // 👈 Proporção quadrada exata idêntica à compressão de origem
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final containerWidth = constraints.maxWidth;
                        final containerHeight = constraints.maxHeight;

                        return GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _sliderValue += details.delta.dx / containerWidth;
                              if (_sliderValue < 0.0) _sliderValue = 0.0;
                              if (_sliderValue > 1.0) _sliderValue = 1.0;
                            });
                          },
                          onTapDown: (details) {
                            final localX = details.localPosition.dx;
                            setState(() {
                              _sliderValue = (localX / containerWidth).clamp(0.0, 1.0);
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
                                  // 1️⃣ CAMADA DE BASE (DIREITA): Imagem Processada com IA com BoxFit.cover
                                  if (processedFile != null && processedFile.existsSync())
                                    Image.file(
                                      processedFile,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                    )
                                  else
                                    const Center(child: Text('Erro ao carregar imagem processada', style: TextStyle(color: Colors.white))),

                                  // 2️⃣ CAMADA SOBREPOSTA (ESQUERDA): Imagem Original com BoxFit.cover exato
                                  if (originalFile != null && originalFile.existsSync())
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

                                  // 3️⃣ BARRA DO SLIDER
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
                                                  color: Colors.black.withOpacity(0.3),
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

                                  // 🏷️ BADGE ORIGINAL
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.65),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Original',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),

                                  // 🏷️ BADGE COM IA
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Com IA',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                      onPressed: () {
                        if (_originalPath != null && _originalPath!.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdjustSmileScreen(
                                image: File(_originalPath!),
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
    );
  }
}