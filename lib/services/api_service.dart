import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:3000";

  static String absoluteUrl(String path) {
    final p = path.trim();
    if (p.isEmpty) return p;
    if (p.startsWith("http://") || p.startsWith("https://")) return p;
    if (!p.startsWith("/")) return "$baseUrl/$p";
    return "$baseUrl$p";
  }

  // -------------------- TOKEN STORAGE --------------------

  static Future<void> saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("token", token);
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString("token");
  }

  static Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove("token");
  }

  static Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"raw": decoded};
    } catch (_) {
      return {"message": body};
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    if (token == null) throw "Token missing. Please login again.";
    return {"Authorization": "Bearer $token"};
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
    final res = await http.post(
      Uri.parse("$baseUrl/api/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Login failed").toString();
    }

    final token = data["token"]?.toString();
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
    final res = await http.post(
      Uri.parse("$baseUrl/api/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "role": role,
        "name": name,
        "email": email,
        "password": password,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Signup failed").toString();
    }

    final token = data["token"]?.toString();
    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }
    return data;
  }

  // -------------------- ME (PROFILE) --------------------

  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/me"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load profile").toString();
    }
    return data;
  }

  static Future<Uint8List?> getMyProfilePhotoBytes() async {
    final token = await getToken();
    if (token == null) throw "Token missing. Please login again.";

    final res = await http.get(
      Uri.parse("$baseUrl/api/me/photo"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 404) return null;

    if (res.statusCode != 200) {
      final data = _safeJson(res.body);
      throw (data["message"] ?? "Failed to load profile photo").toString();
    }

    return res.bodyBytes;
  }

  static Future<Map<String, dynamic>> uploadMyProfilePhoto({
    required File photoFile,
  }) async {
    final token = await getToken();
    if (token == null) throw "Token missing. Please login again.";

    final uri = Uri.parse("$baseUrl/api/me/photo");
    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = "Bearer $token";

    req.files.add(await http.MultipartFile.fromPath("photo", photoFile.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data["message"] ?? "Failed to upload photo").toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/me/password"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "currentPassword": currentPassword,
        "newPassword": newPassword,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to change password").toString();
    }
    return data;
  }

  // -------------------- TODDLERS (PARENT) --------------------

  static Future<List<dynamic>> getToddlers() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/toddlers"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load toddlers").toString();
    }

    return (data["toddlers"] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createToddler({
    required String name,
    required String schoolName,
    required String className,
    required int age,
    File? photoFile,
  }) async {
    final token = await getToken();
    if (token == null) throw "Token missing. Please login again.";

    final uri = Uri.parse("$baseUrl/api/toddlers");
    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = "Bearer $token";

    req.fields["name"] = name.trim();
    req.fields["schoolName"] = schoolName.trim();
    req.fields["className"] = className.trim();
    req.fields["age"] = age.toString();

    if (photoFile != null) {
      req.files.add(await http.MultipartFile.fromPath("photo", photoFile.path));
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data["message"] ?? "Failed to create toddler").toString();
    }
    return data;
  }

  static Future<void> setActiveToddler(String toddlerId) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/toddlers/$toddlerId/active"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to set active toddler").toString();
    }
  }

  static Future<Map<String, dynamic>> getToddlerProgress(String toddlerId) async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/toddlers/$toddlerId/progress"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load progress").toString();
    }

    return data;
  }

  // -------------------- STORY STUDIO --------------------

  static String storyAudioUrl(String storyId) {
    return absoluteUrl("/api/stories/$storyId/audio");
  }

  static Future<List<dynamic>> getStories() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/stories"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load stories").toString();
    }

    return (data["stories"] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createStory({
    required String title,
    required int durationSec,
    required File audioFile,
    String language = "Urdu",
    bool isDraft = false,
    String? toddlerId,
  }) async {
    final token = await getToken();
    if (token == null) throw "Token missing. Please login again.";

    final uri = Uri.parse("$baseUrl/api/stories");
    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = "Bearer $token";

    req.fields["title"] = title.trim();
    req.fields["language"] = language;
    req.fields["durationSec"] = durationSec.toString();
    req.fields["isDraft"] = isDraft.toString();

    if (toddlerId != null && toddlerId.trim().isNotEmpty) {
      req.fields["toddlerId"] = toddlerId.trim();
    }

    req.files.add(await http.MultipartFile.fromPath("audio", audioFile.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data["message"] ?? "Failed to save story").toString();
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateStory({
    required String storyId,
    required String title,
    required int durationSec,
    String language = "Urdu",
    bool isDraft = false,
    File? audioFile,
  }) async {
    final token = await getToken();
    if (token == null) throw "Token missing. Please login again.";

    final uri = Uri.parse("$baseUrl/api/stories/$storyId");
    final req = http.MultipartRequest("PUT", uri);
    req.headers["Authorization"] = "Bearer $token";

    req.fields["title"] = title.trim();
    req.fields["language"] = language;
    req.fields["durationSec"] = durationSec.toString();
    req.fields["isDraft"] = isDraft.toString();

    if (audioFile != null) {
      req.files.add(await http.MultipartFile.fromPath("audio", audioFile.path));
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = _safeJson(body);

    if (streamed.statusCode != 200) {
      throw (data["message"] ?? "Failed to update story").toString();
    }
    return data;
  }

  static Future<void> deleteStory(String storyId) async {
    final headers = await _authHeaders();

    final res = await http.delete(
      Uri.parse("$baseUrl/api/stories/$storyId"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to delete story").toString();
    }
  }

  static Future<Map<String, dynamic>> assignStory({
    required String storyId,
    required bool assignToAll,
    List<String> toddlerIds = const [],
  }) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/stories/$storyId/assign"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "assignToAll": assignToAll,
        "toddlerIds": toddlerIds,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to assign story").toString();
    }
    return data;
  }

  // -------------------- TEACHER DASHBOARD --------------------

  static Future<Map<String, dynamic>> getTeacherDashboard() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/teacher/dashboard"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load teacher dashboard").toString();
    }

    return data;
  }

  // -------------------- TEACHER CLASSES --------------------

  static Future<List<dynamic>> getTeacherClasses() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/teacher/classes"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load classes").toString();
    }

    return (data["classes"] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createTeacherClass({
    required String title,
    String subtitle = "",
  }) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse("$baseUrl/api/teacher/classes"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "subtitle": subtitle,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to create class").toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> updateTeacherClass({
    required String classId,
    required String title,
    String subtitle = "",
  }) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/teacher/classes/$classId"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "subtitle": subtitle,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to update class").toString();
    }

    return data;
  }

  static Future<void> deleteTeacherClass({
    required String classId,
  }) async {
    final headers = await _authHeaders();

    final res = await http.delete(
      Uri.parse("$baseUrl/api/teacher/classes/$classId"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to delete class").toString();
    }
  }

  // -------------------- TEACHER EVENTS --------------------

  static Future<List<dynamic>> getTeacherEvents({
    int days = 7,
    bool all = false,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse("$baseUrl/api/teacher/events").replace(
      queryParameters: {
        if (all) "all": "1",
        if (!all) "days": days.toString(),
      },
    );

    final res = await http.get(uri, headers: headers);

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load events").toString();
    }

    return (data["events"] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> createTeacherEvent({
    required String title,
    required DateTime startAt,
    String note = "",
  }) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse("$baseUrl/api/teacher/events"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "startAt": startAt.toIso8601String(),
        "note": note,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to create event").toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> updateTeacherEvent({
    required String eventId,
    required String title,
    required DateTime startAt,
    String note = "",
  }) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/teacher/events/$eventId"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "title": title,
        "startAt": startAt.toIso8601String(),
        "note": note,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to update event").toString();
    }

    return data;
  }

  static Future<void> deleteTeacherEvent({
    required String eventId,
  }) async {
    final headers = await _authHeaders();

    final res = await http.delete(
      Uri.parse("$baseUrl/api/teacher/events/$eventId"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to delete event").toString();
    }
  }

  // -------------------- TEACHER TODDLERS --------------------

  static Future<List<dynamic>> getAllToddlersForTeacher() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/teacher/toddlers"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load toddlers").toString();
    }

    return (data["toddlers"] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> assignToddlerToClass({
    required String toddlerId,
    required String? classId,
  }) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/teacher/toddlers/$toddlerId/assign-class"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"classId": classId}),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to assign class").toString();
    }

    return data;
  }

  // -------------------- TEACHER ACTIVITIES --------------------

  static Future<Map<String, dynamic>> getTeacherActivityTargets() async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/teacher/activity-targets"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load activity targets").toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> assignTeacherActivity({
    required String activityType,
    required String targetType,
    String? classId,
    List<String> toddlerIds = const [],
    String title = "",
    String description = "",
  }) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse("$baseUrl/api/teacher/activities/assign"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "activityType": activityType,
        "targetType": targetType,
        "classId": classId,
        "toddlerIds": toddlerIds,
        "title": title,
        "description": description,
      }),
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to assign activity").toString();
    }

    return data;
  }

  static Future<List<dynamic>> getTeacherAssignedActivities({
    int limit = 20,
  }) async {
    final headers = await _authHeaders();

    final uri = Uri.parse("$baseUrl/api/teacher/activities").replace(
      queryParameters: {"limit": limit.toString()},
    );

    final res = await http.get(uri, headers: headers);
    final data = _safeJson(res.body);

    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load teacher assignments").toString();
    }

    return (data["assignments"] as List<dynamic>? ?? []);
  }

  static Future<List<dynamic>> getToddlerAssignedActivities(String toddlerId) async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse("$baseUrl/api/toddlers/$toddlerId/assigned-activities"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to load assigned activities").toString();
    }

    return (data["assignments"] as List<dynamic>? ?? []);
  }

  static Future<Map<String, dynamic>> completeAssignedActivity(String assignmentId) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/parent/assigned-activities/$assignmentId/complete"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to complete activity").toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> deleteAssignedActivity(String assignmentId) async {
    final headers = await _authHeaders();

    final res = await http.delete(
      Uri.parse("$baseUrl/api/parent/assigned-activities/$assignmentId"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to delete activity").toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> completeTeacherAssignedActivity(
      String assignmentId,
      ) async {
    final headers = await _authHeaders();

    final res = await http.put(
      Uri.parse("$baseUrl/api/teacher/activities/$assignmentId/complete"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to complete assignment").toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> deleteTeacherAssignedActivity(
      String assignmentId,
      ) async {
    final headers = await _authHeaders();

    final res = await http.delete(
      Uri.parse("$baseUrl/api/teacher/activities/$assignmentId"),
      headers: headers,
    );

    final data = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw (data["message"] ?? "Failed to delete assignment").toString();
    }

    return data;
  }
}