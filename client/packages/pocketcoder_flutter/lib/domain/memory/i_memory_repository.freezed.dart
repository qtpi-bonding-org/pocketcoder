// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'i_memory_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MemoryStats {
  int get observations;
  int get interpretations;
  int get links;
  List<MemoryAccountSummary> get byAccount;
  List<MemoryObservation> get recentObservations;
  List<MemoryInterpretation> get recentInterpretations;

  /// Create a copy of MemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MemoryStatsCopyWith<MemoryStats> get copyWith =>
      _$MemoryStatsCopyWithImpl<MemoryStats>(this as MemoryStats, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MemoryStats &&
            (identical(other.observations, observations) ||
                other.observations == observations) &&
            (identical(other.interpretations, interpretations) ||
                other.interpretations == interpretations) &&
            (identical(other.links, links) || other.links == links) &&
            const DeepCollectionEquality().equals(other.byAccount, byAccount) &&
            const DeepCollectionEquality()
                .equals(other.recentObservations, recentObservations) &&
            const DeepCollectionEquality()
                .equals(other.recentInterpretations, recentInterpretations));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      observations,
      interpretations,
      links,
      const DeepCollectionEquality().hash(byAccount),
      const DeepCollectionEquality().hash(recentObservations),
      const DeepCollectionEquality().hash(recentInterpretations));

  @override
  String toString() {
    return 'MemoryStats(observations: $observations, interpretations: $interpretations, links: $links, byAccount: $byAccount, recentObservations: $recentObservations, recentInterpretations: $recentInterpretations)';
  }
}

/// @nodoc
abstract mixin class $MemoryStatsCopyWith<$Res> {
  factory $MemoryStatsCopyWith(
          MemoryStats value, $Res Function(MemoryStats) _then) =
      _$MemoryStatsCopyWithImpl;
  @useResult
  $Res call(
      {int observations,
      int interpretations,
      int links,
      List<MemoryAccountSummary> byAccount,
      List<MemoryObservation> recentObservations,
      List<MemoryInterpretation> recentInterpretations});
}

/// @nodoc
class _$MemoryStatsCopyWithImpl<$Res> implements $MemoryStatsCopyWith<$Res> {
  _$MemoryStatsCopyWithImpl(this._self, this._then);

  final MemoryStats _self;
  final $Res Function(MemoryStats) _then;

  /// Create a copy of MemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? observations = null,
    Object? interpretations = null,
    Object? links = null,
    Object? byAccount = null,
    Object? recentObservations = null,
    Object? recentInterpretations = null,
  }) {
    return _then(_self.copyWith(
      observations: null == observations
          ? _self.observations
          : observations // ignore: cast_nullable_to_non_nullable
              as int,
      interpretations: null == interpretations
          ? _self.interpretations
          : interpretations // ignore: cast_nullable_to_non_nullable
              as int,
      links: null == links
          ? _self.links
          : links // ignore: cast_nullable_to_non_nullable
              as int,
      byAccount: null == byAccount
          ? _self.byAccount
          : byAccount // ignore: cast_nullable_to_non_nullable
              as List<MemoryAccountSummary>,
      recentObservations: null == recentObservations
          ? _self.recentObservations
          : recentObservations // ignore: cast_nullable_to_non_nullable
              as List<MemoryObservation>,
      recentInterpretations: null == recentInterpretations
          ? _self.recentInterpretations
          : recentInterpretations // ignore: cast_nullable_to_non_nullable
              as List<MemoryInterpretation>,
    ));
  }
}

