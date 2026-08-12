// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'i_observability_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SystemStats {
  int get totalMessages;
  String get cumulativeCost;
  int get cumulativeTokens;
  String get backendStatus;
  List<OperationalTask> get tasks;
  List<TokenUsage> get tokenUsage;

  /// Create a copy of SystemStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SystemStatsCopyWith<SystemStats> get copyWith =>
      _$SystemStatsCopyWithImpl<SystemStats>(this as SystemStats, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SystemStats &&
            (identical(other.totalMessages, totalMessages) ||
                other.totalMessages == totalMessages) &&
            (identical(other.cumulativeCost, cumulativeCost) ||
                other.cumulativeCost == cumulativeCost) &&
            (identical(other.cumulativeTokens, cumulativeTokens) ||
                other.cumulativeTokens == cumulativeTokens) &&
            (identical(other.backendStatus, backendStatus) ||
                other.backendStatus == backendStatus) &&
            const DeepCollectionEquality().equals(other.tasks, tasks) &&
            const DeepCollectionEquality()
                .equals(other.tokenUsage, tokenUsage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalMessages,
      cumulativeCost,
      cumulativeTokens,
      backendStatus,
      const DeepCollectionEquality().hash(tasks),
      const DeepCollectionEquality().hash(tokenUsage));

  @override
  String toString() {
    return 'SystemStats(totalMessages: $totalMessages, cumulativeCost: $cumulativeCost, cumulativeTokens: $cumulativeTokens, backendStatus: $backendStatus, tasks: $tasks, tokenUsage: $tokenUsage)';
  }
}

/// @nodoc
abstract mixin class $SystemStatsCopyWith<$Res> {
  factory $SystemStatsCopyWith(
          SystemStats value, $Res Function(SystemStats) _then) =
      _$SystemStatsCopyWithImpl;
  @useResult
  $Res call(
      {int totalMessages,
      String cumulativeCost,
      int cumulativeTokens,
      String backendStatus,
      List<OperationalTask> tasks,
      List<TokenUsage> tokenUsage});
}

/// @nodoc
class _$SystemStatsCopyWithImpl<$Res> implements $SystemStatsCopyWith<$Res> {
  _$SystemStatsCopyWithImpl(this._self, this._then);

  final SystemStats _self;
  final $Res Function(SystemStats) _then;

  /// Create a copy of SystemStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalMessages = null,
    Object? cumulativeCost = null,
    Object? cumulativeTokens = null,
    Object? backendStatus = null,
    Object? tasks = null,
    Object? tokenUsage = null,
  }) {
    return _then(_self.copyWith(
      totalMessages: null == totalMessages
          ? _self.totalMessages
          : totalMessages // ignore: cast_nullable_to_non_nullable
              as int,
      cumulativeCost: null == cumulativeCost
          ? _self.cumulativeCost
          : cumulativeCost // ignore: cast_nullable_to_non_nullable
              as String,
      cumulativeTokens: null == cumulativeTokens
          ? _self.cumulativeTokens
          : cumulativeTokens // ignore: cast_nullable_to_non_nullable
              as int,
      backendStatus: null == backendStatus
          ? _self.backendStatus
          : backendStatus // ignore: cast_nullable_to_non_nullable
              as String,
      tasks: null == tasks
          ? _self.tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<OperationalTask>,
      tokenUsage: null == tokenUsage
          ? _self.tokenUsage
          : tokenUsage // ignore: cast_nullable_to_non_nullable
              as List<TokenUsage>,
    ));
  }
}

