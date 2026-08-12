// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'elicitation_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ElicitationResponse {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ElicitationResponse);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ElicitationResponse()';
  }
}

/// @nodoc
class $ElicitationResponseCopyWith<$Res> {
  $ElicitationResponseCopyWith(
      ElicitationResponse _, $Res Function(ElicitationResponse) __);
}

/// Adds pattern-matching-related methods to [ElicitationResponse].
extension ElicitationResponsePatterns on ElicitationResponse {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ElicitationResponseAccept value)? accept,
    TResult Function(ElicitationResponseDecline value)? decline,
    TResult Function(ElicitationResponseCancel value)? cancel,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case ElicitationResponseAccept() when accept != null:
        return accept(_that);
      case ElicitationResponseDecline() when decline != null:
        return decline(_that);
      case ElicitationResponseCancel() when cancel != null:
        return cancel(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(ElicitationResponseAccept value) accept,
    required TResult Function(ElicitationResponseDecline value) decline,
    required TResult Function(ElicitationResponseCancel value) cancel,
  }) {
    final _that = this;
    switch (_that) {
      case ElicitationResponseAccept():
        return accept(_that);
      case ElicitationResponseDecline():
        return decline(_that);
      case ElicitationResponseCancel():
        return cancel(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ElicitationResponseAccept value)? accept,
    TResult? Function(ElicitationResponseDecline value)? decline,
    TResult? Function(ElicitationResponseCancel value)? cancel,
  }) {
    final _that = this;
    switch (_that) {
      case ElicitationResponseAccept() when accept != null:
        return accept(_that);
      case ElicitationResponseDecline() when decline != null:
        return decline(_that);
      case ElicitationResponseCancel() when cancel != null:
        return cancel(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Map<String, dynamic> content)? accept,
    TResult Function()? decline,
    TResult Function()? cancel,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case ElicitationResponseAccept() when accept != null:
        return accept(_that.content);
      case ElicitationResponseDecline() when decline != null:
        return decline();
      case ElicitationResponseCancel() when cancel != null:
        return cancel();
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
  TResult when<TResult extends Object?>({
    required TResult Function(Map<String, dynamic> content) accept,
    required TResult Function() decline,
    required TResult Function() cancel,
  }) {
    final _that = this;
    switch (_that) {
      case ElicitationResponseAccept():
        return accept(_that.content);
      case ElicitationResponseDecline():
        return decline();
      case ElicitationResponseCancel():
        return cancel();
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Map<String, dynamic> content)? accept,
    TResult? Function()? decline,
    TResult? Function()? cancel,
  }) {
    final _that = this;
    switch (_that) {
      case ElicitationResponseAccept() when accept != null:
        return accept(_that.content);
      case ElicitationResponseDecline() when decline != null:
        return decline();
      case ElicitationResponseCancel() when cancel != null:
        return cancel();
      case _:
        return null;
    }
  }
}

/// @nodoc

class ElicitationResponseAccept extends ElicitationResponse {
  const ElicitationResponseAccept(final Map<String, dynamic> content)
      : _content = content,
        super._();

  final Map<String, dynamic> _content;
  Map<String, dynamic> get content {
    if (_content is EqualUnmodifiableMapView) return _content;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_content);
  }

  /// Create a copy of ElicitationResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ElicitationResponseAcceptCopyWith<ElicitationResponseAccept> get copyWith =>
      _$ElicitationResponseAcceptCopyWithImpl<ElicitationResponseAccept>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ElicitationResponseAccept &&
            const DeepCollectionEquality().equals(other._content, _content));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_content));

  @override
  String toString() {
    return 'ElicitationResponse.accept(content: $content)';
  }
}

/// @nodoc
abstract mixin class $ElicitationResponseAcceptCopyWith<$Res>
    implements $ElicitationResponseCopyWith<$Res> {
  factory $ElicitationResponseAcceptCopyWith(ElicitationResponseAccept value,
          $Res Function(ElicitationResponseAccept) _then) =
      _$ElicitationResponseAcceptCopyWithImpl;
  @useResult
  $Res call({Map<String, dynamic> content});
}

/// @nodoc
class _$ElicitationResponseAcceptCopyWithImpl<$Res>
    implements $ElicitationResponseAcceptCopyWith<$Res> {
  _$ElicitationResponseAcceptCopyWithImpl(this._self, this._then);

  final ElicitationResponseAccept _self;
  final $Res Function(ElicitationResponseAccept) _then;

  /// Create a copy of ElicitationResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? content = null,
  }) {
    return _then(ElicitationResponseAccept(
      null == content
          ? _self._content
          : content // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc

class ElicitationResponseDecline extends ElicitationResponse {
  const ElicitationResponseDecline() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ElicitationResponseDecline);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ElicitationResponse.decline()';
  }
}

/// @nodoc

class ElicitationResponseCancel extends ElicitationResponse {
  const ElicitationResponseCancel() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ElicitationResponseCancel);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ElicitationResponse.cancel()';
  }
}

// dart format on
