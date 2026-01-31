import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/gmail/v1.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleIntegrationService {
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn(
    scopes: [
      GmailApi.gmailReadonlyScope,
      CalendarApi.calendarEventsReadonlyScope,
    ],
  );

  gsi.GoogleSignInAccount? _currentUser;
  http.Client? _authClient;

  // Getters
  gsi.GoogleSignInAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<String?> signIn() async {
    try {
      print("DEBUG: Starting Google Sign-In...");
      _currentUser = await _googleSignIn.signIn();
      print("DEBUG: SignIn complete. User: $_currentUser");
      
      if (_currentUser != null) {
        print("DEBUG: Retrieving authentication tokens...");
        final auth = await _currentUser!.authentication;
        // Cast to dynamic to bypass potential analyzer issues if accessToken is hidden
        final accessToken = (auth as dynamic).accessToken as String?;
        print("DEBUG: Access Token present: ${accessToken != null}");
        
        if (accessToken != null) {
           _authClient = _AuthenticatedClient({'Authorization': 'Bearer $accessToken'});
           return null; // Success
        } else {
           return "Failed to retrieve Access Token";
        }
      }
      return "Sign in aborted by user";
    } catch (e) {
      print("Google Sign-In Error: $e");
      return "Exception: $e";
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _authClient = null;
  }

  // Gmail: Fetch Recent Emails
  Future<List<String>> getRecentEmails({int count = 5}) async {
    if (_authClient == null) return ["Not authenticated. Please sign in."];

    try {
      final gmail = GmailApi(_authClient!);
      final response = await gmail.users.messages.list("me", maxResults: count);
      
      if (response.messages == null || response.messages!.isEmpty) {
        return ["No recent emails found."];
      }

      List<String> emailSummaries = [];

      for (var msg in response.messages!) {
        final details = await gmail.users.messages.get("me", msg.id!);
        final snippet = details.snippet ?? "No snippet";
        
        // Extract Subject
        String subject = "No Subject";
        final headers = details.payload?.headers;
        if (headers != null) {
          final subjectHeader = headers.firstWhere(
            (h) => h.name?.toLowerCase() == 'subject', 
            orElse: () => MessagePartHeader(name: 'Subject', value: 'No Subject')
          );
          subject = subjectHeader.value ?? "No Subject";
          
           final fromHeader = headers.firstWhere(
            (h) => h.name?.toLowerCase() == 'from', 
            orElse: () => MessagePartHeader(name: 'From', value: 'Unknown')
          );
          subject += " (from ${fromHeader.value})";
        }

        emailSummaries.add("📧 **$subject**: $snippet");
      }
      return emailSummaries;

    } catch (e) {
      return ["Error fetching emails: $e"];
    }
  }

  // Calendar: Fetch Upcoming Events
  Future<List<String>> getUpcomingEvents({int count = 5}) async {
    if (_authClient == null) return ["Not authenticated. Please sign in."];

    try {
      final calendar = CalendarApi(_authClient!);
      final now = DateTime.now().toUtc();
      final events = await calendar.events.list(
        "primary",
        timeMin: now,
        maxResults: count,
        singleEvents: true,
        orderBy: "startTime",
      );

      if (events.items == null || events.items!.isEmpty) {
        return ["No upcoming events found."];
      }

      List<String> eventSummaries = [];

      for (var event in events.items!) {
        final summary = event.summary ?? "No Title";
        final start = event.start?.dateTime ?? event.start?.date;
        final timeStr = start != null ? start.toLocal().toString() : "Unknown time";
        
        eventSummaries.add("📅 **$summary** at $timeStr");
      }
      return eventSummaries;

    } catch (e) {
      return ["Error fetching events: $e"];
    }
  }
}
