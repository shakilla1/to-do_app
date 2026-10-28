import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TodoService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _todosCollection {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  return _firestore.collection('users').doc(userId).collection('todos');
}

  // Add a new task
  static Future<void> addTodo(String task) async {
    await _todosCollection.add({
      'task': task,
      'completed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get tasks from Firebase in real time
  static Stream<QuerySnapshot<Map<String, dynamic>>>
      getTodosStream() {
    return _todosCollection
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark a task complete or incomplete
  static Future<void> toggleTodo(
    String id,
    bool currentStatus,
  ) async {
    await _todosCollection.doc(id).update({
      'completed': !currentStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Edit a task
  static Future<void> updateTodo(
    String id,
    String newTask,
  ) async {
    await _todosCollection.doc(id).update({
      'task': newTask,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete one task
  static Future<void> deleteTodo(String id) async {
    await _todosCollection.doc(id).delete();
  }

  // Delete all completed tasks
  static Future<void> deleteCompletedTodos() async {
    final snapshot = await _todosCollection
        .where('completed', isEqualTo: true)
        .get();

    final batch = _firestore.batch();

    for (final document in snapshot.docs) {
      batch.delete(document.reference);
    }

    await batch.commit();
  }
}