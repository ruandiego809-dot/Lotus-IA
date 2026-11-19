// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'lotus_card.dart';

class LotusDestination {
  const LotusDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Floating pill navigation used on phones.
class LotusBottomNav extends StatelessWidget {
  const LotusBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onSelected,
  });

  final int index;
  final List<LotusDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        LotusSpace.lg,
        0,
        LotusSpace.lg,
        LotusSpace.md,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(LotusSpace.xs + 1),
            decoration: BoxDecoration(
              color: palette.elevated,
              borderRadius: BorderRadius.circular(LotusRadius.xl),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.35 : 0.06,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == index,
                      onTap: () {
                        if (i == index) return;
                        HapticFeedback.selectionClick();
                        onSelected(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final LotusDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final palette = context.palette;
    final color = selected ? scheme.primary : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LotusRadius.md),
        child: AnimatedContainer(
          duration: LotusMotion.base,
          curve: LotusMotion.curve,
          padding: const EdgeInsets.symmetric(vertical: LotusSpace.sm),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(LotusRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: LotusMotion.fast,
                switchInCurve: LotusMotion.curve,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical rail used on tablets and wide windows.
class LotusNavRail extends StatelessWidget {
  const LotusNavRail({
    super.key,
    required this.index,
    required this.destinations,
    required this.onSelected,
  });

  final int index;
  final List<LotusDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.scheme;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: LotusSpace.xl),
      decoration: BoxDecoration(
        color: palette.elevated,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          const LotusBrandMark(size: 42),
          const SizedBox(height: LotusSpace.xxl),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LotusSpace.md,
                vertical: LotusSpace.xs,
              ),
              child: Semantics(
                button: true,
                selected: i == index,
                label: destinations[i].label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () {
                    if (i == index) return;
                    HapticFeedback.selectionClick();
                    onSelected(i);
                  },
                  borderRadius: BorderRadius.circular(LotusRadius.md),
                  child: AnimatedContainer(
                    duration: LotusMotion.base,
                    curve: LotusMotion.curve,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: LotusSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: i == index
                          ? scheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(LotusRadius.md),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          i == index
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          size: 22,
                          color: i == index ? scheme.primary : palette.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destinations[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            fontSize: 10,
                            color: i == index ? scheme.primary : palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