/// Adds pattern-matching-related methods to [SystemStats].
extension SystemStatsPatterns on SystemStats {
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
    TResult Function(_SystemStats value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SystemStats() when $default != null:
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
    TResult Function(_SystemStats value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SystemStats():
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
    TResult? Function(_SystemStats value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SystemStats() when $default != null:
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
            int totalMessages,
            String cumulativeCost,
            int cumulativeTokens,
            String backendStatus,
            List<OperationalTask> tasks,
            List<TokenUsage> tokenUsage)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SystemStats() when $default != null:
        return $default(
            _that.totalMessages,
            _that.cumulativeCost,
            _that.cumulativeTokens,
            _that.backendStatus,
            _that.tasks,
            _that.tokenUsage);
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
            int totalMessages,
            String cumulativeCost,
            int cumulativeTokens,
            String backendStatus,
            List<OperationalTask> tasks,
            List<TokenUsage> tokenUsage)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SystemStats():
        return $default(
            _that.totalMessages,
            _that.cumulativeCost,
            _that.cumulativeTokens,
            _that.backendStatus,
            _that.tasks,
            _that.tokenUsage);
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
            int totalMessages,
            String cumulativeCost,
            int cumulativeTokens,
            String backendStatus,
            List<OperationalTask> tasks,
            List<TokenUsage> tokenUsage)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SystemStats() when $default != null:
        return $default(
            _that.totalMessages,
            _that.cumulativeCost,
            _that.cumulativeTokens,
            _that.backendStatus,
            _that.tasks,
            _that.tokenUsage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SystemStats implements SystemStats {
  const _SystemStats(
      {this.totalMessages = 0,
      this.cumulativeCost = '\$0.00',
      this.cumulativeTokens = 0,
      this.backendStatus = 'unknown',
      final List<OperationalTask> tasks = const [],
      final List<TokenUsage> tokenUsage = const []})
      : _tasks = tasks,
        _tokenUsage = tokenUsage;

  @override
  @JsonKey()
  final int totalMessages;
  @override
  @JsonKey()
  final String cumulativeCost;
  @override
  @JsonKey()
  final int cumulativeTokens;
  @override
  @JsonKey()
  final String backendStatus;
  final List<OperationalTask> _tasks;
  @override
  @JsonKey()
  List<OperationalTask> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  final List<TokenUsage> _tokenUsage;
  @override
  @JsonKey()
  List<TokenUsage> get tokenUsage {
    if (_tokenUsage is EqualUnmodifiableListView) return _tokenUsage;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tokenUsage);
  }

  /// Create a copy of SystemStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SystemStatsCopyWith<_SystemStats> get copyWith =>
      __$SystemStatsCopyWithImpl<_SystemStats>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SystemStats &&
            (identical(other.totalMessages, totalMessages) ||
                other.totalMessages == totalMessages) &&
            (identical(other.cumulativeCost, cumulativeCost) ||
                other.cumulativeCost == cumulativeCost) &&
            (identical(other.cumulativeTokens, cumulativeTokens) ||
                other.cumulativeTokens == cumulativeTokens) &&
            (identical(other.backendStatus, backendStatus) ||
                other.backendStatus == backendStatus) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            const DeepCollectionEquality()
                .equals(other._tokenUsage, _tokenUsage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalMessages,
      cumulativeCost,
      cumulativeTokens,
      backendStatus,
      const DeepCollectionEquality().hash(_tasks),
      const DeepCollectionEquality().hash(_tokenUsage));

  @override
  String toString() {
    return 'SystemStats(totalMessages: $totalMessages, cumulativeCost: $cumulativeCost, cumulativeTokens: $cumulativeTokens, backendStatus: $backendStatus, tasks: $tasks, tokenUsage: $tokenUsage)';
  }
}

/// @nodoc
abstract mixin class _$SystemStatsCopyWith<$Res>
    implements $SystemStatsCopyWith<$Res> {
  factory _$SystemStatsCopyWith(
          _SystemStats value, $Res Function(_SystemStats) _then) =
      __$SystemStatsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int totalMessages,
      String cumulativeCost,
      int cumulativeTokens,
      String backendStatus,
      List<OperationalTask> tasks,
      List<TokenUsage> tokenUsage});
}

/// @nodoc
class __$SystemStatsCopyWithImpl<$Res> implements _$SystemStatsCopyWith<$Res> {
  __$SystemStatsCopyWithImpl(this._self, this._then);

  final _SystemStats _self;
  final $Res Function(_SystemStats) _then;

