import 'package:flutter/material.dart';

/// Full-screen, zoomable receipt viewer on a black background.
///
/// Shared by Add Expense and Expense Details so every receipt is viewed
/// the same way. The caller supplies the resolved [image] (network or
/// local file, web-safe as needed).
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({
    super.key,
    required this.image,
    this.title = 'Receipt',
  });

  final Widget image;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: image,
        ),
      ),
    );
  }
}
