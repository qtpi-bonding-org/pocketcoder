// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'git_ssh_credential.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GitSshCredential {
  String get id;
  String get user;
  String get label;
  @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
  GitSshCredentialKind get kind;
  @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
  GitSshCredentialSource get source;
  @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
  GitSshCredentialAlgorithm get algorithm;
  String? get publicKey;
  String? get fingerprint;
  @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
  GitSshCredentialStatus get status;
  String? get lastError;
  String? get materializedGeneration;

  /// Create a copy of GitSshCredential
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GitSshCredentialCopyWith<GitSshCredential> get copyWith =>
      _$GitSshCredentialCopyWithImpl<GitSshCredential>(
          this as GitSshCredential, _$identity);

  /// Serializes this GitSshCredential to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GitSshCredential &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.algorithm, algorithm) ||
                other.algorithm == algorithm) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.materializedGeneration, materializedGeneration) ||
                other.materializedGeneration == materializedGeneration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      user,
      label,
      kind,
      source,
      algorithm,
      publicKey,
      fingerprint,
      status,
      lastError,
      materializedGeneration);

  @override
  String toString() {
    return 'GitSshCredential(id: $id, user: $user, label: $label, kind: $kind, source: $source, algorithm: $algorithm, publicKey: $publicKey, fingerprint: $fingerprint, status: $status, lastError: $lastError, materializedGeneration: $materializedGeneration)';
  }
}

/// @nodoc
abstract mixin class $GitSshCredentialCopyWith<$Res> {
  factory $GitSshCredentialCopyWith(
          GitSshCredential value, $Res Function(GitSshCredential) _then) =
      _$GitSshCredentialCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String user,
      String label,
      @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
      GitSshCredentialKind kind,
      @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
      GitSshCredentialSource source,
      @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
      GitSshCredentialAlgorithm algorithm,
      String? publicKey,
      String? fingerprint,
      @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
      GitSshCredentialStatus status,
      String? lastError,
      String? materializedGeneration});
}

