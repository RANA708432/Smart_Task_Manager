// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/task_model.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_application_1/utils/validators.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('validates email and password with the expected patterns', () {
    expect(Validators.email('person@example.com'), isNull);
    expect(Validators.email('not-an-email'), isNotNull);
    expect(Validators.password('Secure123'), isNull);
    expect(Validators.password('short'), isNotNull);
  });

  test('rejects invalid registration and sign-in input before querying the database', () async {
    final auth = AuthService();

    await expectLater(
      auth.register(
        name: '   ',
        email: 'invalid-email',
        password: 'short',
      ),
      throwsA(isA<AuthServiceException>()),
    );

    await expectLater(
      auth.signIn(email: 'bad-email', password: 'Secure123'),
      throwsA(isA<AuthServiceException>()),
    );
  });

  testWidgets('shows local sign-in when no local account is signed in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SmartTaskManagerApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  test('stores local accounts and tasks in SQLite', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp(
      'smart_task_manager_test_',
    );
    final database = DatabaseService.withPathForTesting(
      '${directory.path}${Platform.pathSeparator}test.db',
    );

    try {
      await database.initialize();
      final auth = AuthService(database: database);
      final user = await auth.register(
        name: 'Test User',
        email: 'test@example.com',
        password: 'Secure123',
      );

      await auth.signOut();
      await expectLater(
        auth.signIn(email: user.email, password: 'Incorrect123'),
        throwsA(isA<AuthServiceException>()),
      );
      final signedInUser = await auth.signIn(
        email: user.email,
        password: 'Secure123',
      );
      expect(signedInUser.id, user.id);
      expect(await database.getCurrentUserId(), user.id);

      final task = TaskModel(
        id: '',
        title: 'SQLite task',
        description: 'Persist this task locally',
        dueDate: DateTime.utc(2026, 11, 7),
        status: TaskStatus.pending,
      );
      await database.createTask(user.id, task);

      final savedTasks = await database.getTasks(user.id);
      expect(savedTasks, hasLength(1));
      expect(savedTasks.single.title, task.title);
      expect(savedTasks.single.status, TaskStatus.pending);
    } finally {
      AuthService.currentUserNotifier.value = null;
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
