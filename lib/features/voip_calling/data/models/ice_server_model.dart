/// KeepSIMs — WebRTC ICE Server Model
library;

class IceServerModel {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServerModel({required this.urls, this.username, this.credential});

  bool get isAuthenticatedRelay =>
      urls.any((url) => url.startsWith('turn:') || url.startsWith('turns:')) &&
      username?.trim().isNotEmpty == true &&
      credential?.trim().isNotEmpty == true;

  factory IceServerModel.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    List<String> parsedUrls = [];
    if (rawUrls is List) {
      parsedUrls = rawUrls.map((e) => e.toString()).toList();
    } else if (rawUrls is String) {
      parsedUrls = [rawUrls];
    }
    return IceServerModel(
      urls: parsedUrls,
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'urls': urls};
    if (username != null) map['username'] = username;
    if (credential != null) map['credential'] = credential;
    return map;
  }
}
