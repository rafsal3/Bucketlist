import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
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
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Bucket List',
            theme: appState.isDarkMode
                ? AppTheme.darkTheme(appState.themeColor)
                : AppTheme.lightTheme(appState.themeColor),
            // Route based on authentication state
            home: appState.isLoading
                ? Scaffold(
                    backgroundColor: appState.isDarkMode
                        ? const Color(0xFF121212)
                        : Colors.white,
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : appState.isAuthenticated
                    ? const HomeScreen()
                    : const LoginScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