/// Adds pattern-matching-related methods to [MemoryStats].
extension MemoryStatsPatterns on MemoryStats {
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
    TResult Function(_MemoryStats value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryStats() when $default != null:
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
    TResult Function(_MemoryStats value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryStats():
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
    TResult? Function(_MemoryStats value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryStats() when $default != null:
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
            int observations,
            int interpretations,
            int links,
            List<MemoryAccountSummary> byAccount,
            List<MemoryObservation> recentObservations,
            List<MemoryInterpretation> recentInterpretations)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryStats() when $default != null:
        return $default(
            _that.observations,
            _that.interpretations,
            _that.links,
            _that.byAccount,
            _that.recentObservations,
            _that.recentInterpretations);
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
            int observations,
            int interpretations,
            int links,
            List<MemoryAccountSummary> byAccount,
            List<MemoryObservation> recentObservations,
            List<MemoryInterpretation> recentInterpretations)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryStats():
        return $default(
            _that.observations,
            _that.interpretations,
            _that.links,
            _that.byAccount,
            _that.recentObservations,
            _that.recentInterpretations);
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
            int observations,
            int interpretations,
            int links,
            List<MemoryAccountSummary> byAccount,
            List<MemoryObservation> recentObservations,
            List<MemoryInterpretation> recentInterpretations)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryStats() when $default != null:
        return $default(
            _that.observations,
            _that.interpretations,
            _that.links,
            _that.byAccount,
            _that.recentObservations,
            _that.recentInterpretations);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _MemoryStats implements MemoryStats {
  const _MemoryStats(
      {this.observations = 0,
      this.interpretations = 0,
      this.links = 0,
      final List<MemoryAccountSummary> byAccount = const [],
      final List<MemoryObservation> recentObservations = const [],
      final List<MemoryInterpretation> recentInterpretations = const []})
      : _byAccount = byAccount,
        _recentObservations = recentObservations,
        _recentInterpretations = recentInterpretations;

  @override
  @JsonKey()
  final int observations;
  @override
  @JsonKey()
  final int interpretations;
  @override
  @JsonKey()
  final int links;
  final List<MemoryAccountSummary> _byAccount;
  @override
  @JsonKey()
  List<MemoryAccountSummary> get byAccount {
    if (_byAccount is EqualUnmodifiableListView) return _byAccount;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_byAccount);
  }

  final List<MemoryObservation> _recentObservations;
  @override
  @JsonKey()
  List<MemoryObservation> get recentObservations {
    if (_recentObservations is EqualUnmodifiableListView)
      return _recentObservations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentObservations);
  }

  final List<MemoryInterpretation> _recentInterpretations;
  @override
  @JsonKey()
  List<MemoryInterpretation> get recentInterpretations {
    if (_recentInterpretations is EqualUnmodifiableListView)
      return _recentInterpretations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentInterpretations);
  }

  /// Create a copy of MemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MemoryStatsCopyWith<_MemoryStats> get copyWith =>
      __$MemoryStatsCopyWithImpl<_MemoryStats>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MemoryStats &&
            (identical(other.observations, observations) ||
                other.observations == observations) &&
            (identical(other.interpretations, interpretations) ||
                other.interpretations == interpretations) &&
            (identical(other.links, links) || other.links == links) &&
            const DeepCollectionEquality()
                .equals(other._byAccount, _byAccount) &&
            const DeepCollectionEquality()
                .equals(other._recentObservations, _recentObservations) &&
            const DeepCollectionEquality()
                .equals(other._recentInterpretations, _recentInterpretations));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      observations,
      interpretations,
      links,
      const DeepCollectionEquality().hash(_byAccount),
      const DeepCollectionEquality().hash(_recentObservations),
      const DeepCollectionEquality().hash(_recentInterpretations));

  @override
  String toString() {
    return 'MemoryStats(observations: $observations, interpretations: $interpretations, links: $links, byAccount: $byAccount, recentObservations: $recentObservations, recentInterpretations: $recentInterpretations)';
  }
}

/// @nodoc
abstract mixin class _$MemoryStatsCopyWith<$Res>
    implements $MemoryStatsCopyWith<$Res> {
  factory _$MemoryStatsCopyWith(
          _MemoryStats value, $Res Function(_MemoryStats) _then) =
      __$MemoryStatsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int observations,
      int interpretations,
      int links,
      List<MemoryAccountSummary> byAccount,
      List<MemoryObservation> recentObservations,
      List<MemoryInterpretation> recentInterpretations});
}

