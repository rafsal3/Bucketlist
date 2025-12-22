import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Customization'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return ListView(
              padding: EdgeInsets.all(24),
              children: [
                Text(
                  'Theme Color',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose your preferred accent color',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 24),
                _buildColorGrid(context, appState),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildColorGrid(BuildContext context, AppState appState) {
    final colors = {
      'blue': {'name': 'Blue', 'color': AppTheme.accentColors['blue']!},
      'purple': {'name': 'Purple', 'color': AppTheme.accentColors['purple']!},
      'green': {'name': 'Green', 'color': AppTheme.accentColors['green']!},
      'orange': {'name': 'Orange', 'color': AppTheme.accentColors['orange']!},
      'pink': {'name': 'Pink', 'color': AppTheme.accentColors['pink']!},
      'teal': {'name': 'Teal', 'color': AppTheme.accentColors['teal']!},
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final colorKey = colors.keys.elementAt(index);
        final colorData = colors[colorKey]!;
        final isSelected = appState.themeColor == colorKey;

        return GestureDetector(
          onTap: () {
            appState.setThemeColor(colorKey);
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: colorData['color'] as Color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (colorData['color'] as Color).withOpacity(0.4),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 32,
                        ),
                      if (isSelected) SizedBox(height: 8),
                      Text(
                        colorData['name'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: isSelected ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
