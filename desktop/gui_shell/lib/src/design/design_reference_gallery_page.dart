import 'package:flutter/material.dart';

enum _ReferenceConcept {
  commandCenter,
  focusedWorkflow,
  splitCanvas;

  String get title => switch (this) {
    _ReferenceConcept.commandCenter => 'Command Center',
    _ReferenceConcept.focusedWorkflow => 'Focused Workflow',
    _ReferenceConcept.splitCanvas => 'Split Canvas',
  };

  String get subtitle => switch (this) {
    _ReferenceConcept.commandCenter =>
      'Операторский shell с жесткой иерархией и сильным статусным контуром.',
    _ReferenceConcept.focusedWorkflow =>
      'Редактор одного сценария, где оболочка не спорит с основной задачей.',
    _ReferenceConcept.splitCanvas =>
      'Продуктовый layout с ясным разделением выбора, редактирования и live state.',
  };

  String get fit => switch (this) {
    _ReferenceConcept.commandCenter =>
      'Лучше всего для поддержки, диагностики и fail-closed операций.',
    _ReferenceConcept.focusedWorkflow =>
      'Лучше всего для повседневного path: выбрать, настроить, сохранить, запустить.',
    _ReferenceConcept.splitCanvas =>
      'Лучше всего для смешанного режима: библиотека слева, работа справа, live context снизу.',
  };

  String get principle => switch (this) {
    _ReferenceConcept.commandCenter =>
      'Нагруженные operational surfaces собираются в один уверенный command shell, а не разлетаются по пастельным карточкам.',
    _ReferenceConcept.focusedWorkflow =>
      'Главный поток должен ощущаться как один документ со step-by-step прогрессом, а не как dashboard.',
    _ReferenceConcept.splitCanvas =>
      'Информация разделяется по роли: выбор, редактирование и runtime не конкурируют в одном плоском слое.',
  };
}

class DesignReferenceGalleryPage extends StatefulWidget {
  const DesignReferenceGalleryPage({super.key});

  @override
  State<DesignReferenceGalleryPage> createState() =>
      _DesignReferenceGalleryPageState();
}

