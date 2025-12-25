import 'package:flutter/material.dart';
import '../models/person_model.dart';

class CompletionAvatars extends StatelessWidget {
  final List<Person> completedUsers;
  final List<Person> allUsers;
  final double size;

  const CompletionAvatars({
    super.key,
    required this.completedUsers,
    required this.allUsers,
    this.size = 24,
  });

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (allUsers.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show stacked avatars
        SizedBox(
          width: size * (allUsers.length > 1 ? allUsers.length * 0.7 : 1),
          height: size,
          child: Stack(
            children: allUsers.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              final isCompleted = completedUsers.any((p) => p.id == user.id);
              final offset = index * (size * 0.6);

              return Positioned(
                left: offset,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: size / 2,
                        backgroundColor: _hexToColor(user.avatarColor),
                        child: Text(
                          user.initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: size * 0.4,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.3),
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: size * 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${completedUsers.length}/${allUsers.length}',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w600,
            color: completedUsers.length == allUsers.length
                ? Colors.green
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}
