import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// --- Data Model ---
class Meal {
  final String id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final DateTime timestamp;

  Meal({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.timestamp,
  });

  // Factory constructor to create a Meal from a Firestore document
  factory Meal.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Meal(
      id: doc.id,
      name: data['name'] ?? '',
      calories: data['calories'] ?? 0,
      protein: data['protein'] ?? 0,
      carbs: data['carbs'] ?? 0,
      fat: data['fat'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

// --- Main Entry Point ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const NutritionApp());
}

class NutritionApp extends StatelessWidget {
  const NutritionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition Tracker',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF0A0E21),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        colorScheme: const ColorScheme.dark().copyWith(
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Authentication Wrapper ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Sign in anonymously for this simple example
    FirebaseAuth.instance.signInAnonymously();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return NutritionHomePage(userId: snapshot.data!.uid);
        }
        return const Scaffold(body: Center(child: Text("Please sign in")));
      },
    );
  }
}


// --- Home Page ---
class NutritionHomePage extends StatelessWidget {
  final String userId;
  const NutritionHomePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final mealsCollection = firestore.collection('users').doc(userId).collection('meals');

    // Get today's date at midnight for filtering
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Nutrition')),
      body: StreamBuilder<QuerySnapshot>(
        stream: mealsCollection
            .where('timestamp', isGreaterThanOrEqualTo: today)
            .where('timestamp', isLessThan: tomorrow)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No meals logged for today."));
          }

          final meals = snapshot.data!.docs.map((doc) => Meal.fromFirestore(doc)).toList();
          
          // Calculate totals
          final totalCalories = meals.fold(0, (sum, item) => sum + item.calories);
          final totalProtein = meals.fold(0, (sum, item) => sum + item.protein);
          final totalCarbs = meals.fold(0, (sum, item) => sum + item.carbs);
          final totalFat = meals.fold(0, (sum, item) => sum + item.fat);

          return Column(
            children: [
              // Summary Cards
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  childAspectRatio: 2.5,
                  children: [
                    _buildSummaryCard('Calories', '$totalCalories kcal', Colors.orange),
                    _buildSummaryCard('Protein', '$totalProtein g', Colors.green),
                    _buildSummaryCard('Carbs', '$totalCarbs g', Colors.blue),
                    _buildSummaryCard('Fat', '$totalFat g', Colors.red),
                  ],
                ),
              ),
              // Meal List
              Expanded(
                child: ListView.builder(
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(meal.name),
                        subtitle: Text('${meal.calories} kcal'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => mealsCollection.doc(meal.id).delete(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMealDialog(context, mealsCollection),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  void _showAddMealDialog(BuildContext context, CollectionReference mealsCollection) {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log a New Meal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Meal Name')),
                TextField(controller: caloriesController, decoration: const InputDecoration(labelText: 'Calories'), keyboardType: TextInputType.number),
                TextField(controller: proteinController, decoration: const InputDecoration(labelText: 'Protein (g)'), keyboardType: TextInputType.number),
                TextField(controller: carbsController, decoration: const InputDecoration(labelText: 'Carbs (g)'), keyboardType: TextInputType.number),
                TextField(controller: fatController, decoration: const InputDecoration(labelText: 'Fat (g)'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                // Add meal to Firestore
                mealsCollection.add({
                  'name': nameController.text,
                  'calories': int.tryParse(caloriesController.text) ?? 0,
                  'protein': int.tryParse(proteinController.text) ?? 0,
                  'carbs': int.tryParse(carbsController.text) ?? 0,
                  'fat': int.tryParse(fatController.text) ?? 0,
                  'timestamp': Timestamp.now(),
                });
                Navigator.of(context).pop();
              },
              child: const Text('Log Meal'),
            ),
          ],
        );
      },
    );
  }
}
