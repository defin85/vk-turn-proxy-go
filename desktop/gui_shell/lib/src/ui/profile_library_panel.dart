import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';

class ProfileLibraryPanel extends StatelessWidget {
  const ProfileLibraryPanel({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.busy,
    required this.onSelectProfile,
    required this.onCreateDraft,
  });

  final List<ProfileRecord> profiles;
  final String? selectedProfileId;
  final bool busy;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Saved profiles',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onCreateDraft,
                  child: const Text('New draft'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a saved profile or switch to an unsaved draft without mixing the profile library into the active editor.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectedProfileId == null
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.36,
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    selectedProfileId == null
                        ? Icons.edit_note_outlined
                        : Icons.folder_copy_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          selectedProfileId == null
                              ? 'Unsaved draft active'
                              : 'Saved profile active',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedProfileId == null
                              ? 'The workspace is editing a draft that is not yet saved in the profile library.'
                              : 'The workspace is currently bound to a saved profile selection from this library.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: profiles.isEmpty
                  ? Center(
                      child: Text(
                        'No saved profiles yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey<String>('profile-library-scroll'),
                      itemCount: profiles.length,
                      separatorBuilder: (_, int index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final profile = profiles[index];
                        final selected = selectedProfileId == profile.id;
                        return Material(
                          color: selected
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            key: ValueKey<String>(
                              'profile-library-item-${profile.id}',
                            ),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onSelectProfile(profile.id),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          profile.name.isEmpty
                                              ? profile.id
                                              : profile.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      if (selected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'Editing',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    profile.spec.provider,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${profile.spec.listenAddress} -> ${profile.spec.peerAddress}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
