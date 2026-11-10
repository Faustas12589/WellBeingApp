import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/diary_entry_model.dart';
import '../../data/models/diary_question_model.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/diary_question_repository.dart';
import '../../data/repositories/user_repository.dart';

class DiaryProvider extends ChangeNotifier {
  final DiaryRepository _repository = DiaryRepository();
  final DiaryQuestionRepository _questionRepository = DiaryQuestionRepository();
  late String userId;

  // stream and entries
  StreamSubscription? _entriesSub;
  List<DiaryEntryModel> allEntries = [];
  Map<DateTime, List<DiaryEntryModel>> entriesByDate = {};

  // form data
  String selectedMood = "";
  File? selectedImage;
  List<String> categories = [];
  String selectedUploadCategory = '';
  List<DiaryQuestionModel> currentQuestions = [];
  bool questionsLoaded = false;
  bool isPremium = false;

  final textControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // Calendar state
  DateTime currentMonth = DateTime.now();
  DateTime? selectedDay;

  // Memories state
  int memoriesViewIndex = 0;
  String? selectedCategoryView;
  bool isSelectionMode = false;
  Set<String> selectedForDeletion = {};

  // Saved to the database in Lithuanian; shown via LanguageNotifier.moodLabel.
  final List<String> moods = ['Puikiai', 'Gerai', 'Normaliai', 'Prastai', 'Blogai'];



  /// Categories created the first time, in the user's language.
  final List<String> defaultCategories;

  DiaryProvider({this.defaultCategories = const []}) {
    userId = FirebaseAuth.instance.currentUser!.uid;
    _init();
  }