class _DesignReferenceGalleryPageState
    extends State<DesignReferenceGalleryPage> {
  _ReferenceConcept _selected = _ReferenceConcept.commandCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final selectorWidth = (constraints.maxWidth - 32) / 3;
              final wideSelector = selectorWidth >= 320;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ReferenceHeader(selected: _selected),
                  const SizedBox(height: 20),
                  if (wideSelector)
                    Row(
                      children: _ReferenceConcept.values.map((concept) {
                        final index = _ReferenceConcept.values.indexOf(concept);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right:
                                  index == _ReferenceConcept.values.length - 1
                                  ? 0
                                  : 16,
                            ),
                            child: _ConceptSelectorCard(
                              key: ValueKey<String>(
                                'reference-concept-${concept.name}',
                              ),
                              concept: concept,
                              selected: concept == _selected,
                              onTap: () => setState(() {
                                _selected = concept;
                              }),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Column(
                      children: _ReferenceConcept.values.map((concept) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ConceptSelectorCard(
                            key: ValueKey<String>(
                              'reference-concept-${concept.name}',
                            ),
                            concept: concept,
                            selected: concept == _selected,
                            onTap: () => setState(() {
                              _selected = concept;
                            }),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _ReferencePreviewFrame(
                        key: ValueKey<_ReferenceConcept>(_selected),
                        concept: _selected,
                        child: switch (_selected) {
                          _ReferenceConcept.commandCenter =>
                            const _CommandCenterReference(),
                          _ReferenceConcept.focusedWorkflow =>
                            const _FocusedWorkflowReference(),
                          _ReferenceConcept.splitCanvas =>
                            const _SplitCanvasReference(),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Static reference mode. Запуск: flutter run -d linux --dart-define=VKTP_DESIGN_REFERENCES=true',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReferenceHeader extends StatelessWidget {
  const _ReferenceHeader({required this.selected});

  final _ReferenceConcept selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Desktop shell reference directions',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Текущий shell страдает не от одного неудачного виджета, а от отсутствия доминирующего сценария. Ниже три намеренно разные статические компоновки под один и тот же provider workflow.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            color: const Color(0xFFF8F1E4),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Selected direction',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected.principle,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const <Widget>[
                      _HeaderTag(label: 'Material 3 layout rules'),
                      _HeaderTag(label: 'No live control plane'),
                      _HeaderTag(label: 'Static approval artifact'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConceptSelectorCard extends StatelessWidget {
  const _ConceptSelectorCard({
    super.key,
    required this.concept,
    required this.selected,
    required this.onTap,
  });

  final _ReferenceConcept concept;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? const Color(0xFFF8F1E4)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.35)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      concept.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'preview',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                concept.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                concept.fit,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferencePreviewFrame extends StatelessWidget {
  const _ReferencePreviewFrame({
    super.key,
    required this.concept,
    required this.child,
  });

  final _ReferenceConcept concept;
  final Widget child;

  static const double _canvasWidth = 1480;
  static const double _canvasHeight = 1400;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        concept.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        concept.principle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    concept.fit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _canvasWidth,
                        height: _canvasHeight,
                        child: child,
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

class _CommandCenterReference extends StatelessWidget {
  const _CommandCenterReference();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        color: const Color(0xFFE3DBCF),
        child: Row(
          children: <Widget>[
            Container(
              width: 88,
              color: const Color(0xFF173B43),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: <Widget>[
                  const _RailBadge(label: 'V'),
                  const SizedBox(height: 18),
                  const _RailIcon(
                    active: true,
                    icon: Icons.fact_check_outlined,
                  ),
                  const SizedBox(height: 12),
                  const _RailIcon(active: false, icon: Icons.tune_outlined),
                  const SizedBox(height: 12),
                  const _RailIcon(active: false, icon: Icons.route_outlined),
                  const Spacer(),
                  const _RailIcon(active: false, icon: Icons.settings_outlined),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const <Widget>[
                              Text(
                                'Operator shell',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5A625F),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Managed providers',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: Color(0xFF14241F),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Host status is compressed into one confident shell bar so the task canvas can dominate the body.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Color(0xFF4D5551),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _StatusCapsule(
                          title: 'Host ready',
                          detail: '127.0.0.1:7777 · sidecar owned by shell',
                          accent: Color(0xFF1D6A57),
                          surface: Color(0xFFF3F6EE),
                        ),
                        const SizedBox(width: 12),
                        const _MiniActionColumn(),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(
                            width: 320,
                            child: _PaneSurface(
                              title: 'Queues',
                              subtitle:
                                  'Navigation stays terse. Secondary taxonomy never pretends to be a dashboard.',
                              background: const Color(0xFFFFFAF2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  _ListBlockHeader(
                                    eyebrow: 'workflows',
                                    title: 'Providers',
                                  ),
                                  SizedBox(height: 10),
                                  _ListOption(
                                    active: true,
                                    title: 'Managed-provider catalog',
                                    detail:
                                        '12 saved records · 2 shipped families',
                                    badge: 'current',
                                  ),
                                  SizedBox(height: 10),
                                  _ListOption(
                                    active: false,
                                    title: 'Profiles',
                                    detail: '4 saved profiles · 1 active draft',
                                    badge: 'secondary',
                                  ),
                                  SizedBox(height: 18),
                                  _ListBlockHeader(
                                    eyebrow: 'seed actions',
                                    title: 'Presets',
                                  ),
                                  SizedBox(height: 10),
                                  _SeedTile(
                                    title: 'VK Calls',
                                    detail: 'Invite-first provider entry',
                                  ),
                                  SizedBox(height: 10),
                                  _SeedTile(
                                    title: 'Generic TURN',
                                    detail: 'Deterministic operator startup',
                                  ),
                                  Spacer(),
                                  _QueueNote(
                                    title: 'Why it feels calmer',
                                    detail:
                                        'Only one primary workflow is highlighted at a time. Presets drop back to seed actions, not a second navigation tree.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _PaneSurface(
                              title: 'Provider record',
                              subtitle:
                                  'The editor reads like a controlled workbench, not a card pile.',
                              background: const Color(0xFFFFFCF7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  _InlineMetricShelf(
                                    items: <String>[
                                      'Shipped family: Generic TURN',
                                      'Reusable fields: none',
                                      'Availability: host overlay only',
                                    ],
                                  ),
                                  SizedBox(height: 18),
                                  _FormSection(
                                    title: 'Family selection',
                                    description:
                                        'The shipped catalog becomes a compact choice row instead of a full card grid.',
                                    children: <Widget>[_FamilyChoiceRow()],
                                  ),
                                  SizedBox(height: 18),
                                  _FormSection(
                                    title: 'Managed record',
                                    description:
                                        'Primary fields stay above the fold. Advanced notes do not crowd the first read.',
                                    children: <Widget>[
                                      _FieldShell(
                                        label: 'Managed record name',
                                        value: 'Generic TURN',
                                      ),
                                      SizedBox(height: 12),
                                      _FieldShell(
                                        label: 'Reusable shell-owned values',
                                        value:
                                            'No reusable fields for this shipped family yet',
                                        muted: true,
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  _ActionStrip(
                                    primary: 'Save managed record',
                                    secondary: 'Apply to profile draft',
                                    tertiary: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 300,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: const <Widget>[
                                _PaneSurface(
                                  title: 'Diagnostics',
                                  subtitle:
                                      'Support data lives in a distinct sidecar lane.',
                                  background: Color(0xFFE9EEF4),
                                  expandBody: false,
                                  child: _DiagnosticStack(),
                                ),
                                SizedBox(height: 16),
                                Expanded(
                                  child: _PaneSurface(
                                    title: 'Live activity',
                                    subtitle:
                                        'Event streams stay visible without hijacking the editor.',
                                    background: Color(0xFFF6F0E4),
                                    child: _ActivityList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedWorkflowReference extends StatelessWidget {
  const _FocusedWorkflowReference();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        color: const Color(0xFFF3EEE7),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: const <Widget>[
                    Expanded(
                      child: Text(
                        'One-path editor for the common operator flow.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C2622),
                        ),
                      ),
                    ),
                    _HeaderStep(label: 'Choose family', active: false),
                    SizedBox(width: 8),
                    _HeaderStep(label: 'Name record', active: true),
                    SizedBox(width: 8),
                    _HeaderStep(label: 'Apply or save', active: false),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 250,
                      child: _PaneSurface(
                        title: 'Context',
                        subtitle:
                            'Left rail becomes a quiet index, not a second content wall.',
                        background: const Color(0xFFF8F4ED),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            _IndexTile(
                              title: 'Managed providers',
                              detail: 'Primary workflow',
                              active: true,
                            ),
                            SizedBox(height: 10),
                            _IndexTile(
                              title: 'Profiles',
                              detail: 'Separate downstream step',
                              active: false,
                            ),
                            SizedBox(height: 24),
                            _ListBlockHeader(
                              eyebrow: 'today',
                              title: 'Recently touched',
                            ),
                            SizedBox(height: 10),
                            _ThinRecordRow(
                              title: 'Test',
                              detail: 'VK Calls · saved 4 min ago',
                            ),
                            SizedBox(height: 10),
                            _ThinRecordRow(
                              title: 'Generic TURN',
                              detail: 'Selected family',
                            ),
                            Spacer(),
                            _QueueNote(
                              title: 'Intent',
                              detail:
                                  'This direction removes most chrome. It treats provider setup like writing a structured document.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF8),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  blurRadius: 28,
                                  offset: Offset(0, 16),
                                  color: Color(0x19000000),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                32,
                                28,
                                32,
                                28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  Text(
                                    'Create managed provider record',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.7,
                                      color: Color(0xFF20241F),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'The main screen shows only the next meaningful choices. Diagnostics and support information no longer compete with the editing flow.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF59605A),
                                    ),
                                  ),
                                  SizedBox(height: 22),
                                  _EditorialFamilyStrip(),
                                  SizedBox(height: 24),
                                  _LongField(
                                    label: 'Managed record name',
                                    value: 'Generic TURN',
                                  ),
                                  SizedBox(height: 18),
                                  _LongField(
                                    label: 'Reusable data for this family',
                                    value:
                                        'None yet. Keep the editor calm and explain the limitation plainly.',
                                    muted: true,
                                  ),
                                  SizedBox(height: 18),
                                  _LongField(
                                    label: 'What happens next',
                                    value:
                                        'Save the record for reuse or apply it to the current profile draft.',
                                    muted: true,
                                  ),
                                  Spacer(),
                                  _EditorialActionBar(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const <Widget>[
                          _PaneSurface(
                            title: 'Readiness',
                            subtitle:
                                'Status is reduced to one compact assurance block.',
                            background: Color(0xFFEEF4EA),
                            expandBody: false,
                            child: _CompactReadinessCard(),
                          ),
                          SizedBox(height: 16),
                          Expanded(
                            child: _PaneSurface(
                              title: 'On-demand support',
                              subtitle:
                                  'Hidden by default in production, pinned here only in the static reference.',
                              background: Color(0xFFF6F0E6),
                              child: _SupportDrawerPreview(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitCanvasReference extends StatelessWidget {
  const _SplitCanvasReference();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        color: const Color(0xFFE7EDF0),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10353C),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: const <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Productive split canvas',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF5F2E9),
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Selection and editing become two coordinated panes, while live runtime surfaces move into a low horizontal band.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Color(0xFFD1DCD8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TopStatusDot(label: 'Host ready'),
                    SizedBox(width: 10),
                    _TopStatusDot(label: '2 tunnel modes'),
                    SizedBox(width: 10),
                    _TopStatusDot(label: '1 live session'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 360,
                      child: _PaneSurface(
                        title: 'Selection lane',
                        subtitle:
                            'Everything that changes the current focus lives together.',
                        background: const Color(0xFFF6FBFC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            _SectionStripHeader(
                              title: 'Workflows',
                              action: 'Switch',
                            ),
                            SizedBox(height: 10),
                            _ListOption(
                              active: true,
                              title: 'Providers',
                              detail: 'Managed records and preset seeds',
                              badge: 'active',
                            ),
                            SizedBox(height: 10),
                            _ListOption(
                              active: false,
                              title: 'Profiles',
                              detail: 'Saved profiles and runtime defaults',
                              badge: '4',
                            ),
                            SizedBox(height: 18),
                            _SectionStripHeader(
                              title: 'Supported families',
                              action: 'View all',
                            ),
                            SizedBox(height: 10),
                            _FamilyBoardCard(
                              title: 'VK Calls',
                              detail:
                                  'Invite-first provider with browser continuation',
                              selected: false,
                            ),
                            SizedBox(height: 10),
                            _FamilyBoardCard(
                              title: 'Generic TURN',
                              detail:
                                  'Static TURN handoff for deterministic startup',
                              selected: true,
                            ),
                            SizedBox(height: 18),
                            _SectionStripHeader(
                              title: 'Presets',
                              action: 'Seed draft',
                            ),
                            SizedBox(height: 10),
                            _ThinRecordRow(
                              title: 'VK Calls preset',
                              detail: 'Use preset',
                            ),
                            SizedBox(height: 10),
                            _ThinRecordRow(
                              title: 'Generic TURN preset',
                              detail: 'Use preset',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const <Widget>[
                          Expanded(
                            child: _PaneSurface(
                              title: 'Detail canvas',
                              subtitle:
                                  'The selected entity gets one clean surface with tabs and action hierarchy.',
                              background: Color(0xFFFFFCF7),
                              child: _TabbedCanvas(),
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: _PaneSurface(
                              title: 'Runtime ribbon',
                              subtitle:
                                  'Activity moves into a low horizontal strip that can expand on demand.',
                              background: Color(0xFFF4EEE1),
                              child: _RuntimeRibbon(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  const _HeaderTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E7D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaneSurface extends StatelessWidget {
  const _PaneSurface({
    required this.title,
    required this.subtitle,
    required this.background,
    required this.child,
    this.expandBody = true,
  });

  final String title;
  final String subtitle;
  final Color background;
  final Widget child;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2521),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF5D6762),
            ),
          ),
          const SizedBox(height: 16),
          if (expandBody) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _RailBadge extends StatelessWidget {
  const _RailBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFFEEF4EA),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF173B43),
        ),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.active, required this.icon});

  final bool active;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF4E8D8) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: active ? const Color(0xFF173B43) : const Color(0xFFB8CCC6),
      ),
    );
  }
}

class _StatusCapsule extends StatelessWidget {
  const _StatusCapsule({
    required this.title,
    required this.detail,
    required this.accent,
    required this.surface,
  });

  final String title;
  final String detail;
  final Color accent;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF15221D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF4E5A54),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionColumn extends StatelessWidget {
  const _MiniActionColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: const <Widget>[
        _ActionChip(label: 'Diagnostics', filled: false),
        SizedBox(height: 8),
        _ActionChip(label: 'Refresh', filled: true),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF173B43) : const Color(0xFFF5E6D5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: filled ? const Color(0xFFF9F5EE) : const Color(0xFF173B43),
        ),
      ),
    );
  }
}

class _ListBlockHeader extends StatelessWidget {
  const _ListBlockHeader({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Color(0xFF6F7771),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2521),
          ),
        ),
      ],
    );
  }
}

class _ListOption extends StatelessWidget {
  const _ListOption({
    required this.active,
    required this.title,
    required this.detail,
    required this.badge,
  });

  final bool active;
  final String title;
  final String detail;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFE4ECE9)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: active
            ? Border.all(color: const Color(0xFF173B43).withValues(alpha: 0.18))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2522),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF5E6762),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E6D5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B5539),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeedTile extends StatelessWidget {
  const _SeedTile({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EEE3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF252520),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5F6760)),
          ),
        ],
      ),
    );
  }
}

class _QueueNote extends StatelessWidget {
  const _QueueNote({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECE4D7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF30271C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF5F584E),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetricShelf extends StatelessWidget {
  const _InlineMetricShelf({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (String item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EBDD),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D513E),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C2521),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Color(0xFF5D6762),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _FamilyChoiceRow extends StatelessWidget {
  const _FamilyChoiceRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(
          child: _FamilyChoiceCard(
            title: 'VK Calls',
            description: 'Invite-first provider with browser continuation',
            selected: false,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _FamilyChoiceCard(
            title: 'Generic TURN',
            description: 'Static TURN handoff for deterministic startup',
            selected: true,
          ),
        ),
      ],
    );
  }
}

class _FamilyChoiceCard extends StatelessWidget {
  const _FamilyChoiceCard({
    required this.title,
    required this.description,
    required this.selected,
  });

  final String title;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE0E8F1) : const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(20),
        border: selected
            ? Border.all(color: const Color(0xFF2D5870).withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2521),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selected ? 'selected' : 'available',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF5B655F),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF616A65),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: muted ? const Color(0xFFF0EBE2) : const Color(0xFFE7EEF2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: muted ? const Color(0xFF6E6962) : const Color(0xFF25302C),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final String primary;
  final String secondary;
  final String tertiary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF173B43),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            primary,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF9F6EF),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2E7D7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            secondary,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F4A40),
            ),
          ),
        ),
        Text(
          tertiary,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B6A55),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticStack extends StatelessWidget {
  const _DiagnosticStack();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        _MetricRow(label: 'Tunnel modes', value: '0 / 2 ready'),
        SizedBox(height: 10),
        _MetricRow(label: 'Negotiation', value: 'passed'),
        SizedBox(height: 10),
        _MetricRow(label: 'Pinned warning', value: 'No startup tested'),
        SizedBox(height: 16),
        _SmallLogLine(
          message: 'windows_wintun: fail-closed until explicit startup',
        ),
        SizedBox(height: 8),
        _SmallLogLine(message: 'linux_tun: fail-closed until explicit startup'),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5E6661)),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2925),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallLogLine extends StatelessWidget {
  const _SmallLogLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xFF525D57),
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const <Widget>[
        _ActivityRow(
          title: 'Resolution',
          detail: 'vk://invite parsed and waiting for browser continuation',
        ),
        SizedBox(height: 10),
        _ActivityRow(
          title: 'Session',
          detail: 'generic-turn profile idle after diagnostics export',
        ),
        SizedBox(height: 10),
        _ActivityRow(
          title: 'Diagnostics',
          detail: 'Bundle prepared under ~/.vk-turn-proxy-go/diagnostics',
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2824),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF5B655F),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStep extends StatelessWidget {
  const _HeaderStep({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF173B43) : const Color(0xFFF0E8DD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFFF9F6EF) : const Color(0xFF5A554D),
        ),
      ),
    );
  }
}

class _IndexTile extends StatelessWidget {
  const _IndexTile({
    required this.title,
    required this.detail,
    required this.active,
  });

  final String title;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7EEE9) : const Color(0xFFF1EDE6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF202521),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5C645F)),
          ),
        ],
      ),
    );
  }
}

