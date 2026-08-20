import 'package:flutter/material.dart';

import '../../models/last_readings.dart';
import '../../services/api_service.dart';
import '../../widgets/meter_field.dart';

class OdpoctyCard extends StatefulWidget {
  const OdpoctyCard({super.key});

  @override
  State<OdpoctyCard> createState() => _OdpoctyCardState();
}

class _OdpoctyCardState extends State<OdpoctyCard> {
  DateTime _dateTime = DateTime.now();

  final _plnValue = TextEditingController();
  final _plnRemoved = TextEditingController();
  final _plnStart = TextEditingController();
  final _plnNote = TextEditingController();
  final _plnFocus = FocusNode();
  bool _plnChange = false;
  bool _plnShowNotes = false;

  final _eleValue = TextEditingController();
  final _eleRemoved = TextEditingController();
  final _eleStart = TextEditingController();
  final _eleNote = TextEditingController();
  final _eleFocus = FocusNode();
  bool _eleChange = false;
  bool _eleShowNotes = false;

  final _vodValue = TextEditingController();
  final _vodRemoved = TextEditingController();
  final _vodStart = TextEditingController();
  final _vodNote = TextEditingController();
  final _vodFocus = FocusNode();
  bool _vodChange = false;
  bool _vodShowNotes = false;

  final _commonNote = TextEditingController();
  bool _showCommonNote = false;

  /// Centralny prepinac v zahlavi - naraz nastavi vsetky 4 prepinace poznamok naraz.
  bool _showAllNotes = false;

  LastReadings? _lastReadings;
  bool _loadingLast = false;
  bool _saving = false;

  /// Kluce meradiel ('pln'/'ele'/'vod'), ktore pri poslednom pokuse o ulozenie
  /// zlyhali na validacii "nizsia ako posledna hodnota". Zvyrazni sa nimi pole cervenou.
  Set<String> _invalidMeters = {};

  @override
  void initState() {
    super.initState();
    _loadLastReadings();
  }

  @override
  void dispose() {
    for (final c in [
      _plnValue, _plnRemoved, _plnStart, _plnNote,
      _eleValue, _eleRemoved, _eleStart, _eleNote,
      _vodValue, _vodRemoved, _vodStart, _vodNote,
      _commonNote,
    ]) {
      c.dispose();
    }
    _plnFocus.dispose();
    _eleFocus.dispose();
    _vodFocus.dispose();
    super.dispose();
  }

  Future<void> _loadLastReadings() async {
    setState(() => _loadingLast = true);
    try {
      final data = await ApiService.fetchLastReadings();
      if (!mounted) return;
      setState(() => _lastReadings = data);
    } catch (_) {
      // ticho ignoruj - popisky s poslednou hodnotou ostanu prazdne
    } finally {
      if (mounted) setState(() => _loadingLast = false);
    }
  }

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _hintFor(MeterLastValue? m) {
    if (m == null) return '- [-]';
    final g = m.global != null ? _formatNum(m.global!) : '-';
    final r = m.raw != null ? _formatNum(m.raw!) : '-';
    return '$g [$r]';
  }

  MeterLastValue? _pickMeter(String meter, LastReadings data) {
    switch (meter) {
      case 'pln':
        return data.pln;
      case 'ele':
        return data.ele;
      case 'vod':
        return data.vod;
    }
    return null;
  }

  void _applyRaw(TextEditingController ctrl, MeterLastValue? m) {
    if (m?.raw != null) {
      ctrl.text = _formatNum(m!.raw!);
    }
  }

