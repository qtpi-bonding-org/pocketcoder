// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Chat {
  String get id;
  String get title;
  String get user;
  DateTime? get lastActive;
  String? get preview;
  @JsonKey(unknownEnumValue: ChatTurn.unknown)
  ChatTurn? get turn;
  String? get description;
  bool? get archived;
  String? get tags;
  DateTime? get created;
  DateTime? get updated;
  String? get agentProfile;
  String? get harnessModelOverride;
  String? get ollamaModelOverride;
  String? get harness;
  dynamic get workspaceOverride;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatCopyWith<Chat> get copyWith =>
      _$ChatCopyWithImpl<Chat>(this as Chat, _$identity);

  /// Serializes this Chat to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Chat &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.lastActive, lastActive) ||
                other.lastActive == lastActive) &&
            (identical(other.preview, preview) || other.preview == preview) &&
            (identical(other.turn, turn) || other.turn == turn) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.archived, archived) ||
                other.archived == archived) &&
            (identical(other.tags, tags) || other.tags == tags) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.agentProfile, agentProfile) ||
                other.agentProfile == agentProfile) &&
            (identical(other.harnessModelOverride, harnessModelOverride) ||
                other.harnessModelOverride == harnessModelOverride) &&
            (identical(other.ollamaModelOverride, ollamaModelOverride) ||
                other.ollamaModelOverride == ollamaModelOverride) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            const DeepCollectionEquality()
                .equals(other.workspaceOverride, workspaceOverride));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      user,
      lastActive,
      preview,
      turn,
      description,
      archived,
      tags,
      created,
      updated,
      agentProfile,
      harnessModelOverride,
      ollamaModelOverride,
      harness,
      const DeepCollectionEquality().hash(workspaceOverride));

  @override
  String toString() {
    return 'Chat(id: $id, title: $title, user: $user, lastActive: $lastActive, preview: $preview, turn: $turn, description: $description, archived: $archived, tags: $tags, created: $created, updated: $updated, agentProfile: $agentProfile, harnessModelOverride: $harnessModelOverride, ollamaModelOverride: $ollamaModelOverride, harness: $harness, workspaceOverride: $workspaceOverride)';
  }
}

/// @nodoc
abstract mixin class $ChatCopyWith<$Res> {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) _then) =
      _$ChatCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String user,
      DateTime? lastActive,
      String? preview,
      @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
      String? description,
      bool? archived,
      String? tags,
      DateTime? created,
      DateTime? updated,
      String? agentProfile,
      String? harnessModelOverride,
      String? ollamaModelOverride,
      String? harness,
      dynamic workspaceOverride});
}

/// @nodoc
class _$ChatCopyWithImpl<$Res> implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._self, this._then);

  final Chat _self;
  final $Res Function(Chat) _then;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? user = null,
    Object? lastActive = freezed,
    Object? preview = freezed,
    Object? turn = freezed,
    Object? description = freezed,
    Object? archived = freezed,
    Object? tags = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? agentProfile = freezed,
    Object? harnessModelOverride = freezed,
    Object? ollamaModelOverride = freezed,
    Object? harness = freezed,
    Object? workspaceOverride = freezed,
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
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      lastActive: freezed == lastActive
          ? _self.lastActive
          : lastActive // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      preview: freezed == preview
          ? _self.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as String?,
      turn: freezed == turn
          ? _self.turn
          : turn // ignore: cast_nullable_to_non_nullable
              as ChatTurn?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      archived: freezed == archived
          ? _self.archived
          : archived // ignore: cast_nullable_to_non_nullable
              as bool?,
      tags: freezed == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as String?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      agentProfile: freezed == agentProfile
          ? _self.agentProfile
          : agentProfile // ignore: cast_nullable_to_non_nullable
              as String?,
      harnessModelOverride: freezed == harnessModelOverride
          ? _self.harnessModelOverride
          : harnessModelOverride // ignore: cast_nullable_to_non_nullable
              as String?,
      ollamaModelOverride: freezed == ollamaModelOverride
          ? _self.ollamaModelOverride
          : ollamaModelOverride // ignore: cast_nullable_to_non_nullable
              as String?,
      harness: freezed == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String?,
      workspaceOverride: freezed == workspaceOverride
          ? _self.workspaceOverride
          : workspaceOverride // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