class _ThinRecordRow extends StatelessWidget {
  const _ThinRecordRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202521),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: Color(0xFF626964)),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFF8D948E)),
      ],
    );
  }
}

class _EditorialFamilyStrip extends StatelessWidget {
  const _EditorialFamilyStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(
          child: _EditorialPill(
            title: 'VK Calls',
            description: 'Invite-first flow',
            selected: false,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _EditorialPill(
            title: 'Generic TURN',
            description: 'Static TURN handoff',
            selected: true,
          ),
        ),
      ],
    );
  }
}

class _EditorialPill extends StatelessWidget {
  const _EditorialPill({
    required this.title,
    required this.description,
    required this.selected,
  });

  final String title;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4ECF2) : const Color(0xFFF3EEE6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2622),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF626963)),
          ),
        ],
      ),
    );
  }
}

class _LongField extends StatelessWidget {
  const _LongField({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6A716B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: muted ? const Color(0xFFF1ECE4) : const Color(0xFFE8EFF2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: muted ? const Color(0xFF6B665D) : const Color(0xFF25302C),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorialActionBar extends StatelessWidget {
  const _EditorialActionBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF173B43),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Save managed record',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF9F6EF),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF1E6D8),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Apply to profile draft',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF544E44),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactReadinessCard extends StatelessWidget {
  const _CompactReadinessCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text(
          'Local host ready',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2722),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'GUI 0.1.0+1 · Host 0.1.0+1 · Contract 1',
          style: TextStyle(fontSize: 12, color: Color(0xFF5B645F)),
        ),
        SizedBox(height: 14),
        _MetricRow(label: 'Ownership', value: 'sidecar launched'),
        SizedBox(height: 10),
        _MetricRow(label: 'Tunnel summary', value: 'fail-closed'),
      ],
    );
  }
}

