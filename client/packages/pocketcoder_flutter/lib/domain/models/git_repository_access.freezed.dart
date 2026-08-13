// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'git_repository_access.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GitRepositoryAccess {
  String get id;
  String get user;
  @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
  GitRepositoryAccessProvider get provider;
  String get repository;
  String get purpose;
  @JsonKey(unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
  GitRepositoryAccessCredentialMode get credentialMode;
  String? get credential;
  @JsonKey(unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
  GitRepositoryAccessRequestedAccess get requestedAccess;
  @JsonKey(unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
  GitRepositoryAccessRegistrationStatus get registrationStatus;
  @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
  GitRepositoryAccessStatus get status;
  String? get lastError;

  /// Create a copy of GitRepositoryAccess
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GitRepositoryAccessCopyWith<GitRepositoryAccess> get copyWith =>
      _$GitRepositoryAccessCopyWithImpl<GitRepositoryAccess>(
          this as GitRepositoryAccess, _$identity);

  /// Serializes this GitRepositoryAccess to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GitRepositoryAccess &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.repository, repository) ||
                other.repository == repository) &&
            (identical(other.purpose, purpose) || other.purpose == purpose) &&
            (identical(other.credentialMode, credentialMode) ||
                other.credentialMode == credentialMode) &&
            (identical(other.credential, credential) ||
                other.credential == credential) &&
            (identical(other.requestedAccess, requestedAccess) ||
                other.requestedAccess == requestedAccess) &&
            (identical(other.registrationStatus, registrationStatus) ||
                other.registrationStatus == registrationStatus) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      user,
      provider,
      repository,
      purpose,
      credentialMode,
      credential,
      requestedAccess,
      registrationStatus,
      status,
      lastError);

  @override
  String toString() {
    return 'GitRepositoryAccess(id: $id, user: $user, provider: $provider, repository: $repository, purpose: $purpose, credentialMode: $credentialMode, credential: $credential, requestedAccess: $requestedAccess, registrationStatus: $registrationStatus, status: $status, lastError: $lastError)';
  }
}

