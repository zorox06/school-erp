import 'package:flutter/material.dart';

Future<T?> quickSheet<T>(
  BuildContext context,
  Widget Function(BuildContext, ScrollController) builder,
) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .5,
    minChildSize: .3,
    maxChildSize: .9,
    snap: true,
    snapSizes: const [.5, .9],
    builder: (context, scroll) =>
        SafeArea(top: false, child: builder(context, scroll)),
  ),
);