/// @nodoc
class __$MemoryStatsCopyWithImpl<$Res> implements _$MemoryStatsCopyWith<$Res> {
  __$MemoryStatsCopyWithImpl(this._self, this._then);

  final _MemoryStats _self;
  final $Res Function(_MemoryStats) _then;

  /// Create a copy of MemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? observations = null,
    Object? interpretations = null,
    Object? links = null,
    Object? byAccount = null,
    Object? recentObservations = null,
    Object? recentInterpretations = null,
  }) {
    return _then(_MemoryStats(
      observations: null == observations
          ? _self.observations
          : observations // ignore: cast_nullable_to_non_nullable
              as int,
      interpretations: null == interpretations
          ? _self.interpretations
          : interpretations // ignore: cast_nullable_to_non_nullable
              as int,
      links: null == links
          ? _self.links
          : links // ignore: cast_nullable_to_non_nullable
              as int,
      byAccount: null == byAccount
          ? _self._byAccount
          : byAccount // ignore: cast_nullable_to_non_nullable
              as List<MemoryAccountSummary>,
      recentObservations: null == recentObservations
          ? _self._recentObservations
          : recentObservations // ignore: cast_nullable_to_non_nullable
              as List<MemoryObservation>,
      recentInterpretations: null == recentInterpretations
          ? _self._recentInterpretations
          : recentInterpretations // ignore: cast_nullable_to_non_nullable
              as List<MemoryInterpretation>,
    ));
  }
}

/// @nodoc
mixin _$MemoryAccountSummary {
  String get accountId;
  String get agentProfileId;
  String get agentName;
  int get observations;
  int get interpretations;

  /// Create a copy of MemoryAccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MemoryAccountSummaryCopyWith<MemoryAccountSummary> get copyWith =>
      _$MemoryAccountSummaryCopyWithImpl<MemoryAccountSummary>(
          this as MemoryAccountSummary, _$identity);

  /// Serializes this MemoryAccountSummary to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MemoryAccountSummary &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.agentProfileId, agentProfileId) ||
                other.agentProfileId == agentProfileId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.observations, observations) ||
                other.observations == observations) &&
            (identical(other.interpretations, interpretations) ||
                other.interpretations == interpretations));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, accountId, agentProfileId,
      agentName, observations, interpretations);

  @override
  String toString() {
    return 'MemoryAccountSummary(accountId: $accountId, agentProfileId: $agentProfileId, agentName: $agentName, observations: $observations, interpretations: $interpretations)';
  }
}

/// @nodoc
abstract mixin class $MemoryAccountSummaryCopyWith<$Res> {
  factory $MemoryAccountSummaryCopyWith(MemoryAccountSummary value,
          $Res Function(MemoryAccountSummary) _then) =
      _$MemoryAccountSummaryCopyWithImpl;
  @useResult
  $Res call(
      {String accountId,
      String agentProfileId,
      String agentName,
      int observations,
      int interpretations});
}

