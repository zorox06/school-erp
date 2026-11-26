import 'quick_sheet.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/theme.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

TextStyle textStyle(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color? color,
  double height = 1.45,
}) => TextStyle(
  fontFamily: 'Manrope',
  fontFeatures: const [FontFeature.tabularFigures()],
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

bool limitSchoolEffects(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<AppScope>()
        ?.notifier
        ?.limitEffects ??
    false;

Duration schoolMotion(BuildContext context, int full, int light) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return Duration(milliseconds: limitSchoolEffects(context) ? light : full);
}

Future<T?> openPage<T>(BuildContext context, Widget page) {
  final limited = limitSchoolEffects(context);
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: schoolMotion(context, 310, 135),
      reverseTransitionDuration: schoolMotion(context, 205, 110),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final eased = CurveTween(curve: Curves.easeOutCubic).animate(animation);
        final slide = SlideTransition(
          position: Tween(
            begin: Offset(limited ? .018 : .055, 0),
            end: Offset.zero,
          ).animate(eased),
          child: child,
        );
        return limited
            ? slide
            : FadeTransition(
                opacity: Tween(begin: .63, end: 1.0).animate(eased),
                child: slide,
              );
      },
    ),
  );
}

class EntranceMotion extends StatelessWidget {
  const EntranceMotion({super.key, required this.child, this.follow = false});

  final Widget child;
  final bool follow;

  @override
  Widget build(BuildContext context) {
    final duration = schoolMotion(context, follow ? 460 : 350, 130);
    if (duration == Duration.zero) return child;
    final limited = limitSchoolEffects(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: follow && !limited
          ? const Interval(.15, 1, curve: Curves.easeOutCubic)
          : Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, (1 - progress) * (limited ? 5 : 13)),
        child: limited
            ? child
            : Opacity(opacity: .7 + .3 * progress, child: child),
      ),
    );
  }
}

void tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class Brand extends StatelessWidget {
  final bool large;
  const Brand({super.key, this.large = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: large ? 44 : 35,
        height: large ? 44 : 35,
        decoration: BoxDecoration(
          color: context.tones.teal,
          borderRadius: BorderRadius.circular(large ? 14 : 12),
        ),
        child: Icon(
          LucideIcons.sprout,
          color: Colors.white,
          size: large ? 27 : 22,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'schoolday',
        style: textStyle(large ? 27 : 21, weight: FontWeight.w800, height: 1.1),
      ),
    ],
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Palette.paper,
    this.onTap,
    this.radius = 22,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: context.tones.resolve(color),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: color == Palette.paper
            ? context.tones.line.withValues(alpha: .8)
            : Colors.transparent,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color, background;
  final double size;
  const IconBadge(
    this.icon, {
    super.key,
    this.color = Palette.teal,
    this.background = Palette.mint,
    this.size = 46,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.tones.resolve(background),
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(icon, color: context.tones.resolve(color), size: size * .47),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color, background;
  final IconData? icon;
  const Tag(
    this.text, {
    super.key,
    this.color = Palette.teal,
    this.background = Palette.mint,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.tones.resolve(background),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: context.tones.resolve(color)),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            style: textStyle(
              10,
              weight: FontWeight.w800,
              color: context.tones.resolve(color),
            ),
          ),
        ),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (icon != null || busy) ...[
            const SizedBox(width: 10),
            SizedBox.square(
              dimension: 18,
              child: AnimatedSwitcher(
                duration: schoolMotion(context, 170, 85),
                child: busy
                    ? CircularProgressIndicator(
                        key: ValueKey('busy'),
                        strokeWidth: 2,
                        color: context.tones.paper,
                      )
                    : Icon(icon, size: 17),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const SectionHeading(this.title, {super.key, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: textStyle(17, weight: FontWeight.w800)),
      ),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ],
  );
}

class ScreenHeading extends StatelessWidget {
  final String title, eyebrow;
  final String? subtitle;
  final Widget? trailing;
  const ScreenHeading(
    this.title, {
    super.key,
    required this.eyebrow,
    this.subtitle,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: textStyle(
            12,
            color: context.tones.teal,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: textStyle(28, weight: FontWeight.w800, height: 1.2),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          Text(subtitle!, style: textStyle(13, color: context.tones.muted)),
        ],
      ],
    ),
  );
}

class ContentList extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  const ContentList({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(22, 8, 22, 28),
  });
  @override
  Widget build(BuildContext context) {
    final list = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList.builder(
            itemCount: children.length,
            itemBuilder: (context, i) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SizedBox(width: double.infinity, child: children[i]),
              ),
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class AppPage extends StatelessWidget {
  final String title, eyebrow;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget>? actions;
  const AppPage({
    super.key,
    required this.title,
    this.eyebrow = '',
    required this.children,
    this.bottom,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ModalRoute.of(context)?.isFirst == true
        ? null
        : AppBar(
            leading: IconButton(
              tooltip: 'Go back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
            ),
            title: Text(
              eyebrow.isEmpty ? title : eyebrow,
              style: textStyle(13, weight: FontWeight.w700),
            ),
            actions: [
              if (AppScope.of(context).workspace == Workspace.parent &&
                  AppScope.of(context).snapshot.children.isNotEmpty)
                const ChildAvatar(),
              ...?actions,
            ],
          ),
    body: SafeArea(
      top: false,
      child: ContentList(
        children: [
          if (eyebrow.isNotEmpty) ScreenHeading(title, eyebrow: eyebrow),
          ...children,
        ],
      ),
    ),
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: bottom!,
                ),
              ),
            ),
          ),
  );
}

