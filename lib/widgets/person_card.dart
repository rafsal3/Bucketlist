import 'package:flutter/material.dart';
import '../models/person_model.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const PersonCard({
    super.key,
    required this.person,
    this.onRemove,
    this.onTap,
  });

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _hexToColor(person.avatarColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: avatarColor,
          child: Text(
            person.initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          person.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Code: ${person.uniqueCode}',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 12,
          ),
        ),
        trailing: onRemove != null
            ? IconButton(
                icon:
                    Icon(Icons.person_remove_outlined, color: Colors.red[400]),
                onPressed: onRemove,
              )
            : null,
      ),
    );
  }
}
