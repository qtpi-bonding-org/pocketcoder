// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'poco_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PocoState {
  String get message;
  List<(String, int)> get sequence;
  List<String> get history;

  /// Create a copy of PocoState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PocoStateCopyWith<PocoState> get copyWith =>
      _$PocoStateCopyWithImpl<PocoState>(this as PocoState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PocoState &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other.sequence, sequence) &&
            const DeepCollectionEquality().equals(other.history, history));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      message,
      const DeepCollectionEquality().hash(sequence),
      const DeepCollectionEquality().hash(history));

  @override
  String toString() {
    return 'PocoState(message: $message, sequence: $sequence, history: $history)';
  }
}

/// @nodoc
abstract mixin class $PocoStateCopyWith<$Res> {
  factory $PocoStateCopyWith(PocoState value, $Res Function(PocoState) _then) =
      _$PocoStateCopyWithImpl;
  @useResult
  $Res call(
      {String message, List<(String, int)> sequence, List<String> history});
}

/// @nodoc
class _$PocoStateCopyWithImpl<$Res> implements $PocoStateCopyWith<$Res> {
  _$PocoStateCopyWithImpl(this._self, this._then);

  final PocoState _self;
  final $Res Function(PocoState) _then;

  /// Create a copy of PocoState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? sequence = null,
    Object? history = null,
  }) {
    return _then(_self.copyWith(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      sequence: null == sequence
          ? _self.sequence
          : sequence // ignore: cast_nullable_to_non_nullable
              as List<(String, int)>,
      history: null == history
          ? _self.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PocoState].
extension PocoStatePatterns on PocoState {
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
    TResult Function(_PocoState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocoState() when $default != null:
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
    TResult Function(_PocoState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoState():
        return $default(_that);
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
    TResult? Function(_PocoState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoState() when $default != null:
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
            String message, List<(String, int)> sequence, List<String> history)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocoState() when $default != null:
        return $default(_that.message, _that.sequence, _that.history);
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
            String message, List<(String, int)> sequence, List<String> history)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoState():
        return $default(_that.message, _that.sequence, _that.history);
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
            String message, List<(String, int)> sequence, List<String> history)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoState() when $default != null:
        return $default(_that.message, _that.sequence, _that.history);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PocoState implements PocoState {
  const _PocoState(
      {required this.message,
      required final List<(String, int)> sequence,
      final List<String> history = const []})
      : _sequence = sequence,
        _history = history;

  @override
  final String message;
  final List<(String, int)> _sequence;
  @override
  List<(String, int)> get sequence {
    if (_sequence is EqualUnmodifiableListView) return _sequence;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sequence);
  }

  final List<String> _history;
  @override
  @JsonKey()
  List<String> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  /// Create a copy of PocoState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PocoStateCopyWith<_PocoState> get copyWith =>
      __$PocoStateCopyWithImpl<_PocoState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PocoState &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._sequence, _sequence) &&
            const DeepCollectionEquality().equals(other._history, _history));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      message,
      const DeepCollectionEquality().hash(_sequence),
      const DeepCollectionEquality().hash(_history));

  @override
  String toString() {
    return 'PocoState(message: $message, sequence: $sequence, history: $history)';
  }
}

/// @nodoc
abstract mixin class _$PocoStateCopyWith<$Res>
    implements $PocoStateCopyWith<$Res> {
  factory _$PocoStateCopyWith(
          _PocoState value, $Res Function(_PocoState) _then) =
      __$PocoStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String message, List<(String, int)> sequence, List<String> history});
}

/// @nodoc
class __$PocoStateCopyWithImpl<$Res> implements _$PocoStateCopyWith<$Res> {
  __$PocoStateCopyWithImpl(this._self, this._then);

  final _PocoState _self;
  final $Res Function(_PocoState) _then;

  /// Create a copy of PocoState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? message = null,
    Object? sequence = null,
    Object? history = null,
  }) {
    return _then(_PocoState(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      sequence: null == sequence
          ? _self._sequence
          : sequence // ignore: cast_nullable_to_non_nullable
              as List<(String, int)>,
      history: null == history
          ? _self._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
