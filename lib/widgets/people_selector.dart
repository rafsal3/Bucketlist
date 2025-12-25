import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class PeopleSelector extends StatefulWidget {
  final List<String> selectedPersonIds;
  final Function(List<String>) onSelectionChanged;

  const PeopleSelector({
    super.key,
    required this.selectedPersonIds,
    required this.onSelectionChanged,
  });

  @override
  State<PeopleSelector> createState() => _PeopleSelectorState();
}

class _PeopleSelectorState extends State<PeopleSelector> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedPersonIds);
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _togglePerson(String personId) {
    setState(() {
      if (_selectedIds.contains(personId)) {
        _selectedIds.remove(personId);
      } else {
        _selectedIds.add(personId);
      }
    });
    widget.onSelectionChanged(_selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final people = appState.people;

    if (people.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No connections yet',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add people from Settings → People',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected people chips
        if (_selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedIds.map((personId) {
                final person = people.firstWhere((p) => p.id == personId);
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: _hexToColor(person.avatarColor),
                    child: Text(
                      person.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(person.name),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _togglePerson(personId),
                );
              }).toList(),
            ),
          ),

        // People list
        Text(
          'Select collaborators:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        ...people.map((person) {
          final isSelected = _selectedIds.contains(person.id);
          return CheckboxListTile(
            value: isSelected,
            onChanged: (value) => _togglePerson(person.id),
            title: Text(
              person.name,
              style: TextStyle(
                color: Theme.of(context).textTheme.titleMedium?.color,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              person.uniqueCode,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 12,
              ),
            ),
            secondary: CircleAvatar(
              backgroundColor: _hexToColor(person.avatarColor),
              child: Text(
                person.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ],
    );
  }
}