/// @nodoc
class _$GitSshCredentialCopyWithImpl<$Res>
    implements $GitSshCredentialCopyWith<$Res> {
  _$GitSshCredentialCopyWithImpl(this._self, this._then);

  final GitSshCredential _self;
  final $Res Function(GitSshCredential) _then;

  /// Create a copy of GitSshCredential
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? label = null,
    Object? kind = null,
    Object? source = null,
    Object? algorithm = null,
    Object? publicKey = freezed,
    Object? fingerprint = freezed,
    Object? status = null,
    Object? lastError = freezed,
    Object? materializedGeneration = freezed,
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
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialKind,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialSource,
      algorithm: null == algorithm
          ? _self.algorithm
          : algorithm // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialAlgorithm,
      publicKey: freezed == publicKey
          ? _self.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String?,
      fingerprint: freezed == fingerprint
          ? _self.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
      materializedGeneration: freezed == materializedGeneration
          ? _self.materializedGeneration
          : materializedGeneration // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [GitSshCredential].
extension GitSshCredentialPatterns on GitSshCredential {
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
    TResult Function(_GitSshCredential value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GitSshCredential() when $default != null:
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
    TResult Function(_GitSshCredential value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshCredential():
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
    TResult? Function(_GitSshCredential value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshCredential() when $default != null:
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
            String label,
            @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
            GitSshCredentialKind kind,
            @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
            GitSshCredentialSource source,
            @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
            GitSshCredentialAlgorithm algorithm,
            String? publicKey,
            String? fingerprint,
            @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
            GitSshCredentialStatus status,
            String? lastError,
            String? materializedGeneration)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GitSshCredential() when $default != null:
        return $default(
            _that.id,
            _that.user,
            _that.label,
            _that.kind,
            _that.source,
            _that.algorithm,
            _that.publicKey,
            _that.fingerprint,
            _that.status,
            _that.lastError,
            _that.materializedGeneration);
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
            String label,
            @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
            GitSshCredentialKind kind,
            @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
            GitSshCredentialSource source,
            @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
            GitSshCredentialAlgorithm algorithm,
            String? publicKey,
            String? fingerprint,
            @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
            GitSshCredentialStatus status,
            String? lastError,
            String? materializedGeneration)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshCredential():
        return $default(
            _that.id,
            _that.user,
            _that.label,
            _that.kind,
            _that.source,
            _that.algorithm,
            _that.publicKey,
            _that.fingerprint,
            _that.status,
            _that.lastError,
            _that.materializedGeneration);
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
            String label,
            @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
            GitSshCredentialKind kind,
            @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
            GitSshCredentialSource source,
            @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
            GitSshCredentialAlgorithm algorithm,
            String? publicKey,
            String? fingerprint,
            @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
            GitSshCredentialStatus status,
            String? lastError,
            String? materializedGeneration)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshCredential() when $default != null:
        return $default(
            _that.id,
            _that.user,
            _that.label,
            _that.kind,
            _that.source,
            _that.algorithm,
            _that.publicKey,
            _that.fingerprint,
            _that.status,
            _that.lastError,
            _that.materializedGeneration);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _GitSshCredential implements GitSshCredential {
  const _GitSshCredential(
      {required this.id,
      required this.user,
      required this.label,
      @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
      required this.kind,
      @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
      required this.source,
      @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
      required this.algorithm,
      this.publicKey,
      this.fingerprint,
      @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
      required this.status,
      this.lastError,
      this.materializedGeneration});
  factory _GitSshCredential.fromJson(Map<String, dynamic> json) =>
      _$GitSshCredentialFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final String label;
  @override
  @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
  final GitSshCredentialKind kind;
  @override
  @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
  final GitSshCredentialSource source;
  @override
  @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
  final GitSshCredentialAlgorithm algorithm;
  @override
  final String? publicKey;
  @override
  final String? fingerprint;
  @override
  @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
  final GitSshCredentialStatus status;
  @override
  final String? lastError;
  @override
  final String? materializedGeneration;

  /// Create a copy of GitSshCredential
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GitSshCredentialCopyWith<_GitSshCredential> get copyWith =>
      __$GitSshCredentialCopyWithImpl<_GitSshCredential>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GitSshCredentialToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GitSshCredential &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.algorithm, algorithm) ||
                other.algorithm == algorithm) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.materializedGeneration, materializedGeneration) ||
                other.materializedGeneration == materializedGeneration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      user,
      label,
      kind,
      source,
      algorithm,
      publicKey,
      fingerprint,
      status,
      lastError,
      materializedGeneration);

  @override
  String toString() {
    return 'GitSshCredential(id: $id, user: $user, label: $label, kind: $kind, source: $source, algorithm: $algorithm, publicKey: $publicKey, fingerprint: $fingerprint, status: $status, lastError: $lastError, materializedGeneration: $materializedGeneration)';
  }
}

/// @nodoc
abstract mixin class _$GitSshCredentialCopyWith<$Res>
    implements $GitSshCredentialCopyWith<$Res> {
  factory _$GitSshCredentialCopyWith(
          _GitSshCredential value, $Res Function(_GitSshCredential) _then) =
      __$GitSshCredentialCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String user,
      String label,
      @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
      GitSshCredentialKind kind,
      @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
      GitSshCredentialSource source,
      @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
      GitSshCredentialAlgorithm algorithm,
      String? publicKey,
      String? fingerprint,
      @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
      GitSshCredentialStatus status,
      String? lastError,
      String? materializedGeneration});
}

/// @nodoc
class __$GitSshCredentialCopyWithImpl<$Res>
    implements _$GitSshCredentialCopyWith<$Res> {
  __$GitSshCredentialCopyWithImpl(this._self, this._then);

  final _GitSshCredential _self;
  final $Res Function(_GitSshCredential) _then;

  /// Create a copy of GitSshCredential
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? label = null,
    Object? kind = null,
    Object? source = null,
    Object? algorithm = null,
    Object? publicKey = freezed,
    Object? fingerprint = freezed,
    Object? status = null,
    Object? lastError = freezed,
    Object? materializedGeneration = freezed,
  }) {
    return _then(_GitSshCredential(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialKind,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialSource,
      algorithm: null == algorithm
          ? _self.algorithm
          : algorithm // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialAlgorithm,
      publicKey: freezed == publicKey
          ? _self.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String?,
      fingerprint: freezed == fingerprint
          ? _self.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as GitSshCredentialStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
      materializedGeneration: freezed == materializedGeneration
          ? _self.materializedGeneration
          : materializedGeneration // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
