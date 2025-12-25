import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
// import 'widgets/book_search_example.dart'; // Import the example widget
import 'theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final appState = AppState();
        // Initialize dummy data for testing collaboration features
        Future.delayed(Duration(milliseconds: 500), () {
          appState.generateDummyPeople();
          appState.generateDummyNotifications();
        });
        return appState;
      },
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
