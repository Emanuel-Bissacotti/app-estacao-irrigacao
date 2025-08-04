class Client {
  final String uid;
  final String email;
  final String? emailMqtt;
  final String? passwordMqtt;

  Client({
    required this.uid,
    required this.email,
    this.emailMqtt,
    this.passwordMqtt,
  });

  factory Client.fromMap(Map<String, dynamic> data) {
    return Client(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      emailMqtt: data['emailMqtt'] != null ? data['emailMqtt'] as String : null,
      passwordMqtt: data['passwordMqtt'] != null ? data['passwordMqtt'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      if (emailMqtt != null) 'emailMqtt': emailMqtt,
      if (passwordMqtt != null) 'passwordMqtt': passwordMqtt,
    };
  }
}