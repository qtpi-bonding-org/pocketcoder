// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'credential_selection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CredentialSelection {
  String get id;
  String get user;
  String get harness;
  String get provider;
  @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
  CredentialSelectionMode get mode;
  String? get oauthAccount;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of CredentialSelection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CredentialSelectionCopyWith<CredentialSelection> get copyWith =>
      _$CredentialSelectionCopyWithImpl<CredentialSelection>(
          this as CredentialSelection, _$identity);

  /// Serializes this CredentialSelection to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CredentialSelection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.oauthAccount, oauthAccount) ||
                other.oauthAccount == oauthAccount) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, user, harness, provider,
      mode, oauthAccount, created, updated);

  @override
  String toString() {
    return 'CredentialSelection(id: $id, user: $user, harness: $harness, provider: $provider, mode: $mode, oauthAccount: $oauthAccount, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $CredentialSelectionCopyWith<$Res> {
  factory $CredentialSelectionCopyWith(
          CredentialSelection value, $Res Function(CredentialSelection) _then) =
      _$CredentialSelectionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String user,
      String harness,
      String provider,
      @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
      CredentialSelectionMode mode,
      String? oauthAccount,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$CredentialSelectionCopyWithImpl<$Res>
    implements $CredentialSelectionCopyWith<$Res> {
  _$CredentialSelectionCopyWithImpl(this._self, this._then);

  final CredentialSelection _self;
  final $Res Function(CredentialSelection) _then;

  /// Create a copy of CredentialSelection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? harness = null,
    Object? provider = null,
    Object? mode = null,
    Object? oauthAccount = freezed,
    Object? created = freezed,
    Object? updated = freezed,
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
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as CredentialSelectionMode,
      oauthAccount: freezed == oauthAccount
          ? _self.oauthAccount
          : oauthAccount // ignore: cast_nullable_to_non_nullable
              as String?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CredentialSelection].
extension CredentialSelectionPatterns on CredentialSelection {
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
    TResult Function(_CredentialSelection value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CredentialSelection() when $default != null:
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
    TResult Function(_CredentialSelection value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CredentialSelection():
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
    TResult? Function(_CredentialSelection value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CredentialSelection() when $default != null:
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
            String harness,
            String provider,
            @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
            CredentialSelectionMode mode,
            String? oauthAccount,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CredentialSelection() when $default != null:
        return $default(_that.id, _that.user, _that.harness, _that.provider,
            _that.mode, _that.oauthAccount, _that.created, _that.updated);
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
            String harness,
            String provider,
            @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
            CredentialSelectionMode mode,
            String? oauthAccount,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CredentialSelection():
        return $default(_that.id, _that.user, _that.harness, _that.provider,
            _that.mode, _that.oauthAccount, _that.created, _that.updated);
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
            String harness,
            String provider,
            @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
            CredentialSelectionMode mode,
            String? oauthAccount,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CredentialSelection() when $default != null:
        return $default(_that.id, _that.user, _that.harness, _that.provider,
            _that.mode, _that.oauthAccount, _that.created, _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CredentialSelection implements CredentialSelection {
  const _CredentialSelection(
      {required this.id,
      required this.user,
      required this.harness,
      required this.provider,
      @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
      required this.mode,
      this.oauthAccount,
      this.created,
      this.updated});
  factory _CredentialSelection.fromJson(Map<String, dynamic> json) =>
      _$CredentialSelectionFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final String harness;
  @override
  final String provider;
  @override
  @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
  final CredentialSelectionMode mode;
  @override
  final String? oauthAccount;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of CredentialSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CredentialSelectionCopyWith<_CredentialSelection> get copyWith =>
      __$CredentialSelectionCopyWithImpl<_CredentialSelection>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CredentialSelectionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CredentialSelection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.oauthAccount, oauthAccount) ||
                other.oauthAccount == oauthAccount) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, user, harness, provider,
      mode, oauthAccount, created, updated);

  @override
  String toString() {
    return 'CredentialSelection(id: $id, user: $user, harness: $harness, provider: $provider, mode: $mode, oauthAccount: $oauthAccount, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$CredentialSelectionCopyWith<$Res>
    implements $CredentialSelectionCopyWith<$Res> {
  factory _$CredentialSelectionCopyWith(_CredentialSelection value,
          $Res Function(_CredentialSelection) _then) =
      __$CredentialSelectionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String user,
      String harness,
      String provider,
      @JsonKey(unknownEnumValue: CredentialSelectionMode.unknown)
      CredentialSelectionMode mode,
      String? oauthAccount,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$CredentialSelectionCopyWithImpl<$Res>
    implements _$CredentialSelectionCopyWith<$Res> {
  __$CredentialSelectionCopyWithImpl(this._self, this._then);

  final _CredentialSelection _self;
  final $Res Function(_CredentialSelection) _then;

  /// Create a copy of CredentialSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? harness = null,
    Object? provider = null,
    Object? mode = null,
    Object? oauthAccount = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_CredentialSelection(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as CredentialSelectionMode,
      oauthAccount: freezed == oauthAccount
          ? _self.oauthAccount
          : oauthAccount // ignore: cast_nullable_to_non_nullable
              as String?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
