import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

void main() => runApp(const AvTranslatorApp());

class AvTranslatorApp extends StatelessWidget {
  const AvTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AV Translator',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080808),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TranslatorHomePage(),
    );
  }
}

class SubtitleCue {
  SubtitleCue({required this.index, required this.time, required this.text});
  final String index;
  final String time;
  final String text;
}

class TranslatorHomePage extends StatefulWidget {
  const TranslatorHomePage({super.key});

  @override
  State<TranslatorHomePage> createState() => _TranslatorHomePageState();
}

class _TranslatorHomePageState extends State<TranslatorHomePage> {
  OnDeviceTranslator? _translator;
  bool _modelReady = false;
  bool _busy = false;
  double _progress = 0;
  String _status = 'Pilih file subtitle Jepang (.srt / .vtt)';
  String? _fileName;
  List<SubtitleCue> _preview = [];
  List<SubtitleCue> _translated = [];

  @override
  void dispose() {
    _translator?.close();
    super.dispose();
  }

  Future<void> _prepareTranslator() async {
    final manager = OnDeviceTranslatorModelManager();
    setState(() => _status = 'Menyiapkan model Jepang & Indonesia...');
    await manager.downloadModel(TranslateLanguage.japanese.bcpCode);
    await manager.downloadModel(TranslateLanguage.indonesian.bcpCode);
    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.japanese,
      targetLanguage: TranslateLanguage.indonesian,
    );
    _modelReady = true;
  }

  Future<void> _pickSubtitle() async {
    final file = await FilePicker.pickFile();
    if (file == null) return;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.srt') && !name.endsWith('.vtt')) {
      _show('Pilih file .srt atau .vtt');
      return;
    }
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
    final cues = _parseSubtitle(text);
    setState(() {
      _fileName = file.name;
      _preview = cues.take(8).toList();
      _translated = [];
      _progress = 0;
      _status = '${cues.length} subtitle ditemukan.';
    });
    _pendingCues = cues;
  }

  List<SubtitleCue> _pendingCues = [];

  List<SubtitleCue> _parseSubtitle(String input) {
    final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final result = <SubtitleCue>[];
    for (final block in blocks) {
      final lines = block.split('\n');
      if (lines.length < 2) continue;
      int timeIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timeIndex = i;
          break;
        }
      }
      if (timeIndex < 0 || timeIndex + 1 >= lines.length) continue;
      final index = timeIndex > 0 ? lines.first.trim() : '${result.length + 1}';
      final textLines = lines.sublist(timeIndex + 1).where((e) => e.trim().isNotEmpty).toList();
      if (textLines.isEmpty) continue;
      result.add(SubtitleCue(index: index, time: lines[timeIndex].trim(), text: textLines.join('\n')));
    }
    return result;
  }

  String _stripTags(String text) => text.replaceAll(RegExp(r'<[^>]+>'), '');

  Future<void> _translateAll() async {
    if (_pendingCues.isEmpty) {
      _show('Pilih subtitle terlebih dahulu.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      if (!_modelReady) await _prepareTranslator();
      final translator = _translator!;
      final output = <SubtitleCue>[];
      for (int i = 0; i < _pendingCues.length; i++) {
        final cue = _pendingCues[i];
        final clean = _stripTags(cue.text);
        final translated = await translator.translateText(clean);
        output.add(SubtitleCue(index: cue.index, time: cue.time, text: translated));
        if (mounted) {
          setState(() {
            _progress = (i + 1) / _pendingCues.length;
            _status = 'Menerjemahkan ${i + 1}/${_pendingCues.length}';
            _translated = output.take(8).toList();
          });
        }
      }
      _translated = output;
      setState(() => _status = 'Selesai. ${output.length} subtitle diterjemahkan.');
    } catch (e) {
      _show('Gagal menerjemahkan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSrt() async {
    if (_translated.isEmpty) {
      _show('Terjemahkan subtitle terlebih dahulu.');
      return;
    }
    final content = _translated.map((c) => '${c.index}\n${c.time}\n${c.text}').join('\n\n');
    final bytes = Uint8List.fromList(utf8.encode('$content\n'));
    final outputName = '${_fileName?.replaceFirst(RegExp(r'\.(srt|vtt)$', caseSensitive: false), '') ?? 'subtitle'}_ID.srt';
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Simpan subtitle Indonesia',
      fileName: outputName,
      bytes: bytes,
    );
    if (uri != null) _show('Subtitle tersimpan.');
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('AV Translator', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/av_translator_logo.png', height: 210, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 18),
              const Text('Japanese  →  Bahasa Indonesia', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Terjemahkan subtitle secara lokal di perangkat.', style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 20),
              _ActionButton(icon: Icons.folder_open, label: _fileName ?? 'Pilih Subtitle .SRT / .VTT', onTap: _busy ? null : _pickSubtitle),
              const SizedBox(height: 12),
              _ActionButton(icon: Icons.translate, label: _busy ? 'Menerjemahkan...' : 'Terjemahkan ke Indonesia', onTap: _busy ? null : _translateAll, filled: true),
              const SizedBox(height: 12),
              _ActionButton(icon: Icons.save_alt, label: 'Simpan Subtitle Indonesia', onTap: _busy ? null : _saveSrt),
              const SizedBox(height: 18),
              if (_busy) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text(_status, style: TextStyle(color: Colors.grey.shade300))),
              const SizedBox(height: 18),
              _PreviewCard(title: _translated.isNotEmpty ? 'Preview Indonesia' : 'Preview Jepang', cues: _translated.isNotEmpty ? _translated : _preview),
              const SizedBox(height: 16),
              const Text('Catatan: kualitas terjemahan bergantung pada konteks kalimat. Model ML Kit berjalan di perangkat setelah model bahasa diunduh.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: filled
          ? FilledButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)))
          : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label)),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.cues});
  final String title;
  final List<SubtitleCue> cues;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF121212),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (cues.isEmpty)
            const Text('Belum ada subtitle.', style: TextStyle(color: Colors.grey))
          else
            ...cues.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.index}  ${c.time}', style: TextStyle(color: Colors.red.shade300, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(c.text),
                  ]),
                )),
        ]),
      ),
    );
  }
}