  /// Create a copy of SystemStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? totalMessages = null,
    Object? cumulativeCost = null,
    Object? cumulativeTokens = null,
    Object? backendStatus = null,
    Object? tasks = null,
    Object? tokenUsage = null,
  }) {
    return _then(_SystemStats(
      totalMessages: null == totalMessages
          ? _self.totalMessages
          : totalMessages // ignore: cast_nullable_to_non_nullable
              as int,
      cumulativeCost: null == cumulativeCost
          ? _self.cumulativeCost
          : cumulativeCost // ignore: cast_nullable_to_non_nullable
              as String,
      cumulativeTokens: null == cumulativeTokens
          ? _self.cumulativeTokens
          : cumulativeTokens // ignore: cast_nullable_to_non_nullable
              as int,
      backendStatus: null == backendStatus
          ? _self.backendStatus
          : backendStatus // ignore: cast_nullable_to_non_nullable
              as String,
      tasks: null == tasks
          ? _self._tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<OperationalTask>,
      tokenUsage: null == tokenUsage
          ? _self._tokenUsage
          : tokenUsage // ignore: cast_nullable_to_non_nullable
              as List<TokenUsage>,
    ));
  }
}

/// @nodoc
mixin _$OperationalTask {
  String get id;
  String get status;
  String get sender;
  String get receiver;
  String get summary;
  String get timestamp;

  /// Create a copy of OperationalTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OperationalTaskCopyWith<OperationalTask> get copyWith =>
      _$OperationalTaskCopyWithImpl<OperationalTask>(
          this as OperationalTask, _$identity);

  /// Serializes this OperationalTask to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OperationalTask &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.receiver, receiver) ||
                other.receiver == receiver) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, status, sender, receiver, summary, timestamp);

  @override
  String toString() {
    return 'OperationalTask(id: $id, status: $status, sender: $sender, receiver: $receiver, summary: $summary, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $OperationalTaskCopyWith<$Res> {
  factory $OperationalTaskCopyWith(
          OperationalTask value, $Res Function(OperationalTask) _then) =
      _$OperationalTaskCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String status,
      String sender,
      String receiver,
      String summary,
      String timestamp});
}

