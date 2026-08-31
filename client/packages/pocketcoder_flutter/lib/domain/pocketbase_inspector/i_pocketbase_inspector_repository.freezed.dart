// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'i_pocketbase_inspector_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PocketbaseInspectorStats {
  int get users;
  int get chats;
  int get agentProfiles;
  int get harnesses;
  int get mcpServers;
  int get skills;
  List<PocketbaseChatSummary> get recentChats;

  /// Create a copy of PocketbaseInspectorStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PocketbaseInspectorStatsCopyWith<PocketbaseInspectorStats> get copyWith =>
      _$PocketbaseInspectorStatsCopyWithImpl<PocketbaseInspectorStats>(
          this as PocketbaseInspectorStats, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PocketbaseInspectorStats &&
            (identical(other.users, users) || other.users == users) &&
            (identical(other.chats, chats) || other.chats == chats) &&
            (identical(other.agentProfiles, agentProfiles) ||
                other.agentProfiles == agentProfiles) &&
            (identical(other.harnesses, harnesses) ||
                other.harnesses == harnesses) &&
            (identical(other.mcpServers, mcpServers) ||
                other.mcpServers == mcpServers) &&
            (identical(other.skills, skills) || other.skills == skills) &&
            const DeepCollectionEquality()
                .equals(other.recentChats, recentChats));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      users,
      chats,
      agentProfiles,
      harnesses,
      mcpServers,
      skills,
      const DeepCollectionEquality().hash(recentChats));

  @override
  String toString() {
    return 'PocketbaseInspectorStats(users: $users, chats: $chats, agentProfiles: $agentProfiles, harnesses: $harnesses, mcpServers: $mcpServers, skills: $skills, recentChats: $recentChats)';
  }
}

/// @nodoc
abstract mixin class $PocketbaseInspectorStatsCopyWith<$Res> {
  factory $PocketbaseInspectorStatsCopyWith(PocketbaseInspectorStats value,
          $Res Function(PocketbaseInspectorStats) _then) =
      _$PocketbaseInspectorStatsCopyWithImpl;
  @useResult
  $Res call(
      {int users,
      int chats,
      int agentProfiles,
      int harnesses,
      int mcpServers,
      int skills,
      List<PocketbaseChatSummary> recentChats});
}

