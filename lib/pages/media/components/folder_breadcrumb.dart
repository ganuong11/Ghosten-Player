import 'package:flutter/material.dart';

class FolderBreadcrumb extends StatelessWidget {
  const FolderBreadcrumb({
    super.key,
    required this.paths,
    required this.onPathTap,
  });

  final List<({String id, String name})> paths;
  final void Function(String id) onPathTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right, size: 20),
        ),
        itemBuilder: (context, index) {
          final path = paths[index];
          final isLast = index == paths.length - 1;

          return GestureDetector(
            onTap: isLast ? null : () => onPathTap(path.id),
            child: Center(
              child: Text(
                path.name,
                style: TextStyle(
                  color: isLast ? null : Theme.of(context).colorScheme.primary,
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
