import 'dart:convert';
import '../../../data/local/database_helper.dart';
import '../models/template_model.dart';

class TemplateService {
  static Future<void> saveTemplate(TemplateModel template) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('templates', template.toMap());
  }

  static Future<void> updateTemplate(TemplateModel template) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  static Future<List<TemplateModel>> getTemplates() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'templates',
      orderBy: 'is_favorite DESC, id DESC',
    );

    return result.map((e) => TemplateModel.fromMap(e)).toList();
  }

  static Future<List<TemplateModel>> getFavoriteTemplates() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'templates',
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
    );

    return result.map((e) => TemplateModel.fromMap(e)).toList();
  }

  static Future<void> deleteTemplate(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> toggleFavorite(TemplateModel template) async {
    final updated = template.copyWith(
      isFavorite: !template.isFavorite,
    );
    await updateTemplate(updated);
  }

  static List<Map<String, dynamic>> decodeItems(String jsonStr) {
    return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
  }

  static String encodeItems(List<Map<String, dynamic>> items) {
    return jsonEncode(items);
  }
}