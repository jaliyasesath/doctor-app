class TemplateModel {
  final int? id;
  final String name;
  final String complaint;
  final String diagnosis;
  final String itemsJson;
  final bool isFavorite;

  TemplateModel({
    this.id,
    required this.name,
    required this.complaint,
    required this.diagnosis,
    required this.itemsJson,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'complaint': complaint,
      'diagnosis': diagnosis,
      'items_json': itemsJson,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory TemplateModel.fromMap(Map<String, dynamic> map) {
    return TemplateModel(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? '',
      complaint: map['complaint']?.toString() ?? '',
      diagnosis: map['diagnosis']?.toString() ?? '',
      itemsJson: map['items_json']?.toString() ?? '[]',
      isFavorite: (map['is_favorite'] ?? 0) == 1,
    );
  }

  TemplateModel copyWith({
    int? id,
    String? name,
    String? complaint,
    String? diagnosis,
    String? itemsJson,
    bool? isFavorite,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      complaint: complaint ?? this.complaint,
      diagnosis: diagnosis ?? this.diagnosis,
      itemsJson: itemsJson ?? this.itemsJson,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}