  /// Reload jedneho pola - vzdy nanovo nacita aktualne data z API (nie z cache).
  Future<void> _reloadOne(String meter, TextEditingController ctrl, FocusNode focus) async {
    setState(() => _loadingLast = true);
    try {
      final data = await ApiService.fetchLastReadings();
      if (!mounted) return;
      setState(() => _lastReadings = data);
      _applyRaw(ctrl, _pickMeter(meter, data));
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      focus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri nacitani poslednej hodnoty: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingLast = false);
    }
  }

  /// Reload vsetkych troch poli naraz - vzdy nanovo nacita aktualne data z API (nie z cache).
  Future<void> _reloadAll() async {
    setState(() => _loadingLast = true);
    try {
      final data = await ApiService.fetchLastReadings();
      if (!mounted) return;
      setState(() => _lastReadings = data);
      _applyRaw(_plnValue, data.pln);
      _applyRaw(_eleValue, data.ele);
      _applyRaw(_vodValue, data.vod);
      _plnFocus.requestFocus();
      _plnValue.selection = TextSelection.collapsed(offset: _plnValue.text.length);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pri nacitani poslednych hodnot: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingLast = false);
    }
  }

  void _clearAll() {
    setState(() {
      _dateTime = DateTime.now();
      for (final c in [
        _plnValue, _plnRemoved, _plnStart, _plnNote,
        _eleValue, _eleRemoved, _eleStart, _eleNote,
        _vodValue, _vodRemoved, _vodStart, _vodNote,
        _commonNote,
      ]) {
        c.clear();
      }
      _plnChange = false;
      _eleChange = false;
      _vodChange = false;
      _plnShowNotes = false;
      _eleShowNotes = false;
      _vodShowNotes = false;
      _showCommonNote = false;
      _showAllNotes = false;
      _invalidMeters = {};
    });
  }

  /// Centralny prepinac - naraz zobrazi/skryje vsetky poznamky (3 pri meradlach + spolocna).
  void _toggleAllNotes(bool? value) {
    final v = value ?? false;
    setState(() {
      _showAllNotes = v;
      _plnShowNotes = v;
      _eleShowNotes = v;
      _vodShowNotes = v;
      _showCommonNote = v;
    });
  }

  /// Vyparsuje kody meradiel ('pln'/'ele'/'vod') z chybovych detailov typu "ELE 1499 < 1500".
  Set<String> _parseInvalidMeters(List<String> details) {
    final result = <String>{};
    for (final d in details) {
      final match = RegExp(r'^(PLN|ELE|VOD)\b').firstMatch(d.trim());
      if (match != null) {
        result.add(match.group(1)!.toLowerCase());
      }
    }
    return result;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;

    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  String _isoDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _showValidationErrorDialog(String message, List<String> details) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neplatny odpocet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            for (final d in details) Text('• $d'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final plnVal = _parse(_plnValue);
    final eleVal = _parse(_eleValue);
    final vodVal = _parse(_vodValue);

    if (plnVal == null && eleVal == null && vodVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadaj aspon jednu hodnotu.')),
      );
      return;
    }

    final anyEmpty = plnVal == null || eleVal == null || vodVal == null;
    if (anyEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mimoriadny odpocet'),
          content: const Text('Niektore meradla nie su vyplnene. Si si isty?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('NIE')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ANO')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final payload = <String, dynamic>{
      'mer_datetime': _isoDateTime(_dateTime),
      'mer_pln': plnVal,
      'mer_change_pln': _plnChange,
      'mer_removed_pln': _plnChange ? _parse(_plnRemoved) : null,
      'mer_start_pln': _plnChange ? _parse(_plnStart) : null,
      'mer_ele': eleVal,
      'mer_change_ele': _eleChange,
      'mer_removed_ele': _eleChange ? _parse(_eleRemoved) : null,
      'mer_start_ele': _eleChange ? _parse(_eleStart) : null,
      'mer_vod': vodVal,
      'mer_change_vod': _vodChange,
      'mer_removed_vod': _vodChange ? _parse(_vodRemoved) : null,
      'mer_start_vod': _vodChange ? _parse(_vodStart) : null,
      'mer_note': _emptyToNull(_commonNote.text),
      'mer_note_pln': _emptyToNull(_plnNote.text),
      'mer_note_ele': _emptyToNull(_eleNote.text),
      'mer_note_vod': _emptyToNull(_vodNote.text),
    };

    setState(() => _saving = true);
    try {
      await ApiService.createReading(payload);
      _clearAll();
      await _loadLastReadings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaznam ulozeny')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.details != null && e.details!.isNotEmpty) {
        setState(() => _invalidMeters = _parseInvalidMeters(e.details!));
        await _showValidationErrorDialog(e.message, e.details!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba pripojenia: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _meterSection({
    required String meterKey,
    required String title,
    required TextEditingController valueCtrl,
    required FocusNode focusNode,
    required MeterLastValue? last,
    required bool changeChecked,
    required ValueChanged<bool?> onChangeToggle,
    required TextEditingController removedCtrl,
    required TextEditingController startCtrl,
    required TextEditingController noteCtrl,
    required bool showNotes,
    required ValueChanged<bool?> onShowNotesToggle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MeterField(
                    controller: valueCtrl,
                    focusNode: focusNode,
                    labelText: _hintFor(last),
                    alwaysFloatLabel: true,
                    invalid: _invalidMeters.contains(meterKey),
                    onReload: () => _reloadOne(meterKey, valueCtrl, focusNode),
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Zmena\nmeradla',
                      style: TextStyle(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    Checkbox(
                      value: changeChecked,
                      onChanged: onChangeToggle,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Show\nnotes',
                      style: TextStyle(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    Checkbox(
                      value: showNotes,
                      onChanged: onShowNotesToggle,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
            if (changeChecked) ...[
              const SizedBox(height: 8),
              MeterField(controller: removedCtrl, labelText: 'Posledna hodnota povodneho meradla'),
              const SizedBox(height: 8),
              MeterField(controller: startCtrl, labelText: 'Startovacia hodnota noveho meradla'),
            ],
            if (showNotes) ...[
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Poznamka',
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Odpocty', style: Theme.of(context).textTheme.titleLarge),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Show notes'),
                  Checkbox(value: _showAllNotes, onChanged: _toggleAllNotes),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(_formatDateTime(_dateTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
          ),
          _meterSection(
            meterKey: 'pln',
            title: 'Plynomer (PLN)',
            valueCtrl: _plnValue,
            focusNode: _plnFocus,
            last: _lastReadings?.pln,
            changeChecked: _plnChange,
            onChangeToggle: (v) => setState(() => _plnChange = v ?? false),
            removedCtrl: _plnRemoved,
            startCtrl: _plnStart,
            noteCtrl: _plnNote,
            showNotes: _plnShowNotes,
            onShowNotesToggle: (v) => setState(() => _plnShowNotes = v ?? false),
          ),
          _meterSection(
            meterKey: 'ele',
            title: 'Elektromer (ELE)',
            valueCtrl: _eleValue,
            focusNode: _eleFocus,
            last: _lastReadings?.ele,
            changeChecked: _eleChange,
            onChangeToggle: (v) => setState(() => _eleChange = v ?? false),
            removedCtrl: _eleRemoved,
            startCtrl: _eleStart,
            noteCtrl: _eleNote,
            showNotes: _eleShowNotes,
            onShowNotesToggle: (v) => setState(() => _eleShowNotes = v ?? false),
          ),
          _meterSection(
            meterKey: 'vod',
            title: 'Vodomer (VOD)',
            valueCtrl: _vodValue,
            focusNode: _vodFocus,
            last: _lastReadings?.vod,
            changeChecked: _vodChange,
            onChangeToggle: (v) => setState(() => _vodChange = v ?? false),
            removedCtrl: _vodRemoved,
            startCtrl: _vodStart,
            noteCtrl: _vodNote,
            showNotes: _vodShowNotes,
            onShowNotesToggle: (v) => setState(() => _vodShowNotes = v ?? false),
          ),
          if (_showCommonNote) ...[
            TextField(
              controller: _commonNote,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Spolocna poznamka',
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: _clearAll, child: const Text('Clear ALL')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loadingLast ? null : _reloadAll,
                  child: const Text('RELOAD ALL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ulozit'),
          ),
        ],
      ),
    );
  }
}