/// @nodoc
class _$PocketbaseInspectorStatsCopyWithImpl<$Res>
    implements $PocketbaseInspectorStatsCopyWith<$Res> {
  _$PocketbaseInspectorStatsCopyWithImpl(this._self, this._then);

  final PocketbaseInspectorStats _self;
  final $Res Function(PocketbaseInspectorStats) _then;

  /// Create a copy of PocketbaseInspectorStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? users = null,
    Object? chats = null,
    Object? agentProfiles = null,
    Object? harnesses = null,
    Object? mcpServers = null,
    Object? skills = null,
    Object? recentChats = null,
  }) {
    return _then(_self.copyWith(
      users: null == users
          ? _self.users
          : users // ignore: cast_nullable_to_non_nullable
              as int,
      chats: null == chats
          ? _self.chats
          : chats // ignore: cast_nullable_to_non_nullable
              as int,
      agentProfiles: null == agentProfiles
          ? _self.agentProfiles
          : agentProfiles // ignore: cast_nullable_to_non_nullable
              as int,
      harnesses: null == harnesses
          ? _self.harnesses
          : harnesses // ignore: cast_nullable_to_non_nullable
              as int,
      mcpServers: null == mcpServers
          ? _self.mcpServers
          : mcpServers // ignore: cast_nullable_to_non_nullable
              as int,
      skills: null == skills
          ? _self.skills
          : skills // ignore: cast_nullable_to_non_nullable
              as int,
      recentChats: null == recentChats
          ? _self.recentChats
          : recentChats // ignore: cast_nullable_to_non_nullable
              as List<PocketbaseChatSummary>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PocketbaseInspectorStats].
extension PocketbaseInspectorStatsPatterns on PocketbaseInspectorStats {
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
    TResult Function(_PocketbaseInspectorStats value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorStats() when $default != null:
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
    TResult Function(_PocketbaseInspectorStats value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorStats():
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
    TResult? Function(_PocketbaseInspectorStats value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorStats() when $default != null:
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
            int users,
            int chats,
            int agentProfiles,
            int harnesses,
            int mcpServers,
            int skills,
            List<PocketbaseChatSummary> recentChats)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorStats() when $default != null:
        return $default(_that.users, _that.chats, _that.agentProfiles,
            _that.harnesses, _that.mcpServers, _that.skills, _that.recentChats);
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
    TResult Function(int users, int chats, int agentProfiles, int harnesses,
            int mcpServers, int skills, List<PocketbaseChatSummary> recentChats)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorStats():
        return $default(_that.users, _that.chats, _that.agentProfiles,
            _that.harnesses, _that.mcpServers, _that.skills, _that.recentChats);
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
            int users,
            int chats,
            int agentProfiles,
            int harnesses,
            int mcpServers,
            int skills,
            List<PocketbaseChatSummary> recentChats)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorStats() when $default != null:
        return $default(_that.users, _that.chats, _that.agentProfiles,
            _that.harnesses, _that.mcpServers, _that.skills, _that.recentChats);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PocketbaseInspectorStats implements PocketbaseInspectorStats {
  const _PocketbaseInspectorStats(
      {this.users = 0,
      this.chats = 0,
      this.agentProfiles = 0,
      this.harnesses = 0,
      this.mcpServers = 0,
      this.skills = 0,
      final List<PocketbaseChatSummary> recentChats = const []})
      : _recentChats = recentChats;

  @override
  @JsonKey()
  final int users;
  @override
  @JsonKey()
  final int chats;
  @override
  @JsonKey()
  final int agentProfiles;
  @override
  @JsonKey()
  final int harnesses;
  @override
  @JsonKey()
  final int mcpServers;
  @override
  @JsonKey()
  final int skills;
  final List<PocketbaseChatSummary> _recentChats;
  @override
  @JsonKey()
  List<PocketbaseChatSummary> get recentChats {
    if (_recentChats is EqualUnmodifiableListView) return _recentChats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentChats);
  }

  /// Create a copy of PocketbaseInspectorStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PocketbaseInspectorStatsCopyWith<_PocketbaseInspectorStats> get copyWith =>
      __$PocketbaseInspectorStatsCopyWithImpl<_PocketbaseInspectorStats>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PocketbaseInspectorStats &&
            (identical(other.users, users) || other.users == users) &&
            (identical(other.chats, chats) || other.chats == chats) &&
            (identical(other.agentProfiles, agentProfiles) ||
                other.agentProfiles == agentProfiles) &&
            (identical(other.harnesses, harnesses) ||
                other.harnesses == harnesses) &&
            (identical(other.mcpServers, mcpServers) ||
                other.mcpServers == mcpServers) &&
            (identical(other.skills, skills) || other.skills == skills) &&
            const DeepCollectionEquality()
                .equals(other._recentChats, _recentChats));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      users,
      chats,
      agentProfiles,
      harnesses,
      mcpServers,
      skills,
      const DeepCollectionEquality().hash(_recentChats));

  @override
  String toString() {
    return 'PocketbaseInspectorStats(users: $users, chats: $chats, agentProfiles: $agentProfiles, harnesses: $harnesses, mcpServers: $mcpServers, skills: $skills, recentChats: $recentChats)';
  }
}

/// @nodoc
abstract mixin class _$PocketbaseInspectorStatsCopyWith<$Res>
    implements $PocketbaseInspectorStatsCopyWith<$Res> {
  factory _$PocketbaseInspectorStatsCopyWith(_PocketbaseInspectorStats value,
          $Res Function(_PocketbaseInspectorStats) _then) =
      __$PocketbaseInspectorStatsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int users,
      int chats,
      int agentProfiles,
      int harnesses,
      int mcpServers,
      int skills,
      List<PocketbaseChatSummary> recentChats});
}

/// @nodoc
class __$PocketbaseInspectorStatsCopyWithImpl<$Res>
    implements _$PocketbaseInspectorStatsCopyWith<$Res> {
  __$PocketbaseInspectorStatsCopyWithImpl(this._self, this._then);

  final _PocketbaseInspectorStats _self;
  final $Res Function(_PocketbaseInspectorStats) _then;

  /// Create a copy of PocketbaseInspectorStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? users = null,
    Object? chats = null,
    Object? agentProfiles = null,
    Object? harnesses = null,
    Object? mcpServers = null,
    Object? skills = null,
    Object? recentChats = null,
  }) {
    return _then(_PocketbaseInspectorStats(
      users: null == users
          ? _self.users
          : users // ignore: cast_nullable_to_non_nullable
              as int,
      chats: null == chats
          ? _self.chats
          : chats // ignore: cast_nullable_to_non_nullable
              as int,
      agentProfiles: null == agentProfiles
          ? _self.agentProfiles
          : agentProfiles // ignore: cast_nullable_to_non_nullable
              as int,
      harnesses: null == harnesses
          ? _self.harnesses
          : harnesses // ignore: cast_nullable_to_non_nullable
              as int,
      mcpServers: null == mcpServers
          ? _self.mcpServers
          : mcpServers // ignore: cast_nullable_to_non_nullable
              as int,
      skills: null == skills
          ? _self.skills
          : skills // ignore: cast_nullable_to_non_nullable
              as int,
      recentChats: null == recentChats
          ? _self._recentChats
          : recentChats // ignore: cast_nullable_to_non_nullable
              as List<PocketbaseChatSummary>,
    ));
  }
}

/// @nodoc
mixin _$PocketbaseChatSummary {
  String get id;
  String get title;
  String get turn;
  bool get archived;
  String get createdAt;
  String get lastActive;

  /// Create a copy of PocketbaseChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PocketbaseChatSummaryCopyWith<PocketbaseChatSummary> get copyWith =>
      _$PocketbaseChatSummaryCopyWithImpl<PocketbaseChatSummary>(
          this as PocketbaseChatSummary, _$identity);

  /// Serializes this PocketbaseChatSummary to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PocketbaseChatSummary &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.turn, turn) || other.turn == turn) &&
            (identical(other.archived, archived) ||
                other.archived == archived) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastActive, lastActive) ||
                other.lastActive == lastActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, title, turn, archived, createdAt, lastActive);

  @override
  String toString() {
    return 'PocketbaseChatSummary(id: $id, title: $title, turn: $turn, archived: $archived, createdAt: $createdAt, lastActive: $lastActive)';
  }
}

