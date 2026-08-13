// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_account_selection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessAccountSelection {
  String get id;
  String get user;
  String get harness;
  String get account;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of HarnessAccountSelection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessAccountSelectionCopyWith<HarnessAccountSelection> get copyWith =>
      _$HarnessAccountSelectionCopyWithImpl<HarnessAccountSelection>(
          this as HarnessAccountSelection, _$identity);

  /// Serializes this HarnessAccountSelection to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessAccountSelection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, user, harness, account, created, updated);

  @override
  String toString() {
    return 'HarnessAccountSelection(id: $id, user: $user, harness: $harness, account: $account, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $HarnessAccountSelectionCopyWith<$Res> {
  factory $HarnessAccountSelectionCopyWith(HarnessAccountSelection value,
          $Res Function(HarnessAccountSelection) _then) =
      _$HarnessAccountSelectionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String user,
      String harness,
      String account,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$HarnessAccountSelectionCopyWithImpl<$Res>
    implements $HarnessAccountSelectionCopyWith<$Res> {
  _$HarnessAccountSelectionCopyWithImpl(this._self, this._then);

  final HarnessAccountSelection _self;
  final $Res Function(HarnessAccountSelection) _then;

  /// Create a copy of HarnessAccountSelection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? harness = null,
    Object? account = null,
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
      account: null == account
          ? _self.account
          : account // ignore: cast_nullable_to_non_nullable
              as String,
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

/// Adds pattern-matching-related methods to [HarnessAccountSelection].
extension HarnessAccountSelectionPatterns on HarnessAccountSelection {
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
    TResult Function(_HarnessAccountSelection value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessAccountSelection() when $default != null:
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
    TResult Function(_HarnessAccountSelection value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccountSelection():
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
    TResult? Function(_HarnessAccountSelection value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccountSelection() when $default != null:
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
    TResult Function(String id, String user, String harness, String account,
            DateTime? created, DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessAccountSelection() when $default != null:
        return $default(_that.id, _that.user, _that.harness, _that.account,
            _that.created, _that.updated);
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
    TResult Function(String id, String user, String harness, String account,
            DateTime? created, DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccountSelection():
        return $default(_that.id, _that.user, _that.harness, _that.account,
            _that.created, _that.updated);
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
    TResult? Function(String id, String user, String harness, String account,
            DateTime? created, DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccountSelection() when $default != null:
        return $default(_that.id, _that.user, _that.harness, _that.account,
            _that.created, _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HarnessAccountSelection implements HarnessAccountSelection {
  const _HarnessAccountSelection(
      {required this.id,
      required this.user,
      required this.harness,
      required this.account,
      this.created,
      this.updated});
  factory _HarnessAccountSelection.fromJson(Map<String, dynamic> json) =>
      _$HarnessAccountSelectionFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final String harness;
  @override
  final String account;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of HarnessAccountSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessAccountSelectionCopyWith<_HarnessAccountSelection> get copyWith =>
      __$HarnessAccountSelectionCopyWithImpl<_HarnessAccountSelection>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessAccountSelectionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessAccountSelection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, user, harness, account, created, updated);

  @override
  String toString() {
    return 'HarnessAccountSelection(id: $id, user: $user, harness: $harness, account: $account, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$HarnessAccountSelectionCopyWith<$Res>
    implements $HarnessAccountSelectionCopyWith<$Res> {
  factory _$HarnessAccountSelectionCopyWith(_HarnessAccountSelection value,
          $Res Function(_HarnessAccountSelection) _then) =
      __$HarnessAccountSelectionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String user,
      String harness,
      String account,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$HarnessAccountSelectionCopyWithImpl<$Res>
    implements _$HarnessAccountSelectionCopyWith<$Res> {
  __$HarnessAccountSelectionCopyWithImpl(this._self, this._then);

  final _HarnessAccountSelection _self;
  final $Res Function(_HarnessAccountSelection) _then;

  /// Create a copy of HarnessAccountSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? harness = null,
    Object? account = null,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_HarnessAccountSelection(
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
      account: null == account
          ? _self.account
          : account // ignore: cast_nullable_to_non_nullable
              as String,
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
