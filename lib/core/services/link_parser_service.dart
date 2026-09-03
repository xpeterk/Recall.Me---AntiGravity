import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class LinkParserService {
  // Regex to detect basic URLs in text
  static final RegExp urlRegExp = RegExp(
    r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
    caseSensitive: false,
  );

  /// Checks if string contains at least one valid URL
  bool containsUrl(String text) {
    return urlRegExp.hasMatch(text);
  }

  /// Extracts the first URL found in the text
  String? extractFirstUrl(String text) {
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  /// Master method to fetch context based on URL type
  Future<String?> fetchContextFromUrl(String url) async {
    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        return await _fetchYouTubeTranscript(url);
      } else {
        return await _fetchWebPageText(url);
      }
    } catch (e) {
      log('Error parsing URL $url: $e');
      return null;
    }
  }

  Future<String?> _fetchYouTubeTranscript(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.closedCaptions.getManifest(video.id);
      
      if (manifest.tracks.isEmpty) {
        // Fallback: If no transcript, just use description and title.
        return "Title: ${video.title}\nDescription: ${video.description}";
      }

      final trackInfo = manifest.getByLanguage('en').isNotEmpty 
          ? manifest.getByLanguage('en').first 
          : manifest.tracks.first;
          
      final track = await yt.videos.closedCaptions.get(trackInfo);
      
      final StringBuffer transcriptBuffer = StringBuffer();
      transcriptBuffer.writeln("Title: ${video.title}");
      transcriptBuffer.writeln("Transcript:");
      
      for (final caption in track.captions) {
        transcriptBuffer.writeln(caption.text);
      }
      return transcriptBuffer.toString();
    } catch (e) {
      log('YouTube extraction error: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  Future<String?> _fetchWebPageText(String url) async {
    try {
      // Ensure it has a scheme
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        
        // Remove script, style tags to clean up parsed output
        document.querySelectorAll('script, style, noscript, nav, footer, header').forEach((element) => element.remove());
        
        // Return inner text, stripped of excess whitespace
        final text = document.body?.text ?? '';
        return text.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
      return null;
    } catch (e) {
      log('Web fetch error: $e');
      return null;
    }
  }
}
