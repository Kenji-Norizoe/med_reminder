// 薬データのモデルクラス
class Medicine {
  final int? id;
  final String name;         // 薬名（空文字可）
  final List<String> timings; // タイミング（複数可）
  final String startDate;    // 開始日 YYYY-MM-DD
  final int durationDays;    // 服用日数（0=無期限）
  final String? endDate;     // 終了日 YYYY-MM-DD（計算済み）
  final String? memo;        // メモ（任意）
  final int isActive;        // 1=有効, 0=終了済み

  Medicine({
    this.id,
    required this.name,
    required this.timings,
    required this.startDate,
    required this.durationDays,
    this.endDate,
    this.memo,
    this.isActive = 1,
  });

  // DBのMapからMedicineを生成
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      timings: (map['timings'] as String? ?? '').isEmpty
          ? []
          : (map['timings'] as String).split(','),
      startDate: map['start_date'] as String? ?? '',
      durationDays: map['duration_days'] as int? ?? 0,
      endDate: map['end_date'] as String?,
      memo: map['memo'] as String?,
      isActive: map['is_active'] as int? ?? 1,
    );
  }

  // MedicineをDBのMapに変換
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'timings': timings.join(','),
      'start_date': startDate,
      'duration_days': durationDays,
      'end_date': endDate,
      'memo': memo,
      'is_active': isActive,
    };
  }

  // フィールドを部分的に上書きしたコピーを返す
  Medicine copyWith({
    int? id,
    String? name,
    List<String>? timings,
    String? startDate,
    int? durationDays,
    String? endDate,
    String? memo,
    int? isActive,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      timings: timings ?? this.timings,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      endDate: endDate ?? this.endDate,
      memo: memo ?? this.memo,
      isActive: isActive ?? this.isActive,
    );
  }

  // 表示用の薬名（空の場合はデフォルト名を返す）
  String get displayName => name.isNotEmpty ? name : '名前なしの薬';
}