  Future<void> _init() async {
    _loadUserPremiumStatus();
    _loadCategories();
    loadQuestions();
    
    _entriesSub = _repository.streamEntries(userId).listen((entries) {
      allEntries = entries;
      _groupEntries(entries);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    for (var c in textControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _groupEntries(List<DiaryEntryModel> entries) {
    entriesByDate = {};
    for (var e in entries) {
      DateTime date = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      (entriesByDate[date] ??= []).add(e);
    }
  }

  Future<void> _loadUserPremiumStatus() async { // ----premium checker
    final user = await UserRepository().getUser(userId);
    if (user != null) {
      isPremium = user.premium;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('diary_settings')
          .doc('categories')
          .get();

      if (doc.exists && doc.data() != null && doc.data()!['list'] != null) {
        categories = List<String>.from(doc.data()!['list']);
        selectedUploadCategory = categories.isNotEmpty ? categories.first : '';
      } else {
        categories = List<String>.from(defaultCategories);
        selectedUploadCategory = categories.isNotEmpty ? categories.first : '';
        saveCategories();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  Future<void> saveCategories() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('diary_settings')
          .doc('categories')
          .set({'list': categories});
    } catch (e) {
      debugPrint("Error saving categories: $e");
    }
  }

  void addCategory(String category) {
    categories.add(category);
    if (categories.length == 1) selectedUploadCategory = category;
    saveCategories();
    notifyListeners();
  }

  void deleteCategory(String category) {
    categories.remove(category);
    if (selectedUploadCategory == category) {
      selectedUploadCategory = categories.isNotEmpty ? categories.first : '';
    }
    saveCategories();
    notifyListeners();
  }

  Future<void> loadQuestions() async {
    try {
      currentQuestions = await _questionRepository.getOneRandomFromEachCategory(['highlight', 'reflect', 'gratitude']);
      questionsLoaded = true;
      notifyListeners();
    } catch (e) {
      questionsLoaded = true;
      notifyListeners();
    }
  }

  // State setters used by the UI
  void setMood(String mood) {
    selectedMood = mood;
    notifyListeners();
  }

  void setUploadCategory(String cat) {
    selectedUploadCategory = cat;
    notifyListeners();
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      selectedImage = File(pickedFile.path);
      notifyListeners();
    }
  }

  void clearImage() {
    selectedImage = null;
    notifyListeners();
  }

  void setMonth(DateTime month) {
    currentMonth = month;
    notifyListeners();
  }

  void setDay(DateTime day) {
    selectedDay = day;
    notifyListeners();
  }

  void toggleSelectionMode(String id) {
    isSelectionMode = true;
    if (selectedForDeletion.contains(id)) {
      selectedForDeletion.remove(id);
      if (selectedForDeletion.isEmpty) isSelectionMode = false;
    } else {
      selectedForDeletion.add(id);
    }
    notifyListeners();
  }

  void closeSelectionMode() {
    isSelectionMode = false;
    selectedForDeletion.clear();
    notifyListeners();
  }

  void setMemoriesView(int index) {
    memoriesViewIndex = index;
    selectedCategoryView = null;
    closeSelectionMode();
  }

  void setCategoryView(String? cat) {
    selectedCategoryView = cat;
    closeSelectionMode();
  }

  // Free-tier limits
  DateTime _weekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  int get entriesThisWeek => allEntries.where((e) => !e.createdAt.isBefore(_weekStart())).length;
  int get photosThisWeek => allEntries.where((e) => !e.createdAt.isBefore(_weekStart()) && e.imageUrl != null).length;

  bool get canAddEntry => isPremium || entriesThisWeek < 2;
  bool get canAddPhoto => isPremium || photosThisWeek < 3;

  // Saving
  Future<(bool, int, int)> saveEntry(String moodImagePath) async {
    final now = DateTime.now();
    final id = '${now.millisecondsSinceEpoch}';
    String? uploadedImageUrl;

    if (selectedImage != null) {
      final ref = FirebaseStorage.instance.ref().child('users').child(userId).child('diary_images').child('$id.jpg');
      final task = await ref.putFile(selectedImage!);
      uploadedImageUrl = await task.ref.getDownloadURL();
    }

    final preview = textControllers[0].text.isNotEmpty ? textControllers[0].text
        : textControllers[3].text; // empty preview is shown as a translated "Empty entry"

    String? finalCategory;
    if (selectedImage != null && categories.isNotEmpty) {
      finalCategory = categories.contains(selectedUploadCategory) ? selectedUploadCategory : categories.first;
    }

    await _repository.addEntry(
      userId,
      DiaryEntryModel(
        id: id,
        createdAt: now,
        highlight: textControllers[0].text,
        better: textControllers[1].text,
        gratitude: textControllers[2].text,
        diaryText: textControllers[3].text,
        preview: preview.length > 50 ? '${preview.substring(0, 47)}...' : preview,
        imageUrl: uploadedImageUrl,
        category: finalCategory,
        moodImage: moodImagePath,
        mood: selectedMood,
      ),
    );

    // Reset the form
    selectedMood = "";
    selectedImage = null;
    for (var c in textControllers) { c.clear(); }
    loadQuestions();
    notifyListeners();

    // XP
    final (granted: gotXp, oldLevel: o, newLevel: n) = await UserRepository().tryGiveDiaryXp(userId, 20);
    return (gotXp, o, n);
  }

  Future<void> deleteSelectedImages() async {
    final memories = allEntries.where((e) => e.imageUrl != null).toList();
    for (String id in selectedForDeletion) {
      final entry = memories.firstWhere((e) => e.id == id);
      if (entry.imageUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(entry.imageUrl!).delete();
        } catch (_) {}
      }

      final updatedEntry = DiaryEntryModel(
        id: entry.id, createdAt: entry.createdAt, mood: entry.mood, highlight: entry.highlight,
        better: entry.better, gratitude: entry.gratitude, diaryText: entry.diaryText,
        preview: entry.preview, imageUrl: null, category: entry.category,   moodImage: entry.moodImage,

      );
      await _repository.addEntry(userId, updatedEntry);
    }
    closeSelectionMode();
  }
}