class EmptyIllustration extends StatelessWidget {
  final IconData icon;
  final Color color, background;
  const EmptyIllustration(
    this.icon, {
    super.key,
    this.color = Palette.teal,
    this.background = Palette.mint,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    height: 105,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.tones.resolve(background),
              width: 1.2,
            ),
          ),
        ),
        Transform.rotate(
          angle: -.11,
          child: Container(
            width: 75,
            height: 78,
            decoration: BoxDecoration(
              color: context.tones.resolve(background),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Transform.rotate(
              angle: .11,
              child: Icon(icon, color: context.tones.resolve(color), size: 34),
            ),
          ),
        ),
        Positioned(
          right: 3,
          top: 16,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: context.tones.resolve(color).withValues(alpha: .3),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: 5,
          bottom: 15,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: context.tones.resolve(color).withValues(alpha: .22),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 7,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: context.tones.paper,
              shape: BoxShape.circle,
              border: Border.all(color: context.tones.line),
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: 13,
              color: context.tones.resolve(color),
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;
  final Color color, background;
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
    this.compact = false,
    this.color = Palette.teal,
    this.background = Palette.mint,
  });
  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 22 : 32),
    child: Column(
      children: [
        if (compact)
          IconBadge(
            icon,
            color: context.tones.resolve(color),
            background: background,
            size: 44,
          )
        else
          EmptyIllustration(
            icon,
            color: context.tones.resolve(color),
            background: background,
          ),
        SizedBox(height: compact ? 14 : 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textStyle(compact ? 15 : 19, weight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: textStyle(13, color: context.tones.muted, height: 1.65),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 17),
          OutlinedButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}

class FilterTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const FilterTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(
        labels.length,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            selected: i == selected,
            button: true,
            child: Material(
              color: selected == i ? context.tones.teal : context.tones.paper,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 13,
                  ),
                  child: Text(
                    labels[i],
                    style: textStyle(
                      12,
                      weight: FontWeight.w700,
                      color: selected == i ? Colors.white : context.tones.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FormLabel extends StatelessWidget {
  final String label;
  final Widget child;
  const FormLabel(this.label, {super.key, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textStyle(12, weight: FontWeight.w700)),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color color;
  const SettingRow(
    this.icon,
    this.title, {
    super.key,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color = Palette.teal,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 3),
      child: Row(
        children: [
          IconBadge(icon, color: context.tones.resolve(color), size: 41),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textStyle(14, weight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: textStyle(11, color: context.tones.muted),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              Icon(
                LucideIcons.chevronRight,
                size: 17,
                color: context.tones.muted,
              ),
        ],
      ),
    ),
  );
}

class RecordTile extends StatelessWidget {
  final SchoolRecord record;
  final IconData icon;
  final VoidCallback onTap;
  const RecordTile(
    this.record, {
    super.key,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Surface(
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.category != null) ...[
                  Text(
                    record.category!.toUpperCase(),
                    style: textStyle(
                      9,
                      color: context.tones.teal,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  record.title ?? 'Untitled',
                  style: textStyle(14, weight: FontWeight.w800),
                ),
                if (record.description != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    record.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(12, color: context.tones.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, size: 17, color: context.tones.muted),
        ],
      ),
    ),
  );
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color, background;
  const InfoBanner(
    this.text, {
    super.key,
    this.icon = LucideIcons.info,
    this.color = Palette.teal,
    this.background = Palette.mint,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: context.tones.resolve(background),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: context.tones.resolve(color)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: textStyle(
              12,
              color: context.tones.resolve(color),
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final selected = c.snapshot.children
        .where((r) => r.id == c.selectedChildId)
        .firstOrNull;
    final name = selected?.title;
    return IconButton(
      tooltip: 'Switch child${name == null ? '' : ': $name'}',
      onPressed: () => quickSheet<void>(
        context,
        (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Your children',
              style: textStyle(24, weight: FontWeight.w800),
            ),
            ...c.snapshot.children.map(
              (r) => ListTile(
                selected: r.id == c.selectedChildId,
                leading: const Icon(Icons.person_outline),
                title: Text(r.title ?? 'Linked child'),
                subtitle: r.description == null ? null : Text(r.description!),
                trailing: r.id == c.selectedChildId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  c.chooseChild(r.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
      icon: CircleAvatar(
        radius: 17,
        backgroundColor: context.tones.mint,
        child: name == null || name.isEmpty
            ? const Icon(Icons.person_outline, size: 18)
            : Text(
                name.characters.first.toUpperCase(),
                style: textStyle(13, weight: FontWeight.w800),
              ),
      ),
    );
  }
}

enum RecordSyncState { synced, queued, conflict, offline, syncing }

class SyncPill extends StatelessWidget {
  final RecordSyncState state;
  final String label;
  const SyncPill(this.state, this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tones;
    final (icon, ink, fill) = switch (state) {
      RecordSyncState.conflict => (
        Icons.report_outlined,
        t.danger,
        t.coralWash,
      ),
      RecordSyncState.queued => (Icons.schedule, t.amber, t.amberWash),
      RecordSyncState.offline => (
        Icons.cloud_off_outlined,
        t.amber,
        t.amberWash,
      ),
      RecordSyncState.syncing => (Icons.sync, t.teal, t.mint),
      RecordSyncState.synced => (Icons.cloud_done_outlined, t.teal, t.mint),
    };
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ink, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: textStyle(11, color: ink, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
