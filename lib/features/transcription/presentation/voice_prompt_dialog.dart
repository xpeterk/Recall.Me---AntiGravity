import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';

class VoicePromptDialog extends StatefulWidget {
  const VoicePromptDialog({Key? key}) : super(key: key);

  @override
  State<VoicePromptDialog> createState() => _VoicePromptDialogState();
}

class _VoicePromptDialogState extends State<VoicePromptDialog> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _text = "";
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speechToText.initialize(
      onError: (error) {
        print('VoicePromptDialog Error: $error');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (mounted) {
           setState(() => _isListening = status == 'listening');
        }
      },
    );
    if (available && mounted) {
      _startListening();
    }
  }

  void _startListening() async {
    if (!_isListening) {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _text = result.recognizedWords;
              _textController.text = _text;
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4), // Stop automatically upon silence
        partialResults: true,
        cancelOnError: true,
      );
      if (mounted) {
        setState(() => _isListening = true);
      }
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Speak your prompt", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(_isListening ? 20 : 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: _isListening 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).dividerColor,
                  width: 2,
                ),
                boxShadow: _isListening ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 5,
                  )
                ] : [],
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Theme.of(context).colorScheme.primary : Colors.grey,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: _isListening ? "Listening..." : "Tap mic to speak or type here...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
             onChanged: (val) {
                 _text = val;
             },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () {
             final promptText = _textController.text.trim();
             if (promptText.isNotEmpty) {
                 Navigator.pop(context, promptText);
             }
          },
          child: const Text("Ask AI"),
        ),
      ],
    );
  }
}
