import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryQuestionModel {
  final String id;
  final String question;
  /// Optional English text (Firestore field `question_en`).
  final String? questionEn;
  final int maxLines;
  final String category; // e.g., "highlight", "reflect", "gratitude", etc.

  DiaryQuestionModel({
    required this.id,
    required this.question,
    this.questionEn,
    this.maxLines = 2,
    this.category = 'general',
  });

  /// Question text for the given locale code ('lt' or 'en').
  /// Falls back to the Lithuanian text if no English version exists.
  String textFor(String locale) {
    if (locale == 'en' && questionEn != null && questionEn!.isNotEmpty) {
      return questionEn!;
    }
    return question;
  }

  factory DiaryQuestionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return DiaryQuestionModel(
      id: doc.id,
      question: data['question'] ?? '',
      questionEn: data['question_en'] as String?,
      maxLines: data['maxLines'] ?? 2,
      category: data['category'] ?? 'general',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      if (questionEn != null) 'question_en': questionEn,
      'maxLines': maxLines,
      'category': category,
    };
  }
}
