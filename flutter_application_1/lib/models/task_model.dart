enum TaskStatus { pending, inProgress, completed }

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
    TaskStatus.pending => 'To do',
    TaskStatus.inProgress => 'In progress',
    TaskStatus.completed => 'Completed',
  };
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final DateTime? createdAt;

  factory TaskModel.fromMap(Map<String, Object?> row) {
    final id = row['id'];
    final rawStatus = row['status'];
    final rawDueDate = row['due_date'];
    final rawCreatedAt = row['created_at'];
    if (id is! int ||
        rawStatus is! String ||
        rawDueDate is! String ||
        rawCreatedAt is! String) {
      throw const FormatException('Task record has invalid fields.');
    }

    final status = TaskStatus.values
        .where((value) => value.name == rawStatus)
        .firstOrNull;
    if (status == null) {
      throw FormatException('Task $id has an invalid status.');
    }

    return TaskModel(
      id: id.toString(),
      title: row['title'] as String,
      description: row['description'] as String,
      dueDate: DateTime.parse(rawDueDate),
      status: status,
      createdAt: DateTime.parse(rawCreatedAt),
    );
  }

  Map<String, Object?> toDatabaseMap() {
    return {
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
}