class _SupportDrawerPreview extends StatelessWidget {
  const _SupportDrawerPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        _SmallLogLine(message: 'Diagnostics drawer opens only on demand.'),
        SizedBox(height: 10),
        _SmallLogLine(
          message:
              'Event stream and tunnel detail should not be permanently competing with the main form.',
        ),
      ],
    );
  }
}

class _TopStatusDot extends StatelessWidget {
  const _TopStatusDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF4EFE5),
        ),
      ),
    );
  }
}

class _SectionStripHeader extends StatelessWidget {
  const _SectionStripHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF202622),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          action,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7E84),
          ),
        ),
      ],
    );
  }
}

class _FamilyBoardCard extends StatelessWidget {
  const _FamilyBoardCard({
    required this.title,
    required this.detail,
    required this.selected,
  });

  final String title;
  final String detail;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFDDE9EF)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2521),
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? const Color(0xFF2A5D74)
                    : const Color(0xFF8D999C),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF5E6863),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabbedCanvas extends StatelessWidget {
  const _TabbedCanvas();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Row(
          children: <Widget>[
            _HeaderStep(label: 'Record', active: true),
            SizedBox(width: 8),
            _HeaderStep(label: 'Availability', active: false),
            SizedBox(width: 8),
            _HeaderStep(label: 'Apply', active: false),
          ],
        ),
        SizedBox(height: 18),
        _LongField(label: 'Managed record name', value: 'Generic TURN'),
        SizedBox(height: 16),
        _LongField(
          label: 'Reusable fields',
          value:
              'No reusable shell-owned values are shipped for this family yet.',
          muted: true,
        ),
        SizedBox(height: 16),
        _LongField(
          label: 'Runtime note',
          value:
              'Host overlay reports current availability but does not own the operator-facing catalog.',
          muted: true,
        ),
        Spacer(),
        _EditorialActionBar(),
      ],
    );
  }
}

class _RuntimeRibbon extends StatelessWidget {
  const _RuntimeRibbon();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(
          child: _RibbonCard(
            title: 'Live resolution',
            detail: 'VK invite waiting for browser continuation',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _RibbonCard(
            title: 'Tunnel summary',
            detail: 'All platform modes fail closed until explicit startup',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _RibbonCard(
            title: 'Diagnostics export',
            detail: 'Last bundle written 09:14 to local diagnostics path',
          ),
        ),
      ],
    );
  }
}

class _RibbonCard extends StatelessWidget {
  const _RibbonCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF202622),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF5D6762),
            ),
          ),
        ],
      ),
    );
  }
}
