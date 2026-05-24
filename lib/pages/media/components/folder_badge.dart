import 'package:flutter/material.dart';

class FolderBadge extends StatelessWidget {
  const FolderBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.folder,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
