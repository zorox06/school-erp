import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'components.dart';

class SchoolSkeleton extends StatelessWidget {
  const SchoolSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading school workspace',
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Brand(),
          const SizedBox(height: 42),
          for (final width in [220.0, 160.0, double.infinity, double.infinity])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                width: width,
                height: width == double.infinity ? 90 : 24,
                decoration: BoxDecoration(
                  color: Palette.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
