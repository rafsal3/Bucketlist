import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'widgets/book_search_example.dart'; // Import the example widget
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'providers/category_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CategoryProvider(),
      child: MaterialApp(
        title: 'Bucket List',
        theme: AppTheme.darkTheme,
        // Temporarily show the book search example for testing
        // Change back to HomeScreen() when done testing
        home: const BookSearchExample(), // Testing books integration
        // home: const HomeScreen(), // Original home screen
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