/// Adds pattern-matching-related methods to [Chat].
extension ChatPatterns on Chat {
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
    TResult Function(_Chat value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
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
    TResult Function(_Chat value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat():
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
    TResult? Function(_Chat value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
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
            String title,
            String user,
            DateTime? lastActive,
            String? preview,
            @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
            String? description,
            bool? archived,
            String? tags,
            DateTime? created,
            DateTime? updated,
            String? agentProfile,
            String? harnessModelOverride,
            String? ollamaModelOverride,
            String? harness,
            dynamic workspaceOverride)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.user,
            _that.lastActive,
            _that.preview,
            _that.turn,
            _that.description,
            _that.archived,
            _that.tags,
            _that.created,
            _that.updated,
            _that.agentProfile,
            _that.harnessModelOverride,
            _that.ollamaModelOverride,
            _that.harness,
            _that.workspaceOverride);
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
            String title,
            String user,
            DateTime? lastActive,
            String? preview,
            @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
            String? description,
            bool? archived,
            String? tags,
            DateTime? created,
            DateTime? updated,
            String? agentProfile,
            String? harnessModelOverride,
            String? ollamaModelOverride,
            String? harness,
            dynamic workspaceOverride)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat():
        return $default(
            _that.id,
            _that.title,
            _that.user,
            _that.lastActive,
            _that.preview,
            _that.turn,
            _that.description,
            _that.archived,
            _that.tags,
            _that.created,
            _that.updated,
            _that.agentProfile,
            _that.harnessModelOverride,
            _that.ollamaModelOverride,
            _that.harness,
            _that.workspaceOverride);
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
            String title,
            String user,
            DateTime? lastActive,
            String? preview,
            @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
            String? description,
            bool? archived,
            String? tags,
            DateTime? created,
            DateTime? updated,
            String? agentProfile,
            String? harnessModelOverride,
            String? ollamaModelOverride,
            String? harness,
            dynamic workspaceOverride)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.user,
            _that.lastActive,
            _that.preview,
            _that.turn,
            _that.description,
            _that.archived,
            _that.tags,
            _that.created,
            _that.updated,
            _that.agentProfile,
            _that.harnessModelOverride,
            _that.ollamaModelOverride,
            _that.harness,
            _that.workspaceOverride);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Chat implements Chat {
  const _Chat(
      {required this.id,
      required this.title,
      required this.user,
      this.lastActive,
      this.preview,
      @JsonKey(unknownEnumValue: ChatTurn.unknown) this.turn,
      this.description,
      this.archived,
      this.tags,
      this.created,
      this.updated,
      this.agentProfile,
      this.harnessModelOverride,
      this.ollamaModelOverride,
      this.harness,
      this.workspaceOverride});
  factory _Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String user;
  @override
  final DateTime? lastActive;
  @override
  final String? preview;
  @override
  @JsonKey(unknownEnumValue: ChatTurn.unknown)
  final ChatTurn? turn;
  @override
  final String? description;
  @override
  final bool? archived;
  @override
  final String? tags;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;
  @override
  final String? agentProfile;
  @override
  final String? harnessModelOverride;
  @override
  final String? ollamaModelOverride;
  @override
  final String? harness;
  @override
  final dynamic workspaceOverride;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatCopyWith<_Chat> get copyWith =>
      __$ChatCopyWithImpl<_Chat>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChatToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Chat &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.lastActive, lastActive) ||
                other.lastActive == lastActive) &&
            (identical(other.preview, preview) || other.preview == preview) &&
            (identical(other.turn, turn) || other.turn == turn) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.archived, archived) ||
                other.archived == archived) &&
            (identical(other.tags, tags) || other.tags == tags) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.agentProfile, agentProfile) ||
                other.agentProfile == agentProfile) &&
            (identical(other.harnessModelOverride, harnessModelOverride) ||
                other.harnessModelOverride == harnessModelOverride) &&
            (identical(other.ollamaModelOverride, ollamaModelOverride) ||
                other.ollamaModelOverride == ollamaModelOverride) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            const DeepCollectionEquality()
                .equals(other.workspaceOverride, workspaceOverride));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      user,
      lastActive,
      preview,
      turn,
      description,
      archived,
      tags,
      created,
      updated,
      agentProfile,
      harnessModelOverride,
      ollamaModelOverride,
      harness,
      const DeepCollectionEquality().hash(workspaceOverride));

  @override
  String toString() {
    return 'Chat(id: $id, title: $title, user: $user, lastActive: $lastActive, preview: $preview, turn: $turn, description: $description, archived: $archived, tags: $tags, created: $created, updated: $updated, agentProfile: $agentProfile, harnessModelOverride: $harnessModelOverride, ollamaModelOverride: $ollamaModelOverride, harness: $harness, workspaceOverride: $workspaceOverride)';
  }
}

/// @nodoc
abstract mixin class _$ChatCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$ChatCopyWith(_Chat value, $Res Function(_Chat) _then) =
      __$ChatCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String user,
      DateTime? lastActive,
      String? preview,
      @JsonKey(unknownEnumValue: ChatTurn.unknown) ChatTurn? turn,
      String? description,
      bool? archived,
      String? tags,
      DateTime? created,
      DateTime? updated,
      String? agentProfile,
      String? harnessModelOverride,
      String? ollamaModelOverride,
      String? harness,
      dynamic workspaceOverride});
}

/// @nodoc
class __$ChatCopyWithImpl<$Res> implements _$ChatCopyWith<$Res> {
  __$ChatCopyWithImpl(this._self, this._then);

  final _Chat _self;
  final $Res Function(_Chat) _then;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? user = null,
    Object? lastActive = freezed,
    Object? preview = freezed,
    Object? turn = freezed,
    Object? description = freezed,
    Object? archived = freezed,
    Object? tags = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? agentProfile = freezed,
    Object? harnessModelOverride = freezed,
    Object? ollamaModelOverride = freezed,
    Object? harness = freezed,
    Object? workspaceOverride = freezed,
  }) {
    return _then(_Chat(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      lastActive: freezed == lastActive
          ? _self.lastActive
          : lastActive // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      preview: freezed == preview
          ? _self.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as String?,
      turn: freezed == turn
          ? _self.turn
          : turn // ignore: cast_nullable_to_non_nullable
              as ChatTurn?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      archived: freezed == archived
          ? _self.archived
          : archived // ignore: cast_nullable_to_non_nullable
              as bool?,
      tags: freezed == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as String?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      agentProfile: freezed == agentProfile
          ? _self.agentProfile
          : agentProfile // ignore: cast_nullable_to_non_nullable
              as String?,
      harnessModelOverride: freezed == harnessModelOverride
          ? _self.harnessModelOverride
          : harnessModelOverride // ignore: cast_nullable_to_non_nullable
              as String?,
      ollamaModelOverride: freezed == ollamaModelOverride
          ? _self.ollamaModelOverride
          : ollamaModelOverride // ignore: cast_nullable_to_non_nullable
              as String?,
      harness: freezed == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String?,
      workspaceOverride: freezed == workspaceOverride
          ? _self.workspaceOverride
          : workspaceOverride // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

// dart format on
