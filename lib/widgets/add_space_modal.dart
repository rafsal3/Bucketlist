import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'people_selector.dart';

class AddSpaceModal extends StatefulWidget {
  final String? spaceId;
  final String? initialName;
  final String? initialIcon;

  const AddSpaceModal({
    super.key,
    this.spaceId,
    this.initialName,
    this.initialIcon,
  });

  @override
  State<AddSpaceModal> createState() => _AddSpaceModalState();
}

class _AddSpaceModalState extends State<AddSpaceModal> {
  late TextEditingController _nameController;
  late String _selectedEmoji;
  bool _isShared = false;
  List<String> _selectedPeople = [];

  // Reusing same emoji list for consistency
  final List<String> _emojiOptions = [
    '🚀',
    '🏠',
    '💼',
    '🎨',
    '🎓',
    '✈️',
    '💪',
    '🎪',
    '🧩',
    '📚',
    '💡',
    '🌱',
    '⭐',
    '🎯',
    '🎸',
    '🎮',
    '🍳',
    '📷',
    '🏔️',
    '🌊',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedEmoji = widget.initialIcon ?? '🚀';

    // Load existing collaborators if editing
    if (widget.spaceId != null) {
      final appState = Provider.of<AppState>(context, listen: false);
      final space = appState.spaces.firstWhere((s) => s.id == widget.spaceId);
      _isShared = space.isShared;
      _selectedPeople = List.from(space.collaboratorIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveSpace() {
    if (_nameController.text.trim().isEmpty) return;

    final appState = Provider.of<AppState>(context, listen: false);

    if (widget.spaceId != null) {
      appState.editSpace(
        widget.spaceId!,
        _nameController.text.trim(),
        _selectedEmoji,
      );

      // Update collaborators if shared
      if (_isShared && _selectedPeople.isNotEmpty) {
        appState.addCollaboratorsToSpace(widget.spaceId!, _selectedPeople);
      }
    } else {
      appState.addSpace(_nameController.text.trim(), _selectedEmoji);

      // Add collaborators if shared
      if (_isShared && _selectedPeople.isNotEmpty) {
        final newSpaceId = appState.currentSpace.id;
        appState.addCollaboratorsToSpace(newSpaceId, _selectedPeople);
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.spaceId != null;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              isEditing ? 'Edit Space' : 'New Space',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            SizedBox(height: 24),

            // Space Name Input
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Space name (e.g. Work, Home)',
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _saveSpace(),
            ),
            SizedBox(height: 24),

            // Emoji Picker
            Text(
              'Choose an icon',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 12),
            Container(
              height: 80,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _emojiOptions.length,
                itemBuilder: (context, index) {
                  final emoji = _emojiOptions[index];
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),

            // Shared Space Toggle
            SwitchListTile(
              value: _isShared,
              onChanged: (value) {
                setState(() {
                  _isShared = value;
                });
              },
              title: Text(
                'Shared Space',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              subtitle: Text(
                'Collaborate with others',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 12,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),

            // People Selector (shown when shared is enabled)
            if (_isShared) ...[
              SizedBox(height: 16),
              PeopleSelector(
                selectedPersonIds: _selectedPeople,
                onSelectionChanged: (selected) {
                  setState(() {
                    _selectedPeople = selected;
                  });
                },
              ),
            ],
            SizedBox(height: 24),

            // Create/Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSpace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Create Space',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
