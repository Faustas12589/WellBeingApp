import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../features/habits/models/habit.dart';
import '../features/habits/models/goalsModel.dart';
import '../features/habits/models/ratingKind.dart';
import '../services/language_notifier.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {

  bool fitness = false;
  bool sleep = false;
  bool productivity = false;

  bool running = false;
  bool gym = false;
  bool walking = false;

  final runningKmController = TextEditingController();
  final gymDaysController = TextEditingController();
  final walkingStepsController = TextEditingController();
  final sleepHoursController = TextEditingController();
  final productivityHoursController = TextEditingController();

  // Creates a habit and a matching goal that points to it
  Future<void> _createHabitWithGoal({
    required String userId,
    required String habitName,
    required RatingKind kind,
    required int target,
    required GoalPeriod period,
    required String goalName,
    int? min,
    int? max,
  }) async {
    final db = FirebaseFirestore.instance;

    // Firestore generates the ID
    final habitRef = db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc();

    final habit = Habit(
      id: habitRef.id,
      name: habitName,
      kind: kind,
      min: min,
      max: max,
    );

    await habitRef.set(habit.toJson());

    // Goal linked to the same habit ID
    final goalRef = db
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc();

    final goal = Goal(
      id: goalRef.id,
      name: goalName,
      habbitID: habit.id,
      target: target,
      period: period,
      repeat: true,
    );

    await goalRef.set(goal.toJson());
  }

  // Save every selected answer as a habit + goal.
  // Habit and goal names are created in the user's current language.
  Future<void> saveToFirebase(LanguageNotifier lang) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    // Ignore empty or non-numeric answers instead of crashing.
    int? read(TextEditingController c) => int.tryParse(c.text.trim());

    final runningKm = read(runningKmController);
    if (fitness && running && runningKm != null) {
      await _createHabitWithGoal(
        userId: userId,
        habitName: lang.t('q_running'),
        kind: RatingKind.number,
        target: runningKm,
        period: GoalPeriod.week,
        goalName: lang.tp('q_goal_running', {'n': runningKm}),
        min: 0,
        max: 200,
      );
    }

    final gymDays = read(gymDaysController);
    if (fitness && gym && gymDays != null) {
      await _createHabitWithGoal(
        userId: userId,
        habitName: lang.t('q_gym'),
        kind: RatingKind.checkbox,
        target: gymDays,
        period: GoalPeriod.week,
        goalName: lang.tp('q_goal_gym', {'n': gymDays}),
      );
    }

    final walkingSteps = read(walkingStepsController);
    if (fitness && walking && walkingSteps != null) {
      await _createHabitWithGoal(
        userId: userId,
        habitName: lang.t('q_walking'),
        kind: RatingKind.number,
        target: walkingSteps,
        period: GoalPeriod.day,
        goalName: lang.tp('q_goal_walking', {'n': walkingSteps}),
        min: 0,
        max: 50000,
      );
    }

    final sleepHours = read(sleepHoursController);
    if (sleep && sleepHours != null) {
      await _createHabitWithGoal(
        userId: userId,
        habitName: lang.t('q_sleep'),
        kind: RatingKind.number,
        target: sleepHours,
        period: GoalPeriod.day,
        goalName: lang.tp('q_goal_sleep', {'n': sleepHours}),
        min: 0,
        max: 24,
      );
    }

    final productivityHours = read(productivityHoursController);
    if (productivity && productivityHours != null) {
      await _createHabitWithGoal(
        userId: userId,
        habitName: lang.t('q_productivity'),
        kind: RatingKind.number,
        target: productivityHours,
        period: GoalPeriod.day,
        goalName: lang.tp('q_goal_productivity', {'n': productivityHours}),
        min: 0,
        max: 24,
      );
    }
  }

  void submit() async {
    final lang = context.read<LanguageNotifier>();
    await saveToFirebase(lang);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.t('q_goals_saved'))),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    runningKmController.dispose();
    gymDaysController.dispose();
    walkingStepsController.dispose();
    sleepHoursController.dispose();
    productivityHoursController.dispose();
    super.dispose();
  }

  Widget numberInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('questionnaire_title')),
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              lang.t('q_what_improve'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            CheckboxListTile(
              title: Text(lang.t('q_fitness')),
              value: fitness,
              onChanged: (val) => setState(() => fitness = val!),
            ),

            CheckboxListTile(
              title: Text(lang.t('q_sleep')),
              value: sleep,
              onChanged: (val) => setState(() => sleep = val!),
            ),

            CheckboxListTile(
              title: Text(lang.t('q_productivity')),
              value: productivity,
              onChanged: (val) => setState(() => productivity = val!),
            ),

            const SizedBox(height: 20),

            if (fitness) ...[
              Text(lang.t('q_pick_sport'), style: const TextStyle(fontWeight: FontWeight.bold)),

              CheckboxListTile(
                title: Text(lang.t('q_running')),
                value: running,
                onChanged: (val) => setState(() => running = val!),
              ),
              if (running)
                numberInput(lang.t('q_running_km'), runningKmController),

              CheckboxListTile(
                title: Text(lang.t('q_gym')),
                value: gym,
                onChanged: (val) => setState(() => gym = val!),
              ),
              if (gym)
                numberInput(lang.t('q_gym_days'), gymDaysController),

              CheckboxListTile(
                title: Text(lang.t('q_walking')),
                value: walking,
                onChanged: (val) => setState(() => walking = val!),
              ),
              if (walking)
                numberInput(lang.t('q_walking_steps'), walkingStepsController),
            ],

            if (sleep)
              numberInput(lang.t('q_sleep_hours'), sleepHoursController),

            if (productivity)
              numberInput(lang.t('q_productivity_hours'), productivityHoursController),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submit,
                child: Text(lang.t('q_submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
