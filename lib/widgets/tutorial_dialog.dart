import 'package:flutter/material.dart';

class TutorialDialog extends StatelessWidget {
  final VoidCallback onDone;

  const TutorialDialog({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How to Play Scriblet'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('🎨 Draw and Guess!'),
            SizedBox(height: 12),
            Text('1. One player draws a word, others try to guess it.'),
            Text('2. Use the chat to enter guesses.'),
            Text('3. Use the tools to draw, erase, undo, redo, or clear the canvas.'),
            Text('4. Points are awarded for correct guesses and good drawings!'),
            SizedBox(height: 16),
            Text('Good luck and have fun!'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDone,
          child: const Text('Got it!'),
        ),
        TextButton(
          onPressed: onDone,
          child: const Text('Skip'),
        ),
      ],
    );
  }
}