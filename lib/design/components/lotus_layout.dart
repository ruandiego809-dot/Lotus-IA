// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'lotus_card.dart';

/// App bar with an optional subtitle. Keeps every screen visually aligned.
class LotusAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LotusAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.bottom,
    this.showBrand = false,
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showBrand;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(
    64 + (subtitle == null ? 0 : 16) + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final titles = Column(
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleLarge,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall,
          ),
      ],
    );
    return PreferredSize(
      preferredSize: preferredSize,
      child: AppBar(
        leading: leading,
        centerTitle: centerTitle,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBrand) ...[
              const LotusBrandMark(size: 34),
              const SizedBox(width: LotusSpace.md),
            ],
            centerTitle ? titles : Flexible(child: titles),
          ],
        ),
        actions: actions == null
            ? null
            : [...actions!, const SizedBox(width: LotusSpace.sm)],
        bottom: bottom,
      ),
    );
  }
}

/// Scaffold wrapper adding a subtle brand glow behind the content.
class LotusScaffold extends StatelessWidget {
  const LotusScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.safeTop = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool safeTop;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: context.palette.glow),
            ),
          ),
        ),
        SafeArea(top: safeTop, bottom: false, child: body),
      ],
    );
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// Centers content and clamps its width on tablets.
class LotusContent extends StatelessWidget {
  const LotusContent({
    super.key,
    required this.child,
    this.maxWidth = LotusBreakpoints.contentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: LotusSpace.lg),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Scrollable page with consistent padding and bottom breathing room.
class LotusPage extends StatelessWidget {
  const LotusPage({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(
      LotusSpace.lg,
      LotusSpace.sm,
      LotusSpace.lg,
      LotusSpace.xxxl,
    ),
    this.maxWidth = LotusBreakpoints.contentMaxWidth,
    this.controller,
    this.onRefresh,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      controller: controller,
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Full-height rounded sheet with keyboard-aware padding.
Future<T?> showLotusSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: context.palette.elevated,
    constraints: const BoxConstraints(maxWidth: LotusBreakpoints.sheetMaxWidth),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: builder(ctx),
    ),
  );
}