/// @nodoc
class _$OperationalTaskCopyWithImpl<$Res>
    implements $OperationalTaskCopyWith<$Res> {
  _$OperationalTaskCopyWithImpl(this._self, this._then);

  final OperationalTask _self;
  final $Res Function(OperationalTask) _then;

  /// Create a copy of OperationalTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? sender = null,
    Object? receiver = null,
    Object? summary = null,
    Object? timestamp = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _self.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as String,
      receiver: null == receiver
          ? _self.receiver
          : receiver // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [OperationalTask].
extension OperationalTaskPatterns on OperationalTask {
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
    TResult Function(_OperationalTask value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OperationalTask() when $default != null:
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
    TResult Function(_OperationalTask value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OperationalTask():
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
    TResult? Function(_OperationalTask value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OperationalTask() when $default != null:
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
    TResult Function(String id, String status, String sender, String receiver,
            String summary, String timestamp)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OperationalTask() when $default != null:
        return $default(_that.id, _that.status, _that.sender, _that.receiver,
            _that.summary, _that.timestamp);
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
    TResult Function(String id, String status, String sender, String receiver,
            String summary, String timestamp)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OperationalTask():
        return $default(_that.id, _that.status, _that.sender, _that.receiver,
            _that.summary, _that.timestamp);
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
    TResult? Function(String id, String status, String sender, String receiver,
            String summary, String timestamp)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OperationalTask() when $default != null:
        return $default(_that.id, _that.status, _that.sender, _that.receiver,
            _that.summary, _that.timestamp);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _OperationalTask implements OperationalTask {
  const _OperationalTask(
      {required this.id,
      required this.status,
      required this.sender,
      required this.receiver,
      required this.summary,
      required this.timestamp});
  factory _OperationalTask.fromJson(Map<String, dynamic> json) =>
      _$OperationalTaskFromJson(json);

  @override
  final String id;
  @override
  final String status;
  @override
  final String sender;
  @override
  final String receiver;
  @override
  final String summary;
  @override
  final String timestamp;

  /// Create a copy of OperationalTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OperationalTaskCopyWith<_OperationalTask> get copyWith =>
      __$OperationalTaskCopyWithImpl<_OperationalTask>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$OperationalTaskToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OperationalTask &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.receiver, receiver) ||
                other.receiver == receiver) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, status, sender, receiver, summary, timestamp);

  @override
  String toString() {
    return 'OperationalTask(id: $id, status: $status, sender: $sender, receiver: $receiver, summary: $summary, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class _$OperationalTaskCopyWith<$Res>
    implements $OperationalTaskCopyWith<$Res> {
  factory _$OperationalTaskCopyWith(
          _OperationalTask value, $Res Function(_OperationalTask) _then) =
      __$OperationalTaskCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String status,
      String sender,
      String receiver,
      String summary,
      String timestamp});
}

/// @nodoc
class __$OperationalTaskCopyWithImpl<$Res>
    implements _$OperationalTaskCopyWith<$Res> {
  __$OperationalTaskCopyWithImpl(this._self, this._then);

  final _OperationalTask _self;
  final $Res Function(_OperationalTask) _then;

  /// Create a copy of OperationalTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? sender = null,
    Object? receiver = null,
    Object? summary = null,
    Object? timestamp = null,
  }) {
    return _then(_OperationalTask(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _self.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as String,
      receiver: null == receiver
          ? _self.receiver
          : receiver // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$TokenUsage {
  String get model;
  int get tokens;

  /// Create a copy of TokenUsage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TokenUsageCopyWith<TokenUsage> get copyWith =>
      _$TokenUsageCopyWithImpl<TokenUsage>(this as TokenUsage, _$identity);

  /// Serializes this TokenUsage to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TokenUsage &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.tokens, tokens) || other.tokens == tokens));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, model, tokens);

  @override
  String toString() {
    return 'TokenUsage(model: $model, tokens: $tokens)';
  }
}

/// @nodoc
abstract mixin class $TokenUsageCopyWith<$Res> {
  factory $TokenUsageCopyWith(
          TokenUsage value, $Res Function(TokenUsage) _then) =
      _$TokenUsageCopyWithImpl;
  @useResult
  $Res call({String model, int tokens});
}

/// @nodoc
class _$TokenUsageCopyWithImpl<$Res> implements $TokenUsageCopyWith<$Res> {
  _$TokenUsageCopyWithImpl(this._self, this._then);

  final TokenUsage _self;
  final $Res Function(TokenUsage) _then;

  /// Create a copy of TokenUsage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
    Object? tokens = null,
  }) {
    return _then(_self.copyWith(
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      tokens: null == tokens
          ? _self.tokens
          : tokens // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [TokenUsage].
extension TokenUsagePatterns on TokenUsage {
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
    TResult Function(_TokenUsage value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TokenUsage() when $default != null:
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
    TResult Function(_TokenUsage value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TokenUsage():
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
    TResult? Function(_TokenUsage value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TokenUsage() when $default != null:
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
    TResult Function(String model, int tokens)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TokenUsage() when $default != null:
        return $default(_that.model, _that.tokens);
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
    TResult Function(String model, int tokens) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TokenUsage():
        return $default(_that.model, _that.tokens);
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
    TResult? Function(String model, int tokens)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TokenUsage() when $default != null:
        return $default(_that.model, _that.tokens);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TokenUsage implements TokenUsage {
  const _TokenUsage({required this.model, required this.tokens});
  factory _TokenUsage.fromJson(Map<String, dynamic> json) =>
      _$TokenUsageFromJson(json);

  @override
  final String model;
  @override
  final int tokens;

  /// Create a copy of TokenUsage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TokenUsageCopyWith<_TokenUsage> get copyWith =>
      __$TokenUsageCopyWithImpl<_TokenUsage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TokenUsageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TokenUsage &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.tokens, tokens) || other.tokens == tokens));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, model, tokens);

  @override
  String toString() {
    return 'TokenUsage(model: $model, tokens: $tokens)';
  }
}

/// @nodoc
abstract mixin class _$TokenUsageCopyWith<$Res>
    implements $TokenUsageCopyWith<$Res> {
  factory _$TokenUsageCopyWith(
          _TokenUsage value, $Res Function(_TokenUsage) _then) =
      __$TokenUsageCopyWithImpl;
  @override
  @useResult
  $Res call({String model, int tokens});
}

/// @nodoc
class __$TokenUsageCopyWithImpl<$Res> implements _$TokenUsageCopyWith<$Res> {
  __$TokenUsageCopyWithImpl(this._self, this._then);

  final _TokenUsage _self;
  final $Res Function(_TokenUsage) _then;

  /// Create a copy of TokenUsage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? model = null,
    Object? tokens = null,
  }) {
    return _then(_TokenUsage(
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      tokens: null == tokens
          ? _self.tokens
          : tokens // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
