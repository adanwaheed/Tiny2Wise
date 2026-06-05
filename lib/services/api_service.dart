import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static String absoluteUrl(String path) {
    final p = path.trim();
    if (p.isEmpty) return p;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (!p.startsWith('/')) return '$baseUrl/$p';
    return '$baseUrl$p';
  }

  static Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'raw': decoded};
    } catch (_) {
      return {'message': body};
    }
  }

  static Future<void> saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', token);
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  static Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw 'Token missing. Please login again.';
    }
    return {'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    return _authHeaders();
  }

  static Future<Map<String, String>> getAuthImageHeaders() async {
    return _authHeaders();
  }

  // -------------------- AUTH --------------------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http
        .post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Login failed').toString();
    }

    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }
    return data;
  }

  static Future<Map<String, dynamic>> signup({
    required String role,
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http
        .post(
      Uri.parse('$baseUrl/api/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role,
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Signup failed').toString();
    }

    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }
    return data;
  }

  // -------------------- ME (PROFILE) --------------------

  static const String _profilePhotoCacheKey = 'cached_profile_photo_bytes';

  static Future<void> saveCachedProfilePhotoBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_profilePhotoCacheKey, base64Encode(bytes));
  }

  static Future<Uint8List?> getCachedProfilePhotoBytes() async {
    final sp = await SharedPreferences.getInstance();
    final encoded = sp.getString(_profilePhotoCacheKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } catch (_) {
      await sp.remove(_profilePhotoCacheKey);
      return null;
    }
  }

  static Future<void> clearCachedProfilePhotoBytes() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_profilePhotoCacheKey);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/me'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load profile').toString();
    }
    return data;
  }

  static Future<Uint8List?> getMyProfilePhotoBytes({int? cacheBust}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw 'Token missing. Please login again.';
    }

    final uri = cacheBust == null
        ? Uri.parse('$baseUrl/api/me/photo')
        : Uri.parse('$baseUrl/api/me/photo?b=$cacheBust');

    final res = await http
        .get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'image/*',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode == 404) return null;

    if (res.statusCode != 200) {
      final data = _safeJson(res.body);
      throw (data['message'] ?? 'Failed to load profile photo').toString();
    }

    return res.bodyBytes;
  }

  static Future<Map<String, dynamic>> uploadMyProfilePhoto({
    required File photoFile,
  }) async {
    final token = await getToken();
    if (token == null) throw 'Token missing. Please login again.';

    final uri = Uri.parse('$baseUrl/api/me/photo');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('photo', photoFile.path));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data['message'] ?? 'Failed to upload photo').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/me/password'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to change password').toString();
    }
    return data;
  }

  // -------------------- TODDLERS (PARENT) --------------------

  static Future<List<dynamic>> getToddlers() async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load toddlers').toString();
    }

    return (data['toddlers'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createToddler({
    required String name,
    required String schoolName,
    required String className,
    required int age,
    File? photoFile,
  }) async {
    final token = await getToken();
    if (token == null) throw 'Token missing. Please login again.';

    final uri = Uri.parse('$baseUrl/api/toddlers');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';

    req.fields['name'] = name.trim();
    req.fields['schoolName'] = schoolName.trim();
    req.fields['className'] = className.trim();
    req.fields['age'] = age.toString();

    if (photoFile != null) {
      req.files.add(await http.MultipartFile.fromPath('photo', photoFile.path));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data['message'] ?? 'Failed to create toddler').toString();
    }
    return data;
  }

  static Future<void> setActiveToddler(String toddlerId) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/toddlers/$toddlerId/active'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to set active toddler').toString();
    }
  }

  static Future<Map<String, dynamic>> getToddlerProgress(
      String toddlerId,
      ) async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers/$toddlerId/progress'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load progress').toString();
    }

    return data;
  }


  // -------------------- TODDLER ACTIVITY PROGRESS --------------------

  static Future<Map<String, dynamic>> getToddlerActivityProgress({
    required String toddlerId,
  }) async {
    final headers = await _authHeaders();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers/${toddlerId.trim()}/activity-progress?t=$cacheBuster'),
      headers: {
        ...headers,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load toddler activity progress').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> getActiveToddlerActivityProgress() async {
    final headers = await _authHeaders();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers/active/activity-progress?t=$cacheBuster'),
      headers: {
        ...headers,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load active toddler activity progress').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> recordToddlerActivityProgress({
    required String toddlerId,
    required String activityType,
    String title = '',
    int score = 0,
    int total = 0,
    int correct = 0,
    int completed = 0,
    String sourceId = '',
    String note = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/toddlers/${toddlerId.trim()}/activity-progress'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'activityType': activityType.trim(),
        'title': title.trim(),
        'score': score,
        'percentage': score,
        'total': total,
        'correct': correct,
        'completed': completed,
        'sourceId': sourceId.trim(),
        'note': note.trim(),
        'metadata': metadata,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to save toddler activity progress').toString();
    }
    return data;
  }


  static Future<Map<String, dynamic>?> getActiveToddler() async {
    final toddlers = await getToddlers();
    if (toddlers.isEmpty) return null;

    final maps = toddlers
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (maps.isEmpty) return null;

    return maps.firstWhere(
          (t) => t['isActive'] == true,
      orElse: () => maps.first,
    );
  }

  // -------------------- TODDLER BADGES --------------------

  static Future<Map<String, dynamic>> getToddlerBadges({
    required String toddlerId,
  }) async {
    final headers = await _authHeaders();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers/${toddlerId.trim()}/badges?t=$cacheBuster'),
      headers: {
        ...headers,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load toddler badges').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> awardToddlerBadge({
    required String toddlerId,
    required String badgeKey,
    required String source,
    int score = 0,
    int total = 0,
    int correct = 0,
    String goalText = '',
    Map<String, dynamic> details = const {},
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/toddlers/${toddlerId.trim()}/badges/award'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'badgeKey': badgeKey.trim(),
        'source': source.trim(),
        'sourceActivity': source.trim(),
        'activityType': source.trim(),
        'score': score,
        'percentage': score,
        'total': total,
        'correct': correct,
        'completed': correct > 0 ? correct : total,
        'goalText': goalText.trim(),
        'details': details,
        'metadata': details,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to award badge').toString();
    }

    final newBadges = data['newBadges'];
    if (newBadges is List && newBadges.isNotEmpty) {
      data['newlyUnlocked'] = true;
      data['badge'] = newBadges.first;
    } else {
      data['newlyUnlocked'] = false;
    }

    return data;
  }

  // -------------------- TODDLER 3D AVATAR / GEMINI CHAT --------------------

  /// New compatible method used by ToddlerAvatarScreen.
  ///
  /// It returns the full backend response Map, so screens can read:
  /// reply, inputLanguage, ttsLanguage, avatarAction, avatarEmotion, source, etc.
  static Future<Map<String, dynamic>> sendToddlerAvatarTurn({
    required String message,
    String languageMode = 'auto',
    String? toddlerId,
  }) async {
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      throw 'Message is empty';
    }

    final token = await getToken();

    final response = await http
        .post(
      Uri.parse('$baseUrl/api/toddler/avatar-chat'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'message': cleanMessage,
        'languageMode': languageMode,
        if (toddlerId != null && toddlerId.trim().isNotEmpty)
          'toddlerId': toddlerId.trim(),
      }),
    )
        .timeout(const Duration(seconds: 120));

    final data = _safeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = data['message']?.toString() ?? 'Avatar reply failed';
      final err = data['error']?.toString();

      if (err != null && err.isNotEmpty) {
        throw '$msg: $err';
      }

      throw msg;
    }

    final reply = data['reply']?.toString().trim() ?? '';

    if (reply.isEmpty) {
      throw 'Gemini returned empty reply';
    }

    return {
      ...data,
      'reply': reply,
      'inputLanguage': data['inputLanguage']?.toString() ?? languageMode,
      'ttsLanguage': data['ttsLanguage']?.toString() ??
          (RegExp(r'[\u0600-\u06FF]').hasMatch(reply) ? 'ur-PK' : 'en-US'),
      'avatarAction': data['avatarAction']?.toString() ?? 'talk',
      'avatarEmotion': data['avatarEmotion']?.toString() ?? 'friendly',
    };
  }

  /// Old compatible method used by older screens.
  ///
  /// Keep this method so existing ToddlerAvatarScreen files that expect only
  /// a String reply still compile correctly.
  static Future<String> sendToddlerAvatarMessage({
    required String message,
    String languageMode = 'auto',
    String? toddlerId,
  }) async {
    final data = await sendToddlerAvatarTurn(
      message: message,
      languageMode: languageMode,
      toddlerId: toddlerId,
    );

    return data['reply']?.toString().trim() ?? '';
  }



  // -------------------- TODDLER AI SPEECH GAMES --------------------

  /// Generates toddler speech-practice games.
  ///
  /// The backend uses Gemini when GEMINI_API_KEY is available and automatically
  /// falls back to safe local toddler-friendly games when the AI service is not
  /// configured or is temporarily unavailable.
  static Future<Map<String, dynamic>> generateToddlerSpeechGames({
    int countPerGame = 5,
    String languageMode = 'mixed',
  }) async {
    final token = await getToken();

    final response = await http
        .post(
      Uri.parse('$baseUrl/api/toddler/speech-games/generate'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'countPerGame': countPerGame,
        'languageMode': languageMode,
      }),
    )
        .timeout(const Duration(seconds: 70));

    final data = _safeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw (data['message'] ?? 'Failed to generate toddler games').toString();
    }
    return data;
  }



  // -------------------- TODDLER AI PUZZLES --------------------

  /// Generates toddler puzzle games for drag-and-match speech practice.
  ///
  /// The backend uses Gemini when GEMINI_API_KEY is configured and safely
  /// falls back to local toddler-friendly puzzles when AI is unavailable.
  static Future<Map<String, dynamic>> generateToddlerPuzzles({
    int countPerGame = 6,
    String languageMode = 'mixed',
  }) async {
    final token = await getToken();

    final response = await http
        .post(
      Uri.parse('$baseUrl/api/toddler/puzzles/generate'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'countPerGame': countPerGame,
        'languageMode': languageMode,
      }),
    )
        .timeout(const Duration(seconds: 70));

    final data = _safeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw (data['message'] ?? 'Failed to generate toddler puzzles').toString();
    }
    return data;
  }

  // -------------------- STORY STUDIO --------------------

  static String storyAudioUrl(String storyId) {
    return absoluteUrl('/api/stories/$storyId/audio');
  }

  static Future<List<dynamic>> getStories() async {
    final headers = await _authHeaders();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/stories?t=$cacheBuster'),
      headers: {
        ...headers,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load stories').toString();
    }

    return (data['stories'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> getToddlerAssignedStories(String toddlerId) async {
    final headers = await _authHeaders();
    final safeToddlerId = toddlerId.trim();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers/$safeToddlerId/stories?t=$cacheBuster'),
      headers: {
        ...headers,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load toddler stories').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> createStory({
    required String title,
    required int durationSec,
    required File audioFile,
    String language = 'Urdu',
    bool isDraft = false,
    String? toddlerId,
  }) async {
    final token = await getToken();
    if (token == null) throw 'Token missing. Please login again.';

    final uri = Uri.parse('$baseUrl/api/stories');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';

    req.fields['title'] = title.trim();
    req.fields['language'] = language;
    req.fields['durationSec'] = durationSec.toString();
    req.fields['isDraft'] = isDraft.toString();

    if (toddlerId != null && toddlerId.trim().isNotEmpty) {
      req.fields['toddlerId'] = toddlerId.trim();
    }

    req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data['message'] ?? 'Failed to save story').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateStory({
    required String storyId,
    required String title,
    required int durationSec,
    String language = 'Urdu',
    bool isDraft = false,
    File? audioFile,
  }) async {
    final token = await getToken();
    if (token == null) throw 'Token missing. Please login again.';

    final uri = Uri.parse('$baseUrl/api/stories/$storyId');
    final req = http.MultipartRequest('PUT', uri);
    req.headers['Authorization'] = 'Bearer $token';

    req.fields['title'] = title.trim();
    req.fields['language'] = language;
    req.fields['durationSec'] = durationSec.toString();
    req.fields['isDraft'] = isDraft.toString();

    if (audioFile != null) {
      req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data['message'] ?? 'Failed to update story').toString();
    }
    return data;
  }

  static Future<void> deleteStory(String storyId) async {
    final headers = await _authHeaders();

    final res = await http
        .delete(
      Uri.parse('$baseUrl/api/stories/$storyId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to delete story').toString();
    }
  }

  static Future<Map<String, dynamic>> assignStory({
    required String storyId,
    required bool assignToAll,
    List<String> toddlerIds = const [],
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/stories/$storyId/assign'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'assignToAll': assignToAll,
        'toddlerIds': toddlerIds,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to assign story').toString();
    }
    return data;
  }

  // -------------------- TEACHER DASHBOARD --------------------

  static Future<Map<String, dynamic>> getTeacherDashboard() async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/teacher/dashboard'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load teacher dashboard').toString();
    }

    return data;
  }

  // -------------------- TEACHER CLASSES --------------------

  static Future<List<dynamic>> getTeacherClasses() async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/teacher/classes'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load classes').toString();
    }

    return (data['classes'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createTeacherClass({
    required String title,
    String subtitle = '',
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/teacher/classes'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'subtitle': subtitle,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to create class').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> updateTeacherClass({
    required String classId,
    required String title,
    String subtitle = '',
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/teacher/classes/$classId'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'subtitle': subtitle,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to update class').toString();
    }

    return data;
  }

  static Future<void> deleteTeacherClass({
    required String classId,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .delete(
      Uri.parse('$baseUrl/api/teacher/classes/$classId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to delete class').toString();
    }
  }

  // -------------------- TEACHER EVENTS --------------------

  static Future<List<dynamic>> getTeacherEvents({
    int days = 7,
    bool all = false,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse('$baseUrl/api/teacher/events').replace(
      queryParameters: {
        if (all) 'all': '1',
        if (!all) 'days': days.toString(),
      },
    );

    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load events').toString();
    }

    return (data['events'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createTeacherEvent({
    required String title,
    required DateTime startAt,
    String note = '',
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/teacher/events'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'startAt': startAt.toIso8601String(),
        'note': note,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to create event').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> updateTeacherEvent({
    required String eventId,
    required String title,
    required DateTime startAt,
    String note = '',
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/teacher/events/$eventId'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'startAt': startAt.toIso8601String(),
        'note': note,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to update event').toString();
    }

    return data;
  }

  static Future<void> deleteTeacherEvent({
    required String eventId,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .delete(
      Uri.parse('$baseUrl/api/teacher/events/$eventId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to delete event').toString();
    }
  }

  // -------------------- TEACHER TODDLERS --------------------

  static Future<List<dynamic>> getAllToddlersForTeacher() async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/teacher/toddlers'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load toddlers').toString();
    }

    return (data['toddlers'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> assignToddlerToClass({
    required String toddlerId,
    required String? classId,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/teacher/toddlers/$toddlerId/assign-class'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'classId': classId}),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to assign class').toString();
    }

    return data;
  }

  // -------------------- TEACHER ACTIVITIES --------------------

  static Future<Map<String, dynamic>> getTeacherActivityTargets() async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/teacher/activity-targets'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load activity targets').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> assignTeacherActivity({
    required String activityType,
    required String targetType,
    String? classId,
    List<String> toddlerIds = const [],
    String title = '',
    String description = '',
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/teacher/activities/assign'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'activityType': activityType,
        'targetType': targetType,
        'classId': classId,
        'toddlerIds': toddlerIds,
        'title': title,
        'description': description,
      }),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to assign activity').toString();
    }

    return data;
  }

  static Future<List<dynamic>> getTeacherAssignedActivities({
    int limit = 20,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse('$baseUrl/api/teacher/activities').replace(
      queryParameters: {'limit': limit.toString()},
    );

    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
    final data = _safeJson(res.body);

    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load teacher assignments')
          .toString();
    }

    return (data['assignments'] as List<dynamic>? ?? []);
  }

  static Future<List<dynamic>> getToddlerAssignedActivities(
      String toddlerId,
      ) async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/toddlers/$toddlerId/assigned-activities'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load assigned activities')
          .toString();
    }

    return (data['assignments'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> completeAssignedActivity(
      String assignmentId,
      ) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse(
        '$baseUrl/api/parent/assigned-activities/$assignmentId/complete',
      ),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to complete activity').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> deleteAssignedActivity(
      String assignmentId,
      ) async {
    final headers = await _authHeaders();

    final res = await http
        .delete(
      Uri.parse('$baseUrl/api/parent/assigned-activities/$assignmentId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to delete activity').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> completeTeacherAssignedActivity(
      String assignmentId,
      ) async {
    final headers = await _authHeaders();

    final res = await http
        .put(
      Uri.parse('$baseUrl/api/teacher/activities/$assignmentId/complete'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to complete assignment').toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> deleteTeacherAssignedActivity(
      String assignmentId,
      ) async {
    final headers = await _authHeaders();

    final res = await http
        .delete(
      Uri.parse('$baseUrl/api/teacher/activities/$assignmentId'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to delete assignment').toString();
    }

    return data;
  }


  // -------------------- TODDLER MOCK TEST --------------------

  static Future<Map<String, dynamic>> generateToddlerMockTest({
    required String toddlerId,
    int count = 40,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/toddlers/$toddlerId/mock-test/generate'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'count': count}),
    )
        .timeout(const Duration(seconds: 120));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to generate mock test').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> submitToddlerMockTestResult({
    required String toddlerId,
    required List<Map<String, dynamic>> answers,
    DateTime? startedAt,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/toddlers/$toddlerId/mock-test/submit'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'answers': answers,
        if (startedAt != null) 'startedAt': startedAt.toIso8601String(),
      }),
    )
        .timeout(const Duration(seconds: 45));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to save mock test result').toString();
    }
    return data;
  }

  static Future<List<dynamic>> getToddlerMockTestResults({
    required String toddlerId,
    int limit = 20,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse('$baseUrl/api/toddlers/$toddlerId/mock-test/results').replace(
      queryParameters: {'limit': limit.toString()},
    );

    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load mock test results').toString();
    }

    return (data['results'] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> sendMockTestReportToTeacher({
    required String resultId,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/mock-test-results/$resultId/send-to-teacher'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to send report to teacher').toString();
    }
    return data;
  }

  static Future<List<dynamic>> getTeacherMockTestResults({
    int limit = 30,
    bool? sentToTeacher,
    String? createdByRole,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse('$baseUrl/api/teacher/mock-test-results').replace(
      queryParameters: {
        'limit': limit.toString(),
        if (sentToTeacher != null) 'sentToTeacher': sentToTeacher ? '1' : '0',
        if (createdByRole != null && createdByRole.trim().isNotEmpty)
          'createdByRole': createdByRole.trim(),
      },
    );

    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load teacher mock test reports').toString();
    }

    return (data['results'] as List<dynamic>? ?? []);
  }

  static String _newsIdentifierPath(String articleIdentifier) {
    final value = articleIdentifier.trim();
    if (value.isEmpty) {
      throw 'Article identifier is missing';
    }
    return Uri.encodeComponent(value);
  }

  // -------------------- URDU NEWS --------------------

  static Future<Map<String, dynamic>> refreshNews({
    int days = 7,
    int limit = 10,
    String query = '',
    String topic = '',
    bool savedOnly = false,
    bool clearCache = true,
  }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/news/refresh'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      body: jsonEncode({
        'days': days,
        'limit': limit,
        'query': query.trim(),
        'topic': topic.trim(),
        'savedOnly': savedOnly,
        'clearCache': clearCache,
        'cacheBust': DateTime.now().millisecondsSinceEpoch,
      }),
    )
        .timeout(const Duration(seconds: 150));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to refresh news').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> getNewsArticles({
    int days = 7,
    int page = 1,
    int limit = 10,
    String query = '',
    String topic = '',
    bool savedOnly = false,
    bool forceRefresh = false,
  }) async {
    final headers = await _authHeaders();

    Future<Map<String, dynamic>> fetchOnce({bool refresh = false}) async {
      final uri = Uri.parse('$baseUrl/api/news').replace(
        queryParameters: {
          'days': days.toString(),
          'page': page.toString(),
          'limit': limit.toString(),
          '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
          if (query.trim().isNotEmpty) 'query': query.trim(),
          if (topic.trim().isNotEmpty) 'topic': topic.trim(),
          if (savedOnly) 'savedOnly': '1',
          if (refresh) 'refresh': '1',
          if (refresh) 'clearCache': '1',
        },
      );

      final res = await http
          .get(
        uri,
        headers: {
          ...headers,
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      )
          .timeout(Duration(seconds: refresh ? 150 : 45));

      final data = _safeJson(res.body);
      if (res.statusCode != 200) {
        throw (data['message'] ?? 'Failed to load news').toString();
      }
      return data;
    }

    var data = await fetchOnce(refresh: forceRefresh && page == 1 && !savedOnly);
    final firstPage = page == 1;
    final shouldRetry = firstPage && query.trim().isEmpty && topic.trim().isEmpty && !savedOnly && !forceRefresh &&
        ((data['articles'] as List?)?.isEmpty ?? true);

    if (!shouldRetry) {
      return data;
    }

    try {
      data = await refreshNews(days: days, limit: limit, query: query, topic: topic);
    } catch (_) {
      // Keep the original empty response if refresh fails.
    }

    return data;
  }

  static Future<Map<String, dynamic>> getNewsDetail(String articleId) async {
    final headers = await _authHeaders();

    final res = await http
        .get(
      Uri.parse('$baseUrl/api/news/${_newsIdentifierPath(articleId)}'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 30));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load news detail').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> summarizeNews(
      String articleId, {
        bool force = false,
      }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/news/${_newsIdentifierPath(articleId)}/summarize'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'force': force}),
    )
        .timeout(const Duration(seconds: 60));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to summarize news').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> saveNewsToLibrary(
      String articleId, {
        bool saved = true,
      }) async {
    final headers = await _authHeaders();

    final res = await http
        .post(
      Uri.parse('$baseUrl/api/news/${_newsIdentifierPath(articleId)}/save'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'saved': saved}),
    )
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to update library').toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> getMySavedNews({
    int page = 1,
    int limit = 20,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse('$baseUrl/api/news/library/me').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data['message'] ?? 'Failed to load saved news').toString();
    }
    return data;
  }
}