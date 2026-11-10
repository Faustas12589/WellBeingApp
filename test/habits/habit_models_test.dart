import 'package:flutter_test/flutter_test.dart';
import 'package:well_being_app/features/habits/models/models.dart';
import 'package:well_being_app/features/habits/utils/goalProgress.dart';

void main() {
  group('RatingValue JSON', () {
    test('round-trips each value type', () {
      const values = <RatingValue>[
        BoolValue(true),
        NumberValue(42),
        EnumValue('morning'),
      ];
      for (final v in values) {
        final restored = RatingValue.fromJson(v.toJson());
        expect(restored.runtimeType, v.runtimeType);
        expect(restored.toJson(), v.toJson());
      }
    });

    test('throws on unknown type', () {
      expect(() => RatingValue.fromJson({'t': 'x', 'v': 1}), throwsArgumentError);
    });
  });

  group('DayLog', () {
    test('formats date as yyyy-mm-dd', () {
      final log = DayLog(dateUtc: DateTime.utc(2025, 3, 7), entries: const {});
      expect(log.yyyymmdd, '2025-03-07');
    });

    test('setValue and removeValue do not mutate the original', () {
      final empty = DayLog(dateUtc: DateTime.utc(2025, 1, 1), entries: const {});
      final withValue = empty.setValue('run', const BoolValue(true));

      expect(empty.getValue('run'), isNull);
      expect((withValue.getValue('run') as BoolValue).value, isTrue);
      expect(withValue.removeValue('run').getValue('run'), isNull);
    });

    test('round-trips through JSON', () {
      final log = DayLog(dateUtc: DateTime.utc(2025, 12, 31), entries: const {})
          .setValue('gym', const BoolValue(true))
          .setValue('steps', const NumberValue(8500));

      final restored = DayLog.fromJson(log.toJson());
      expect(restored.dateUtc, log.dateUtc);
      expect(restored.toJson(), log.toJson());
    });
  });

  group('Habit JSON', () {
    test('round-trips with defaults', () {
      const habit = Habit(id: 'h1', name: 'Read', kind: RatingKind.scale, min: 1, max: 5);
      final restored = Habit.fromJson(habit.toJson());

      expect(restored.toJson(), habit.toJson());
      expect(restored.archived, isFalse);
    });
  });

  group('goalValueOf', () {
    test('checkbox counts only true', () {
      const habit = Habit(id: 'h', name: 'Gym', kind: RatingKind.checkbox);
      expect(goalValueOf(const BoolValue(true), habit), 1);
      expect(goalValueOf(const BoolValue(false), habit), 0);
      expect(goalValueOf(null, habit), 0);
    });

    test('number and steps use the rounded value', () {
      const number = Habit(id: 'h', name: 'Water', kind: RatingKind.number);
      const steps = Habit(id: 's', name: 'Steps', kind: RatingKind.steps);
      expect(goalValueOf(const NumberValue(2.6), number), 3);
      expect(goalValueOf(const NumberValue(9000), steps), 9000);
    });

    test('scale counts when moved off the minimum', () {
      const habit = Habit(id: 'h', name: 'Focus', kind: RatingKind.scale, min: 1, max: 5);
      expect(goalValueOf(const NumberValue(1), habit), 0);
      expect(goalValueOf(const NumberValue(4), habit), 1);
    });

    test('enum counts when not the first option', () {
      const habit = Habit(
        id: 'h',
        name: 'Sleep',
        kind: RatingKind.enumerator,
        options: ['none', 'bad', 'good'],
      );
      expect(goalValueOf(const EnumValue('none'), habit), 0);
      expect(goalValueOf(const EnumValue('good'), habit), 1);
    });

    test('wrong value type counts as zero', () {
      const habit = Habit(id: 'h', name: 'Gym', kind: RatingKind.checkbox);
      expect(goalValueOf(const NumberValue(1), habit), 0);
    });
  });
}
