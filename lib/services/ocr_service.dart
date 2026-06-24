import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 服务 — 提供识别 + 解析能力
class OcrService {
  /// 是否支持设备端 OCR（Mobile only）
  static bool get isMlKitSupported =>
      Platform.isAndroid || Platform.isIOS;

  /// 识别图片中的文字
  /// 返回原始文本；失败则抛出异常
  static Future<String> recognizeText(XFile image) async {
    if (!isMlKitSupported) {
      throw UnsupportedError(
        '设备端 OCR 仅支持 Android / iOS。请使用手动输入模式。',
      );
    }

    // ignore: depend_on_referenced_packages
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// 从原始 OCR 文本中解析出员工列表
  /// 返回 [{name, code, phone, department}, ...]
  static List<Map<String, String>> parseEmployees(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length >= 2)
        .toList();

    final employees = <Map<String, String>>[];
    final seen = <String>{};

    for (final line in lines) {
      final parsed = _parseLine(line);
      if (parsed != null &&
          parsed['name']!.isNotEmpty &&
          !seen.contains(parsed['name'])) {
        bool duplicate = false;
        for (final existing in employees) {
          if (existing['name'] == parsed['name'] &&
              existing['code'] == parsed['code']) {
            duplicate = true;
            break;
          }
        }
        if (!duplicate) {
          employees.add(parsed);
          seen.add(parsed['name']!);
        }
      }
    }

    return employees;
  }

  /// 从粘贴的文本中解析员工（同 parseEmployees）
  static List<Map<String, String>> parseEmployeesFromPastedText(String text) {
    return parseEmployees(text);
  }

  // ---------- 单行解析逻辑 ----------

  static Map<String, String>? _parseLine(String line) {
    String cleaned = line.replaceAll(
      RegExp(r'[^一-龥a-zA-Z0-9\s\-\.\(\)（）]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isEmpty) return null;

    final parts = cleaned.split(RegExp(r'\s+'));

    String? name, code, phone, dept;

    for (final part in parts) {
      if (_isPhoneNumber(part)) {
        phone = part;
      } else if (_isEmployeeCode(part)) {
        code = part;
      } else if (_isDepartment(part)) {
        dept = part;
      } else if (_isChineseName(part) && name == null) {
        name = part;
      }
    }

    if (name == null) {
      for (final part in parts) {
        if (part.contains(RegExp(r'[一-龥]')) && part.length >= 2) {
          if (!_isDepartment(part)) {
            name = part;
            break;
          }
        }
      }
    }

    if (name == null && parts.isNotEmpty) {
      final first = parts.first;
      if (first.contains(RegExp(r'[一-龥]')) && first.length >= 2) {
        name = first;
      }
    }

    if (name == null || name.isEmpty) return null;

    name = name.replaceAll(RegExp(r'[\.\-\(\)（）]'), '').trim();

    return {
      'name': name,
      'code': code ?? '',
      'phone': phone ?? '',
      'department': dept ?? '',
    };
  }

  static bool _isChineseName(String s) {
    if (s.length < 2 || s.length > 6) return false;
    final cleaned = s.replaceAll(RegExp(r'[·•]'), '');
    return RegExp(r'^[一-龥]+$').hasMatch(cleaned) && cleaned.length >= 2;
  }

  static bool _isEmployeeCode(String s) {
    if (RegExp(r'^[A-Za-z]{1,4}[-]?\d{2,}$').hasMatch(s)) return true;
    if (RegExp(r'^\d{3,}$').hasMatch(s)) return true;
    return false;
  }

  static bool _isPhoneNumber(String s) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(s);
  }

  static bool _isDepartment(String s) {
    if (s.length > 10) return false;
    if (RegExp(r'^[一-龥]{1,6}[组部车间科班线]$').hasMatch(s)) return true;
    const commonDepts = [
      '车缝', '包装', '质检', '裁剪', '烫工', '手工',
      '后勤', '管理', '销售', '仓库', '设计', '版房',
    ];
    for (final d in commonDepts) {
      if (s.contains(d)) return true;
    }
    return false;
  }
}
