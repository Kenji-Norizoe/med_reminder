import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../utils/time_utils.dart';

class MedicineFormScreen extends StatefulWidget {
  // 編集時は既存データを渡す。新規登録時は null
  final Medicine? medicine;

  const MedicineFormScreen({super.key, this.medicine});

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _nameController = TextEditingController();
  final _memoController = TextEditingController();
  final _durationController = TextEditingController();

  List<String> _selectedTimings = [];
  DateTime _startDate = DateTime.now();
  bool _isUnlimited = false; // 無期限フラグ
  bool _isSaving = false;

  bool get _isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // 編集時は既存データをフォームに反映
      final m = widget.medicine!;
      _nameController.text = m.name;
      _memoController.text = m.memo ?? '';
      _selectedTimings = List.from(m.timings);
      _startDate = DateTime.parse(m.startDate);
      if (m.durationDays <= 0) {
        _isUnlimited = true;
        _durationController.text = '';
      } else {
        _durationController.text = m.durationDays.toString();
      }
    } else {
      // 新規登録のデフォルト値
      _durationController.text = '14';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // 日付ピッカーを開く
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ja'),
      builder: (context, child) => child!,
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  // バリデーション
  String? _validate() {
    if (_selectedTimings.isEmpty) {
      return '飲むタイミングを1つ以上選んでください';
    }
    if (!_isUnlimited) {
      final days = int.tryParse(_durationController.text.trim());
      if (days == null || days <= 0) {
        return '服用日数を正しく入力してください（1以上の数字）';
      }
    }
    return null;
  }

  // 保存処理
  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final durationDays = _isUnlimited
        ? 0
        : int.parse(_durationController.text.trim());
    final endDate = calcEndDate(startDateStr, durationDays);

    final medicine = Medicine(
      id: widget.medicine?.id,
      name: _nameController.text.trim(),
      timings: _selectedTimings,
      startDate: startDateStr,
      durationDays: durationDays,
      endDate: endDate,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
      isActive: 1,
    );

    int medicineId;
    if (_isEditing) {
      await DatabaseHelper.instance.updateMedicine(medicine);
      medicineId = medicine.id!;
    } else {
      medicineId = await DatabaseHelper.instance.insertMedicine(medicine);
    }

    // 通知を（再）スケジュール
    final savedMedicine = await DatabaseHelper.instance.getMedicineById(medicineId);
    if (savedMedicine != null) {
      if (savedMedicine.endDate != null) {
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.of(context).pop(true); // true = 保存完了
  }

  // 削除処理（編集時のみ）
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'この薬を削除しますか？',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '「${widget.medicine!.displayName}」を削除します。\n服薬記録も含めて元に戻せません。',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル',
                style: TextStyle(fontSize: 17, color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 48),
            ),
            child: const Text('削除する', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseHelper.instance.deleteMedicine(widget.medicine!.id!);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '薬を編集する' : '薬を追加する'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 薬名
            _buildSectionLabel('薬の名前（省略できます）'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: '例：血圧の薬、朝の薬',
                hintStyle:
                    const TextStyle(fontSize: 18, color: Colors.black38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // タイミング選択
            _buildSectionLabel('飲むタイミング（複数選択できます）'),
            const SizedBox(height: 4),
            const Text(
              '※ 1つ以上選んでください',
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
            const SizedBox(height: 12),
            _buildTimingSelector(),

            const SizedBox(height: 28),

            // 開始日
            _buildSectionLabel('飲み始める日'),
            const SizedBox(height: 8),
            _buildDatePicker(),

            const SizedBox(height: 28),

            // 服用日数
            _buildSectionLabel('服用日数'),
            const SizedBox(height: 8),
            _buildDurationInput(),

            const SizedBox(height: 28),

            // メモ
            _buildSectionLabel('メモ（省略できます）'),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              style: const TextStyle(fontSize: 18),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '例：食後すぐに飲む、水で飲む',
                hintStyle:
                    const TextStyle(fontSize: 16, color: Colors.black38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // 保存ボタン
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 24),
              label: Text(
                _isEditing ? '変更を保存する' : '登録する',
                style: const TextStyle(fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 64),
                backgroundColor: const Color(0xFF2E7D9F),
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // セクションラベル
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // タイミング選択ボタン群
  Widget _buildTimingSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: Timing.all.map((timing) {
        final isSelected = _selectedTimings.contains(timing);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedTimings.remove(timing);
              } else {
                _selectedTimings.add(timing);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2E7D9F)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2E7D9F)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Text(
              Timing.label(timing),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 開始日ピッカー
  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickStartDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: Color(0xFF2E7D9F), size: 24),
            const SizedBox(width: 12),
            Text(
              DateFormat('yyyy年M月d日').format(_startDate),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  // 服用日数入力
  Widget _buildDurationInput() {
    return Column(
      children: [
        // 無期限チェック
        Row(
          children: [
            Checkbox(
              value: _isUnlimited,
              onChanged: (v) {
                setState(() {
                  _isUnlimited = v ?? false;
                  if (_isUnlimited) _durationController.text = '';
                });
              },
              activeColor: const Color(0xFF2E7D9F),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isUnlimited = !_isUnlimited;
                  if (_isUnlimited) _durationController.text = '';
                });
              },
              child: const Text(
                '無期限（ずっと飲む）',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        if (!_isUnlimited) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    hintText: '例：14',
                    hintStyle: const TextStyle(
                        fontSize: 18, color: Colors.black38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '日間',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // 終了日のプレビュー
          if (_durationController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildEndDatePreview(),
          ],
        ],
      ],
    );
  }

  // 終了日プレビュー
  Widget _buildEndDatePreview() {
    final days = int.tryParse(_durationController.text.trim());
    if (days == null || days <= 0) return const SizedBox.shrink();

    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endDateStr = calcEndDate(startStr, days);
    if (endDateStr == null) return const SizedBox.shrink();

    final endDate = DateTime.parse(endDateStr);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '終了予定日：${DateFormat('yyyy年M月d日').format(endDate)}',
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF2E7D9F),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}