/// @nodoc
abstract mixin class $PocketbaseChatSummaryCopyWith<$Res> {
  factory $PocketbaseChatSummaryCopyWith(PocketbaseChatSummary value,
          $Res Function(PocketbaseChatSummary) _then) =
      _$PocketbaseChatSummaryCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String turn,
      bool archived,
      String createdAt,
      String lastActive});
}

/// @nodoc
class _$PocketbaseChatSummaryCopyWithImpl<$Res>
    implements $PocketbaseChatSummaryCopyWith<$Res> {
  _$PocketbaseChatSummaryCopyWithImpl(this._self, this._then);

  final PocketbaseChatSummary _self;
  final $Res Function(PocketbaseChatSummary) _then;

  /// Create a copy of PocketbaseChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? turn = null,
    Object? archived = null,
    Object? createdAt = null,
    Object? lastActive = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      turn: null == turn
          ? _self.turn
          : turn // ignore: cast_nullable_to_non_nullable
              as String,
      archived: null == archived
          ? _self.archived
          : archived // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      lastActive: null == lastActive
          ? _self.lastActive
          : lastActive // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [PocketbaseChatSummary].
extension PocketbaseChatSummaryPatterns on PocketbaseChatSummary {
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
    TResult Function(_PocketbaseChatSummary value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketbaseChatSummary() when $default != null:
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
    TResult Function(_PocketbaseChatSummary value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseChatSummary():
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
    TResult? Function(_PocketbaseChatSummary value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseChatSummary() when $default != null:
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
    TResult Function(String id, String title, String turn, bool archived,
            String createdAt, String lastActive)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketbaseChatSummary() when $default != null:
        return $default(_that.id, _that.title, _that.turn, _that.archived,
            _that.createdAt, _that.lastActive);
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
    TResult Function(String id, String title, String turn, bool archived,
            String createdAt, String lastActive)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseChatSummary():
        return $default(_that.id, _that.title, _that.turn, _that.archived,
            _that.createdAt, _that.lastActive);
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
    TResult? Function(String id, String title, String turn, bool archived,
            String createdAt, String lastActive)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseChatSummary() when $default != null:
        return $default(_that.id, _that.title, _that.turn, _that.archived,
            _that.createdAt, _that.lastActive);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PocketbaseChatSummary implements PocketbaseChatSummary {
  const _PocketbaseChatSummary(
      {required this.id,
      required this.title,
      required this.turn,
      this.archived = false,
      required this.createdAt,
      required this.lastActive});
  factory _PocketbaseChatSummary.fromJson(Map<String, dynamic> json) =>
      _$PocketbaseChatSummaryFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String turn;
  @override
  @JsonKey()
  final bool archived;
  @override
  final String createdAt;
  @override
  final String lastActive;

  /// Create a copy of PocketbaseChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PocketbaseChatSummaryCopyWith<_PocketbaseChatSummary> get copyWith =>
      __$PocketbaseChatSummaryCopyWithImpl<_PocketbaseChatSummary>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PocketbaseChatSummaryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PocketbaseChatSummary &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.turn, turn) || other.turn == turn) &&
            (identical(other.archived, archived) ||
                other.archived == archived) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastActive, lastActive) ||
                other.lastActive == lastActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, title, turn, archived, createdAt, lastActive);

  @override
  String toString() {
    return 'PocketbaseChatSummary(id: $id, title: $title, turn: $turn, archived: $archived, createdAt: $createdAt, lastActive: $lastActive)';
  }
}

/// @nodoc
abstract mixin class _$PocketbaseChatSummaryCopyWith<$Res>
    implements $PocketbaseChatSummaryCopyWith<$Res> {
  factory _$PocketbaseChatSummaryCopyWith(_PocketbaseChatSummary value,
          $Res Function(_PocketbaseChatSummary) _then) =
      __$PocketbaseChatSummaryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String turn,
      bool archived,
      String createdAt,
      String lastActive});
}

/// @nodoc
class __$PocketbaseChatSummaryCopyWithImpl<$Res>
    implements _$PocketbaseChatSummaryCopyWith<$Res> {
  __$PocketbaseChatSummaryCopyWithImpl(this._self, this._then);

  final _PocketbaseChatSummary _self;
  final $Res Function(_PocketbaseChatSummary) _then;

  /// Create a copy of PocketbaseChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? turn = null,
    Object? archived = null,
    Object? createdAt = null,
    Object? lastActive = null,
  }) {
    return _then(_PocketbaseChatSummary(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      turn: null == turn
          ? _self.turn
          : turn // ignore: cast_nullable_to_non_nullable
              as String,
      archived: null == archived
          ? _self.archived
          : archived // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      lastActive: null == lastActive
          ? _self.lastActive
          : lastActive // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