/// @nodoc
class _$MemoryAccountSummaryCopyWithImpl<$Res>
    implements $MemoryAccountSummaryCopyWith<$Res> {
  _$MemoryAccountSummaryCopyWithImpl(this._self, this._then);

  final MemoryAccountSummary _self;
  final $Res Function(MemoryAccountSummary) _then;

  /// Create a copy of MemoryAccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accountId = null,
    Object? agentProfileId = null,
    Object? agentName = null,
    Object? observations = null,
    Object? interpretations = null,
  }) {
    return _then(_self.copyWith(
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      agentProfileId: null == agentProfileId
          ? _self.agentProfileId
          : agentProfileId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: null == agentName
          ? _self.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String,
      observations: null == observations
          ? _self.observations
          : observations // ignore: cast_nullable_to_non_nullable
              as int,
      interpretations: null == interpretations
          ? _self.interpretations
          : interpretations // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [MemoryAccountSummary].
extension MemoryAccountSummaryPatterns on MemoryAccountSummary {
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
    TResult Function(_MemoryAccountSummary value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryAccountSummary() when $default != null:
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
    TResult Function(_MemoryAccountSummary value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryAccountSummary():
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
    TResult? Function(_MemoryAccountSummary value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryAccountSummary() when $default != null:
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
    TResult Function(String accountId, String agentProfileId, String agentName,
            int observations, int interpretations)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryAccountSummary() when $default != null:
        return $default(_that.accountId, _that.agentProfileId, _that.agentName,
            _that.observations, _that.interpretations);
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
    TResult Function(String accountId, String agentProfileId, String agentName,
            int observations, int interpretations)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryAccountSummary():
        return $default(_that.accountId, _that.agentProfileId, _that.agentName,
            _that.observations, _that.interpretations);
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
    TResult? Function(String accountId, String agentProfileId, String agentName,
            int observations, int interpretations)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryAccountSummary() when $default != null:
        return $default(_that.accountId, _that.agentProfileId, _that.agentName,
            _that.observations, _that.interpretations);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MemoryAccountSummary implements MemoryAccountSummary {
  const _MemoryAccountSummary(
      {required this.accountId,
      required this.agentProfileId,
      required this.agentName,
      this.observations = 0,
      this.interpretations = 0});
  factory _MemoryAccountSummary.fromJson(Map<String, dynamic> json) =>
      _$MemoryAccountSummaryFromJson(json);

  @override
  final String accountId;
  @override
  final String agentProfileId;
  @override
  final String agentName;
  @override
  @JsonKey()
  final int observations;
  @override
  @JsonKey()
  final int interpretations;

  /// Create a copy of MemoryAccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MemoryAccountSummaryCopyWith<_MemoryAccountSummary> get copyWith =>
      __$MemoryAccountSummaryCopyWithImpl<_MemoryAccountSummary>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MemoryAccountSummaryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MemoryAccountSummary &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.agentProfileId, agentProfileId) ||
                other.agentProfileId == agentProfileId) &&
            (identical(other.agentName, agentName) ||
                other.agentName == agentName) &&
            (identical(other.observations, observations) ||
                other.observations == observations) &&
            (identical(other.interpretations, interpretations) ||
                other.interpretations == interpretations));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, accountId, agentProfileId,
      agentName, observations, interpretations);

  @override
  String toString() {
    return 'MemoryAccountSummary(accountId: $accountId, agentProfileId: $agentProfileId, agentName: $agentName, observations: $observations, interpretations: $interpretations)';
  }
}

/// @nodoc
abstract mixin class _$MemoryAccountSummaryCopyWith<$Res>
    implements $MemoryAccountSummaryCopyWith<$Res> {
  factory _$MemoryAccountSummaryCopyWith(_MemoryAccountSummary value,
          $Res Function(_MemoryAccountSummary) _then) =
      __$MemoryAccountSummaryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String accountId,
      String agentProfileId,
      String agentName,
      int observations,
      int interpretations});
}

/// @nodoc
class __$MemoryAccountSummaryCopyWithImpl<$Res>
    implements _$MemoryAccountSummaryCopyWith<$Res> {
  __$MemoryAccountSummaryCopyWithImpl(this._self, this._then);

  final _MemoryAccountSummary _self;
  final $Res Function(_MemoryAccountSummary) _then;

  /// Create a copy of MemoryAccountSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? accountId = null,
    Object? agentProfileId = null,
    Object? agentName = null,
    Object? observations = null,
    Object? interpretations = null,
  }) {
    return _then(_MemoryAccountSummary(
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      agentProfileId: null == agentProfileId
          ? _self.agentProfileId
          : agentProfileId // ignore: cast_nullable_to_non_nullable
              as String,
      agentName: null == agentName
          ? _self.agentName
          : agentName // ignore: cast_nullable_to_non_nullable
              as String,
      observations: null == observations
          ? _self.observations
          : observations // ignore: cast_nullable_to_non_nullable
              as int,
      interpretations: null == interpretations
          ? _self.interpretations
          : interpretations // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$MemoryObservation {
  String get id;
  String get accountId;
  String get author;
  String get body;
  String get createdAt;
  String get updatedAt;
  String get retrievedAt;

  /// Create a copy of MemoryObservation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MemoryObservationCopyWith<MemoryObservation> get copyWith =>
      _$MemoryObservationCopyWithImpl<MemoryObservation>(
          this as MemoryObservation, _$identity);

  /// Serializes this MemoryObservation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MemoryObservation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.retrievedAt, retrievedAt) ||
                other.retrievedAt == retrievedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, accountId, author, body,
      createdAt, updatedAt, retrievedAt);

  @override
  String toString() {
    return 'MemoryObservation(id: $id, accountId: $accountId, author: $author, body: $body, createdAt: $createdAt, updatedAt: $updatedAt, retrievedAt: $retrievedAt)';
  }
}

/// @nodoc
abstract mixin class $MemoryObservationCopyWith<$Res> {
  factory $MemoryObservationCopyWith(
          MemoryObservation value, $Res Function(MemoryObservation) _then) =
      _$MemoryObservationCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String accountId,
      String author,
      String body,
      String createdAt,
      String updatedAt,
      String retrievedAt});
}

