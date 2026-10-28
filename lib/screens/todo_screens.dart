import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/todo_service.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController _taskController =
      TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  // Add a task
  Future<void> _addTodo() async {
    final task = _taskController.text.trim();

    if (task.isEmpty) return;

    try {
      await TodoService.addTodo(task);
      _taskController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully')),
      );
    } catch (e) {
      _showError('Could not add task: $e');
    }
  }

  // Mark a task complete or incomplete
  Future<void> _toggleTodo(
    String id,
    bool currentStatus,
  ) async {
    try {
      await TodoService.toggleTodo(id, currentStatus);
    } catch (e) {
      _showError('Could not update task: $e');
    }
  }

  // Delete a task
  Future<void> _deleteTodo(String id) async {
    try {
      await TodoService.deleteTodo(id);
    } catch (e) {
      _showError('Could not delete task: $e');
    }
  }

  // Edit a task
  Future<void> _editTodo(
    String id,
    String currentTask,
  ) async {
    final editController =
        TextEditingController(text: currentTask);

    final newTask = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  editController.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newTask == null || newTask.isEmpty) return;

    try {
      await TodoService.updateTodo(id, newTask);
    } catch (e) {
      _showError('Could not edit task: $e');
    }
  }

  // Delete all completed tasks
  Future<void> _deleteCompletedTodos() async {
    try {
      await TodoService.deleteCompletedTodos();
    } catch (e) {
      _showError('Could not delete completed tasks: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My To-Do List'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
            },
          ),
          IconButton(
            tooltip: 'Delete completed tasks',
            icon: const Icon(Icons.cleaning_services),
            onPressed: _deleteCompletedTodos,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input field and Add button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Enter a task',
                      hintText: 'What do you need to do?',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Live task list from Firebase
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: TodoService.getTodosStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading tasks:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final documents =
                      snapshot.data?.docs ?? [];

                  if (documents.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tasks yet. Add your first task!',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final todo = documents[index];
                      final data = todo.data();

                      final String task =
                          data['task'] as String? ?? '';

                      final bool isCompleted =
                          data['completed'] as bool? ?? false;

                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: ListTile(
                          // Visible checkbox for completion
                          leading: Checkbox(
                            value: isCompleted,
                            onChanged: (value) {
                              if (value != null) {
                                _toggleTodo(
                                  todo.id,
                                  isCompleted,
                                );
                              }
                            },
                          ),

                          // Completed tasks get a strikethrough
                          title: Text(
                            task,
                            style: TextStyle(
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: isCompleted
                                  ? Colors.grey
                                  : null,
                            ),
                          ),

                          // Edit and delete buttons
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Edit task',
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _editTodo(
                                  todo.id,
                                  task,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete task',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _deleteTodo(todo.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}