/// @nodoc
abstract mixin class $GitRepositoryAccessCopyWith<$Res> {
  factory $GitRepositoryAccessCopyWith(
          GitRepositoryAccess value, $Res Function(GitRepositoryAccess) _then) =
      _$GitRepositoryAccessCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String user,
      @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
      GitRepositoryAccessProvider provider,
      String repository,
      String purpose,
      @JsonKey(unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
      GitRepositoryAccessCredentialMode credentialMode,
      String? credential,
      @JsonKey(unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
      GitRepositoryAccessRequestedAccess requestedAccess,
      @JsonKey(unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
      GitRepositoryAccessRegistrationStatus registrationStatus,
      @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
      GitRepositoryAccessStatus status,
      String? lastError});
}

/// @nodoc
class _$GitRepositoryAccessCopyWithImpl<$Res>
    implements $GitRepositoryAccessCopyWith<$Res> {
  _$GitRepositoryAccessCopyWithImpl(this._self, this._then);

  final GitRepositoryAccess _self;
  final $Res Function(GitRepositoryAccess) _then;

  /// Create a copy of GitRepositoryAccess
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? provider = null,
    Object? repository = null,
    Object? purpose = null,
    Object? credentialMode = null,
    Object? credential = freezed,
    Object? requestedAccess = null,
    Object? registrationStatus = null,
    Object? status = null,
    Object? lastError = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessProvider,
      repository: null == repository
          ? _self.repository
          : repository // ignore: cast_nullable_to_non_nullable
              as String,
      purpose: null == purpose
          ? _self.purpose
          : purpose // ignore: cast_nullable_to_non_nullable
              as String,
      credentialMode: null == credentialMode
          ? _self.credentialMode
          : credentialMode // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessCredentialMode,
      credential: freezed == credential
          ? _self.credential
          : credential // ignore: cast_nullable_to_non_nullable
              as String?,
      requestedAccess: null == requestedAccess
          ? _self.requestedAccess
          : requestedAccess // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessRequestedAccess,
      registrationStatus: null == registrationStatus
          ? _self.registrationStatus
          : registrationStatus // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessRegistrationStatus,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [GitRepositoryAccess].
extension GitRepositoryAccessPatterns on GitRepositoryAccess {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_GitRepositoryAccess value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GitRepositoryAccess() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_GitRepositoryAccess value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitRepositoryAccess():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_GitRepositoryAccess value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitRepositoryAccess() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String user,
            @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
            GitRepositoryAccessProvider provider,
            String repository,
            String purpose,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
            GitRepositoryAccessCredentialMode credentialMode,
            String? credential,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
            GitRepositoryAccessRequestedAccess requestedAccess,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
            GitRepositoryAccessRegistrationStatus registrationStatus,
            @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
            GitRepositoryAccessStatus status,
            String? lastError)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GitRepositoryAccess() when $default != null:
        return $default(
            _that.id,
            _that.user,
            _that.provider,
            _that.repository,
            _that.purpose,
            _that.credentialMode,
            _that.credential,
            _that.requestedAccess,
            _that.registrationStatus,
            _that.status,
            _that.lastError);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            String user,
            @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
            GitRepositoryAccessProvider provider,
            String repository,
            String purpose,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
            GitRepositoryAccessCredentialMode credentialMode,
            String? credential,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
            GitRepositoryAccessRequestedAccess requestedAccess,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
            GitRepositoryAccessRegistrationStatus registrationStatus,
            @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
            GitRepositoryAccessStatus status,
            String? lastError)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitRepositoryAccess():
        return $default(
            _that.id,
            _that.user,
            _that.provider,
            _that.repository,
            _that.purpose,
            _that.credentialMode,
            _that.credential,
            _that.requestedAccess,
            _that.registrationStatus,
            _that.status,
            _that.lastError);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String user,
            @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
            GitRepositoryAccessProvider provider,
            String repository,
            String purpose,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
            GitRepositoryAccessCredentialMode credentialMode,
            String? credential,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
            GitRepositoryAccessRequestedAccess requestedAccess,
            @JsonKey(
                unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
            GitRepositoryAccessRegistrationStatus registrationStatus,
            @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
            GitRepositoryAccessStatus status,
            String? lastError)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitRepositoryAccess() when $default != null:
        return $default(
            _that.id,
            _that.user,
            _that.provider,
            _that.repository,
            _that.purpose,
            _that.credentialMode,
            _that.credential,
            _that.requestedAccess,
            _that.registrationStatus,
            _that.status,
            _that.lastError);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _GitRepositoryAccess implements GitRepositoryAccess {
  const _GitRepositoryAccess(
      {required this.id,
      required this.user,
      @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
      required this.provider,
      required this.repository,
      required this.purpose,
      @JsonKey(unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
      required this.credentialMode,
      this.credential,
      @JsonKey(unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
      required this.requestedAccess,
      @JsonKey(unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
      required this.registrationStatus,
      @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
      required this.status,
      this.lastError});
  factory _GitRepositoryAccess.fromJson(Map<String, dynamic> json) =>
      _$GitRepositoryAccessFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
  final GitRepositoryAccessProvider provider;
  @override
  final String repository;
  @override
  final String purpose;
  @override
  @JsonKey(unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
  final GitRepositoryAccessCredentialMode credentialMode;
  @override
  final String? credential;
  @override
  @JsonKey(unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
  final GitRepositoryAccessRequestedAccess requestedAccess;
  @override
  @JsonKey(unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
  final GitRepositoryAccessRegistrationStatus registrationStatus;
  @override
  @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
  final GitRepositoryAccessStatus status;
  @override
  final String? lastError;

  /// Create a copy of GitRepositoryAccess
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GitRepositoryAccessCopyWith<_GitRepositoryAccess> get copyWith =>
      __$GitRepositoryAccessCopyWithImpl<_GitRepositoryAccess>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GitRepositoryAccessToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GitRepositoryAccess &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.repository, repository) ||
                other.repository == repository) &&
            (identical(other.purpose, purpose) || other.purpose == purpose) &&
            (identical(other.credentialMode, credentialMode) ||
                other.credentialMode == credentialMode) &&
            (identical(other.credential, credential) ||
                other.credential == credential) &&
            (identical(other.requestedAccess, requestedAccess) ||
                other.requestedAccess == requestedAccess) &&
            (identical(other.registrationStatus, registrationStatus) ||
                other.registrationStatus == registrationStatus) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      user,
      provider,
      repository,
      purpose,
      credentialMode,
      credential,
      requestedAccess,
      registrationStatus,
      status,
      lastError);

  @override
  String toString() {
    return 'GitRepositoryAccess(id: $id, user: $user, provider: $provider, repository: $repository, purpose: $purpose, credentialMode: $credentialMode, credential: $credential, requestedAccess: $requestedAccess, registrationStatus: $registrationStatus, status: $status, lastError: $lastError)';
  }
}

/// @nodoc
abstract mixin class _$GitRepositoryAccessCopyWith<$Res>
    implements $GitRepositoryAccessCopyWith<$Res> {
  factory _$GitRepositoryAccessCopyWith(_GitRepositoryAccess value,
          $Res Function(_GitRepositoryAccess) _then) =
      __$GitRepositoryAccessCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String user,
      @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
      GitRepositoryAccessProvider provider,
      String repository,
      String purpose,
      @JsonKey(unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
      GitRepositoryAccessCredentialMode credentialMode,
      String? credential,
      @JsonKey(unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
      GitRepositoryAccessRequestedAccess requestedAccess,
      @JsonKey(unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
      GitRepositoryAccessRegistrationStatus registrationStatus,
      @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
      GitRepositoryAccessStatus status,
      String? lastError});
}

/// @nodoc
class __$GitRepositoryAccessCopyWithImpl<$Res>
    implements _$GitRepositoryAccessCopyWith<$Res> {
  __$GitRepositoryAccessCopyWithImpl(this._self, this._then);

  final _GitRepositoryAccess _self;
  final $Res Function(_GitRepositoryAccess) _then;

  /// Create a copy of GitRepositoryAccess
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? provider = null,
    Object? repository = null,
    Object? purpose = null,
    Object? credentialMode = null,
    Object? credential = freezed,
    Object? requestedAccess = null,
    Object? registrationStatus = null,
    Object? status = null,
    Object? lastError = freezed,
  }) {
    return _then(_GitRepositoryAccess(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessProvider,
      repository: null == repository
          ? _self.repository
          : repository // ignore: cast_nullable_to_non_nullable
              as String,
      purpose: null == purpose
          ? _self.purpose
          : purpose // ignore: cast_nullable_to_non_nullable
              as String,
      credentialMode: null == credentialMode
          ? _self.credentialMode
          : credentialMode // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessCredentialMode,
      credential: freezed == credential
          ? _self.credential
          : credential // ignore: cast_nullable_to_non_nullable
              as String?,
      requestedAccess: null == requestedAccess
          ? _self.requestedAccess
          : requestedAccess // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessRequestedAccess,
      registrationStatus: null == registrationStatus
          ? _self.registrationStatus
          : registrationStatus // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessRegistrationStatus,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as GitRepositoryAccessStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