/// @nodoc
class _$MemoryObservationCopyWithImpl<$Res>
    implements $MemoryObservationCopyWith<$Res> {
  _$MemoryObservationCopyWithImpl(this._self, this._then);

  final MemoryObservation _self;
  final $Res Function(MemoryObservation) _then;

  /// Create a copy of MemoryObservation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? accountId = null,
    Object? author = null,
    Object? body = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? retrievedAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      retrievedAt: null == retrievedAt
          ? _self.retrievedAt
          : retrievedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MemoryObservation].
extension MemoryObservationPatterns on MemoryObservation {
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
    TResult Function(_MemoryObservation value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryObservation() when $default != null:
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
    TResult Function(_MemoryObservation value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryObservation():
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
    TResult? Function(_MemoryObservation value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryObservation() when $default != null:
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
    TResult Function(String id, String accountId, String author, String body,
            String createdAt, String updatedAt, String retrievedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryObservation() when $default != null:
        return $default(_that.id, _that.accountId, _that.author, _that.body,
            _that.createdAt, _that.updatedAt, _that.retrievedAt);
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
    TResult Function(String id, String accountId, String author, String body,
            String createdAt, String updatedAt, String retrievedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryObservation():
        return $default(_that.id, _that.accountId, _that.author, _that.body,
            _that.createdAt, _that.updatedAt, _that.retrievedAt);
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
    TResult? Function(String id, String accountId, String author, String body,
            String createdAt, String updatedAt, String retrievedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryObservation() when $default != null:
        return $default(_that.id, _that.accountId, _that.author, _that.body,
            _that.createdAt, _that.updatedAt, _that.retrievedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MemoryObservation implements MemoryObservation {
  const _MemoryObservation(
      {required this.id,
      required this.accountId,
      required this.author,
      required this.body,
      required this.createdAt,
      required this.updatedAt,
      required this.retrievedAt});
  factory _MemoryObservation.fromJson(Map<String, dynamic> json) =>
      _$MemoryObservationFromJson(json);

  @override
  final String id;
  @override
  final String accountId;
  @override
  final String author;
  @override
  final String body;
  @override
  final String createdAt;
  @override
  final String updatedAt;
  @override
  final String retrievedAt;

  /// Create a copy of MemoryObservation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MemoryObservationCopyWith<_MemoryObservation> get copyWith =>
      __$MemoryObservationCopyWithImpl<_MemoryObservation>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MemoryObservationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MemoryObservation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.retrievedAt, retrievedAt) ||
                other.retrievedAt == retrievedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, accountId, author, body,
      createdAt, updatedAt, retrievedAt);

  @override
  String toString() {
    return 'MemoryObservation(id: $id, accountId: $accountId, author: $author, body: $body, createdAt: $createdAt, updatedAt: $updatedAt, retrievedAt: $retrievedAt)';
  }
}

/// @nodoc
abstract mixin class _$MemoryObservationCopyWith<$Res>
    implements $MemoryObservationCopyWith<$Res> {
  factory _$MemoryObservationCopyWith(
          _MemoryObservation value, $Res Function(_MemoryObservation) _then) =
      __$MemoryObservationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String accountId,
      String author,
      String body,
      String createdAt,
      String updatedAt,
      String retrievedAt});
}

/// @nodoc
class __$MemoryObservationCopyWithImpl<$Res>
    implements _$MemoryObservationCopyWith<$Res> {
  __$MemoryObservationCopyWithImpl(this._self, this._then);

  final _MemoryObservation _self;
  final $Res Function(_MemoryObservation) _then;

  /// Create a copy of MemoryObservation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? accountId = null,
    Object? author = null,
    Object? body = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? retrievedAt = null,
  }) {
    return _then(_MemoryObservation(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      retrievedAt: null == retrievedAt
          ? _self.retrievedAt
          : retrievedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$MemoryInterpretation {
  String get id;
  String get accountId;
  String get author;
  String get body;
  String get createdAt;
  String get updatedAt;
  String get retrievedAt;
  List<String> get linkedObservations;

  /// Create a copy of MemoryInterpretation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MemoryInterpretationCopyWith<MemoryInterpretation> get copyWith =>
      _$MemoryInterpretationCopyWithImpl<MemoryInterpretation>(
          this as MemoryInterpretation, _$identity);

  /// Serializes this MemoryInterpretation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MemoryInterpretation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.retrievedAt, retrievedAt) ||
                other.retrievedAt == retrievedAt) &&
            const DeepCollectionEquality()
                .equals(other.linkedObservations, linkedObservations));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      accountId,
      author,
      body,
      createdAt,
      updatedAt,
      retrievedAt,
      const DeepCollectionEquality().hash(linkedObservations));

  @override
  String toString() {
    return 'MemoryInterpretation(id: $id, accountId: $accountId, author: $author, body: $body, createdAt: $createdAt, updatedAt: $updatedAt, retrievedAt: $retrievedAt, linkedObservations: $linkedObservations)';
  }
}

/// @nodoc
abstract mixin class $MemoryInterpretationCopyWith<$Res> {
  factory $MemoryInterpretationCopyWith(MemoryInterpretation value,
          $Res Function(MemoryInterpretation) _then) =
      _$MemoryInterpretationCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String accountId,
      String author,
      String body,
      String createdAt,
      String updatedAt,
      String retrievedAt,
      List<String> linkedObservations});
}

/// @nodoc
class _$MemoryInterpretationCopyWithImpl<$Res>
    implements $MemoryInterpretationCopyWith<$Res> {
  _$MemoryInterpretationCopyWithImpl(this._self, this._then);

  final MemoryInterpretation _self;
  final $Res Function(MemoryInterpretation) _then;

  /// Create a copy of MemoryInterpretation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? accountId = null,
    Object? author = null,
    Object? body = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? retrievedAt = null,
    Object? linkedObservations = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      retrievedAt: null == retrievedAt
          ? _self.retrievedAt
          : retrievedAt // ignore: cast_nullable_to_non_nullable
              as String,
      linkedObservations: null == linkedObservations
          ? _self.linkedObservations
          : linkedObservations // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [MemoryInterpretation].
extension MemoryInterpretationPatterns on MemoryInterpretation {
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
    TResult Function(_MemoryInterpretation value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryInterpretation() when $default != null:
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
    TResult Function(_MemoryInterpretation value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryInterpretation():
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
    TResult? Function(_MemoryInterpretation value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryInterpretation() when $default != null:
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
            String accountId,
            String author,
            String body,
            String createdAt,
            String updatedAt,
            String retrievedAt,
            List<String> linkedObservations)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryInterpretation() when $default != null:
        return $default(
            _that.id,
            _that.accountId,
            _that.author,
            _that.body,
            _that.createdAt,
            _that.updatedAt,
            _that.retrievedAt,
            _that.linkedObservations);
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
            String accountId,
            String author,
            String body,
            String createdAt,
            String updatedAt,
            String retrievedAt,
            List<String> linkedObservations)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryInterpretation():
        return $default(
            _that.id,
            _that.accountId,
            _that.author,
            _that.body,
            _that.createdAt,
            _that.updatedAt,
            _that.retrievedAt,
            _that.linkedObservations);
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
            String accountId,
            String author,
            String body,
            String createdAt,
            String updatedAt,
            String retrievedAt,
            List<String> linkedObservations)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryInterpretation() when $default != null:
        return $default(
            _that.id,
            _that.accountId,
            _that.author,
            _that.body,
            _that.createdAt,
            _that.updatedAt,
            _that.retrievedAt,
            _that.linkedObservations);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MemoryInterpretation implements MemoryInterpretation {
  const _MemoryInterpretation(
      {required this.id,
      required this.accountId,
      required this.author,
      required this.body,
      required this.createdAt,
      required this.updatedAt,
      required this.retrievedAt,
      final List<String> linkedObservations = const []})
      : _linkedObservations = linkedObservations;
  factory _MemoryInterpretation.fromJson(Map<String, dynamic> json) =>
      _$MemoryInterpretationFromJson(json);

  @override
  final String id;
  @override
  final String accountId;
  @override
  final String author;
  @override
  final String body;
  @override
  final String createdAt;
  @override
  final String updatedAt;
  @override
  final String retrievedAt;
  final List<String> _linkedObservations;
  @override
  @JsonKey()
  List<String> get linkedObservations {
    if (_linkedObservations is EqualUnmodifiableListView)
      return _linkedObservations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_linkedObservations);
  }

  /// Create a copy of MemoryInterpretation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MemoryInterpretationCopyWith<_MemoryInterpretation> get copyWith =>
      __$MemoryInterpretationCopyWithImpl<_MemoryInterpretation>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MemoryInterpretationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MemoryInterpretation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.accountId, accountId) ||
                other.accountId == accountId) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.retrievedAt, retrievedAt) ||
                other.retrievedAt == retrievedAt) &&
            const DeepCollectionEquality()
                .equals(other._linkedObservations, _linkedObservations));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      accountId,
      author,
      body,
      createdAt,
      updatedAt,
      retrievedAt,
      const DeepCollectionEquality().hash(_linkedObservations));

  @override
  String toString() {
    return 'MemoryInterpretation(id: $id, accountId: $accountId, author: $author, body: $body, createdAt: $createdAt, updatedAt: $updatedAt, retrievedAt: $retrievedAt, linkedObservations: $linkedObservations)';
  }
}

