import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/category_model.dart';
import 'models/space_model.dart';
import 'screens/home_screen.dart';
// import 'widgets/book_search_example.dart'; // Import the example widget
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(ChecklistItemAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(SpaceAdapter());

  // Open Boxes
  await Hive.openBox<Space>('spaces');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Bucket List',
            theme: appState.isDarkMode
                ? AppTheme.darkTheme(appState.themeColor)
                : AppTheme.lightTheme(appState.themeColor),
            // Temporarily show the book search example for testing
            // Change back to HomeScreen() when done testing
            // home: const BookSearchExample(), // Testing books integration
            home: const HomeScreen(), // Original home screen
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
