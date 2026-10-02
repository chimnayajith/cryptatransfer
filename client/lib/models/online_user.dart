class OnlineUser {
  final String userId;
  final String publicKey;

  OnlineUser({
    required this.userId,
    required this.publicKey,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      userId: json['userId'].toString(),
      publicKey: json['publicKey'].toString(),
    );
  }
}