/// @nodoc
abstract mixin class _$MemoryInterpretationCopyWith<$Res>
    implements $MemoryInterpretationCopyWith<$Res> {
  factory _$MemoryInterpretationCopyWith(_MemoryInterpretation value,
          $Res Function(_MemoryInterpretation) _then) =
      __$MemoryInterpretationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String accountId,
      String author,
      String body,
      String createdAt,
      String updatedAt,
      String retrievedAt,
      List<String> linkedObservations});
}

/// @nodoc
class __$MemoryInterpretationCopyWithImpl<$Res>
    implements _$MemoryInterpretationCopyWith<$Res> {
  __$MemoryInterpretationCopyWithImpl(this._self, this._then);

  final _MemoryInterpretation _self;
  final $Res Function(_MemoryInterpretation) _then;

  /// Create a copy of MemoryInterpretation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? accountId = null,
    Object? author = null,
    Object? body = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? retrievedAt = null,
    Object? linkedObservations = null,
  }) {
    return _then(_MemoryInterpretation(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      accountId: null == accountId
          ? _self.accountId
          : accountId // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      retrievedAt: null == retrievedAt
          ? _self.retrievedAt
          : retrievedAt // ignore: cast_nullable_to_non_nullable
              as String,
      linkedObservations: null == linkedObservations
          ? _self._linkedObservations
          : linkedObservations // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
