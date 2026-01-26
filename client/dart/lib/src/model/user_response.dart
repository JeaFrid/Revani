class RevaniUserResponse {
  final String username;
  final String uid;
  final String email;
  final String emailVerified;
  final String password;
  final String role;
  final String firstName;
  final String lastName;
  final String displayName;
  final String avatarUrl;
  final String gender;
  final String dateOfBirth;
  final String biography;
  final String preferredLanguage;
  final String timezone;
  final String accountStatus;
  final String accountUpdated;
  final String accountCreation;
  final String accountType;
  final String lastLoginTimestamp;
  final String lastLoginIp;
  final String socialMedias;
  final String theme;
  final String street;
  final String city;
  final String postalCode;
  final String country;
  final String locale;
  final String posts;
  final String createdBy;
  final String updatedBy;
  final String version;
  final Map<String, dynamic> data;

  RevaniUserResponse({
    required this.username,
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.password,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.avatarUrl,
    required this.gender,
    required this.dateOfBirth,
    required this.biography,
    required this.preferredLanguage,
    required this.timezone,
    required this.accountStatus,
    required this.accountUpdated,
    required this.accountCreation,
    required this.accountType,
    required this.lastLoginTimestamp,
    required this.lastLoginIp,
    required this.socialMedias,
    required this.theme,
    required this.street,
    required this.city,
    required this.postalCode,
    required this.country,
    required this.locale,
    required this.posts,
    required this.createdBy,
    required this.updatedBy,
    required this.version,
    required this.data,
  });

  factory RevaniUserResponse.empty() {
    return RevaniUserResponse(
      username: '',
      uid: '',
      email: '',
      emailVerified: '',
      password: '',
      role: '',
      firstName: '',
      lastName: '',
      displayName: '',
      avatarUrl: '',
      gender: '',
      dateOfBirth: '',
      biography: '',
      preferredLanguage: '',
      timezone: '',
      accountStatus: '',
      accountUpdated: '',
      accountCreation: '',
      accountType: '',
      lastLoginTimestamp: '',
      lastLoginIp: '',
      socialMedias: '',
      theme: '',
      street: '',
      city: '',
      postalCode: '',
      country: '',
      locale: '',
      posts: '',
      createdBy: '',
      updatedBy: '',
      version: '',
      data: {},
    );
  }

  factory RevaniUserResponse.fromJson(Map<String, dynamic> json) {
    return RevaniUserResponse(
      username: json['username'] ?? '',
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      emailVerified: json['email_verified '] ?? '', // JSON'da boşluk var
      password: json['password'] ?? '',
      role: json['role'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      displayName: json['display_name'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: json['date_of_birth'] ?? '',
      biography: json['biography'] ?? '',
      preferredLanguage: json['preferred_language'] ?? '',
      timezone: json['timezone'] ?? '',
      accountStatus: json['account_status'] ?? '',
      accountUpdated: json['account_updated'] ?? '',
      accountCreation: json['account_creation'] ?? '',
      accountType: json['account_type'] ?? '',
      lastLoginTimestamp: json['last_login_timestamp'] ?? '',
      lastLoginIp: json['last_login_ip'] ?? '',
      socialMedias: json['social_medias'] ?? '',
      theme: json['theme'] ?? '',
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      postalCode: json['postal_code'] ?? '',
      country: json['country'] ?? '',
      locale: json['locale'] ?? '',
      posts: json['posts'] ?? '',
      createdBy: json['created_by'] ?? '',
      updatedBy: json['updated_by'] ?? '',
      version: json['version'] ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data']
          : <String, dynamic>{},
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'uid': uid,
      'email': email,
      'email_verified ': emailVerified,
      'password': password,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'biography': biography,
      'preferred_language': preferredLanguage,
      'timezone': timezone,
      'account_status': accountStatus,
      'account_updated': accountUpdated,
      'account_creation': accountCreation,
      'account_type': accountType,
      'last_login_timestamp': lastLoginTimestamp,
      'last_login_ip': lastLoginIp,
      'social_medias': socialMedias,
      'theme': theme,
      'street': street,
      'city': city,
      'postal_code': postalCode,
      'country': country,
      'locale': locale,
      'posts': posts,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'version': version,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'User(username: $username, email: $email, displayName: $displayName)';
  }

  RevaniUserResponse copyWith({
    String? username,
    String? uid,
    String? email,
    String? emailVerified,
    String? password,
    String? role,
    String? firstName,
    String? lastName,
    String? displayName,
    String? avatarUrl,
    String? gender,
    String? dateOfBirth,
    String? biography,
    String? preferredLanguage,
    String? timezone,
    String? accountStatus,
    String? accountUpdated,
    String? accountCreation,
    String? accountType,
    String? lastLoginTimestamp,
    String? lastLoginIp,
    String? socialMedias,
    String? theme,
    String? street,
    String? city,
    String? postalCode,
    String? country,
    String? locale,
    String? posts,
    String? createdBy,
    String? updatedBy,
    String? version,
    Map<String, dynamic>? data,
  }) {
    return RevaniUserResponse(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      password: password ?? this.password,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      biography: biography ?? this.biography,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      timezone: timezone ?? this.timezone,
      accountStatus: accountStatus ?? this.accountStatus,
      accountUpdated: accountUpdated ?? this.accountUpdated,
      accountCreation: accountCreation ?? this.accountCreation,
      accountType: accountType ?? this.accountType,
      lastLoginTimestamp: lastLoginTimestamp ?? this.lastLoginTimestamp,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      socialMedias: socialMedias ?? this.socialMedias,
      theme: theme ?? this.theme,
      street: street ?? this.street,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      locale: locale ?? this.locale,
      posts: posts ?? this.posts,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      data: data ?? this.data,
    );
  }
}
