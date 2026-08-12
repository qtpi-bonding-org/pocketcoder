// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpServer {
  String get id;
  String get name;
  @JsonKey(unknownEnumValue: McpServerStatus.unknown)
  McpServerStatus get status;
  String? get requestedBy;
  String? get approvedBy;
  DateTime? get approvedAt;
  dynamic get config;
  String? get catalog;
  String? get reason;
  String? get image;
  dynamic get configSchema;
  String? get oauthProvider;
  String? get oauthTokenEnvVar;
  DateTime? get created;
  DateTime? get updated;
  @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
  McpServerAcpTransport? get acpTransport;

  /// Create a copy of McpServer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $McpServerCopyWith<McpServer> get copyWith =>
      _$McpServerCopyWithImpl<McpServer>(this as McpServer, _$identity);

  /// Serializes this McpServer to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is McpServer &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.requestedBy, requestedBy) ||
                other.requestedBy == requestedBy) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            const DeepCollectionEquality().equals(other.config, config) &&
            (identical(other.catalog, catalog) || other.catalog == catalog) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.image, image) || other.image == image) &&
            const DeepCollectionEquality()
                .equals(other.configSchema, configSchema) &&
            (identical(other.oauthProvider, oauthProvider) ||
                other.oauthProvider == oauthProvider) &&
            (identical(other.oauthTokenEnvVar, oauthTokenEnvVar) ||
                other.oauthTokenEnvVar == oauthTokenEnvVar) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.acpTransport, acpTransport) ||
                other.acpTransport == acpTransport));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      status,
      requestedBy,
      approvedBy,
      approvedAt,
      const DeepCollectionEquality().hash(config),
      catalog,
      reason,
      image,
      const DeepCollectionEquality().hash(configSchema),
      oauthProvider,
      oauthTokenEnvVar,
      created,
      updated,
      acpTransport);

  @override
  String toString() {
    return 'McpServer(id: $id, name: $name, status: $status, requestedBy: $requestedBy, approvedBy: $approvedBy, approvedAt: $approvedAt, config: $config, catalog: $catalog, reason: $reason, image: $image, configSchema: $configSchema, oauthProvider: $oauthProvider, oauthTokenEnvVar: $oauthTokenEnvVar, created: $created, updated: $updated, acpTransport: $acpTransport)';
  }
}

/// @nodoc
abstract mixin class $McpServerCopyWith<$Res> {
  factory $McpServerCopyWith(McpServer value, $Res Function(McpServer) _then) =
      _$McpServerCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(unknownEnumValue: McpServerStatus.unknown)
      McpServerStatus status,
      String? requestedBy,
      String? approvedBy,
      DateTime? approvedAt,
      dynamic config,
      String? catalog,
      String? reason,
      String? image,
      dynamic configSchema,
      String? oauthProvider,
      String? oauthTokenEnvVar,
      DateTime? created,
      DateTime? updated,
      @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
      McpServerAcpTransport? acpTransport});
}

/// @nodoc
class _$McpServerCopyWithImpl<$Res> implements $McpServerCopyWith<$Res> {
  _$McpServerCopyWithImpl(this._self, this._then);

  final McpServer _self;
  final $Res Function(McpServer) _then;

  /// Create a copy of McpServer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? status = null,
    Object? requestedBy = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? config = freezed,
    Object? catalog = freezed,
    Object? reason = freezed,
    Object? image = freezed,
    Object? configSchema = freezed,
    Object? oauthProvider = freezed,
    Object? oauthTokenEnvVar = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? acpTransport = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as McpServerStatus,
      requestedBy: freezed == requestedBy
          ? _self.requestedBy
          : requestedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedBy: freezed == approvedBy
          ? _self.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedAt: freezed == approvedAt
          ? _self.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      config: freezed == config
          ? _self.config
          : config // ignore: cast_nullable_to_non_nullable
              as dynamic,
      catalog: freezed == catalog
          ? _self.catalog
          : catalog // ignore: cast_nullable_to_non_nullable
              as String?,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      image: freezed == image
          ? _self.image
          : image // ignore: cast_nullable_to_non_nullable
              as String?,
      configSchema: freezed == configSchema
          ? _self.configSchema
          : configSchema // ignore: cast_nullable_to_non_nullable
              as dynamic,
      oauthProvider: freezed == oauthProvider
          ? _self.oauthProvider
          : oauthProvider // ignore: cast_nullable_to_non_nullable
              as String?,
      oauthTokenEnvVar: freezed == oauthTokenEnvVar
          ? _self.oauthTokenEnvVar
          : oauthTokenEnvVar // ignore: cast_nullable_to_non_nullable
              as String?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acpTransport: freezed == acpTransport
          ? _self.acpTransport
          : acpTransport // ignore: cast_nullable_to_non_nullable
              as McpServerAcpTransport?,
    ));
  }
}

/// Adds pattern-matching-related methods to [McpServer].
extension McpServerPatterns on McpServer {
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
    TResult Function(_McpServer value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _McpServer() when $default != null:
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
    TResult Function(_McpServer value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpServer():
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
    TResult? Function(_McpServer value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpServer() when $default != null:
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
            String name,
            @JsonKey(unknownEnumValue: McpServerStatus.unknown)
            McpServerStatus status,
            String? requestedBy,
            String? approvedBy,
            DateTime? approvedAt,
            dynamic config,
            String? catalog,
            String? reason,
            String? image,
            dynamic configSchema,
            String? oauthProvider,
            String? oauthTokenEnvVar,
            DateTime? created,
            DateTime? updated,
            @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
            McpServerAcpTransport? acpTransport)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _McpServer() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.status,
            _that.requestedBy,
            _that.approvedBy,
            _that.approvedAt,
            _that.config,
            _that.catalog,
            _that.reason,
            _that.image,
            _that.configSchema,
            _that.oauthProvider,
            _that.oauthTokenEnvVar,
            _that.created,
            _that.updated,
            _that.acpTransport);
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
            String name,
            @JsonKey(unknownEnumValue: McpServerStatus.unknown)
            McpServerStatus status,
            String? requestedBy,
            String? approvedBy,
            DateTime? approvedAt,
            dynamic config,
            String? catalog,
            String? reason,
            String? image,
            dynamic configSchema,
            String? oauthProvider,
            String? oauthTokenEnvVar,
            DateTime? created,
            DateTime? updated,
            @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
            McpServerAcpTransport? acpTransport)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpServer():
        return $default(
            _that.id,
            _that.name,
            _that.status,
            _that.requestedBy,
            _that.approvedBy,
            _that.approvedAt,
            _that.config,
            _that.catalog,
            _that.reason,
            _that.image,
            _that.configSchema,
            _that.oauthProvider,
            _that.oauthTokenEnvVar,
            _that.created,
            _that.updated,
            _that.acpTransport);
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
            String name,
            @JsonKey(unknownEnumValue: McpServerStatus.unknown)
            McpServerStatus status,
            String? requestedBy,
            String? approvedBy,
            DateTime? approvedAt,
            dynamic config,
            String? catalog,
            String? reason,
            String? image,
            dynamic configSchema,
            String? oauthProvider,
            String? oauthTokenEnvVar,
            DateTime? created,
            DateTime? updated,
            @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
            McpServerAcpTransport? acpTransport)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpServer() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.status,
            _that.requestedBy,
            _that.approvedBy,
            _that.approvedAt,
            _that.config,
            _that.catalog,
            _that.reason,
            _that.image,
            _that.configSchema,
            _that.oauthProvider,
            _that.oauthTokenEnvVar,
            _that.created,
            _that.updated,
            _that.acpTransport);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _McpServer implements McpServer {
  const _McpServer(
      {required this.id,
      required this.name,
      @JsonKey(unknownEnumValue: McpServerStatus.unknown) required this.status,
      this.requestedBy,
      this.approvedBy,
      this.approvedAt,
      this.config,
      this.catalog,
      this.reason,
      this.image,
      this.configSchema,
      this.oauthProvider,
      this.oauthTokenEnvVar,
      this.created,
      this.updated,
      @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
      this.acpTransport});
  factory _McpServer.fromJson(Map<String, dynamic> json) =>
      _$McpServerFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(unknownEnumValue: McpServerStatus.unknown)
  final McpServerStatus status;
  @override
  final String? requestedBy;
  @override
  final String? approvedBy;
  @override
  final DateTime? approvedAt;
  @override
  final dynamic config;
  @override
  final String? catalog;
  @override
  final String? reason;
  @override
  final String? image;
  @override
  final dynamic configSchema;
  @override
  final String? oauthProvider;
  @override
  final String? oauthTokenEnvVar;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;
  @override
  @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
  final McpServerAcpTransport? acpTransport;

  /// Create a copy of McpServer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$McpServerCopyWith<_McpServer> get copyWith =>
      __$McpServerCopyWithImpl<_McpServer>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$McpServerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _McpServer &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.requestedBy, requestedBy) ||
                other.requestedBy == requestedBy) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            const DeepCollectionEquality().equals(other.config, config) &&
            (identical(other.catalog, catalog) || other.catalog == catalog) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.image, image) || other.image == image) &&
            const DeepCollectionEquality()
                .equals(other.configSchema, configSchema) &&
            (identical(other.oauthProvider, oauthProvider) ||
                other.oauthProvider == oauthProvider) &&
            (identical(other.oauthTokenEnvVar, oauthTokenEnvVar) ||
                other.oauthTokenEnvVar == oauthTokenEnvVar) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.acpTransport, acpTransport) ||
                other.acpTransport == acpTransport));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      status,
      requestedBy,
      approvedBy,
      approvedAt,
      const DeepCollectionEquality().hash(config),
      catalog,
      reason,
      image,
      const DeepCollectionEquality().hash(configSchema),
      oauthProvider,
      oauthTokenEnvVar,
      created,
      updated,
      acpTransport);

  @override
  String toString() {
    return 'McpServer(id: $id, name: $name, status: $status, requestedBy: $requestedBy, approvedBy: $approvedBy, approvedAt: $approvedAt, config: $config, catalog: $catalog, reason: $reason, image: $image, configSchema: $configSchema, oauthProvider: $oauthProvider, oauthTokenEnvVar: $oauthTokenEnvVar, created: $created, updated: $updated, acpTransport: $acpTransport)';
  }
}

/// @nodoc
abstract mixin class _$McpServerCopyWith<$Res>
    implements $McpServerCopyWith<$Res> {
  factory _$McpServerCopyWith(
          _McpServer value, $Res Function(_McpServer) _then) =
      __$McpServerCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(unknownEnumValue: McpServerStatus.unknown)
      McpServerStatus status,
      String? requestedBy,
      String? approvedBy,
      DateTime? approvedAt,
      dynamic config,
      String? catalog,
      String? reason,
      String? image,
      dynamic configSchema,
      String? oauthProvider,
      String? oauthTokenEnvVar,
      DateTime? created,
      DateTime? updated,
      @JsonKey(unknownEnumValue: McpServerAcpTransport.unknown)
      McpServerAcpTransport? acpTransport});
}

/// @nodoc
class __$McpServerCopyWithImpl<$Res> implements _$McpServerCopyWith<$Res> {
  __$McpServerCopyWithImpl(this._self, this._then);

  final _McpServer _self;
  final $Res Function(_McpServer) _then;

  /// Create a copy of McpServer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? status = null,
    Object? requestedBy = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? config = freezed,
    Object? catalog = freezed,
    Object? reason = freezed,
    Object? image = freezed,
    Object? configSchema = freezed,
    Object? oauthProvider = freezed,
    Object? oauthTokenEnvVar = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? acpTransport = freezed,
  }) {
    return _then(_McpServer(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as McpServerStatus,
      requestedBy: freezed == requestedBy
          ? _self.requestedBy
          : requestedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedBy: freezed == approvedBy
          ? _self.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedAt: freezed == approvedAt
          ? _self.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      config: freezed == config
          ? _self.config
          : config // ignore: cast_nullable_to_non_nullable
              as dynamic,
      catalog: freezed == catalog
          ? _self.catalog
          : catalog // ignore: cast_nullable_to_non_nullable
              as String?,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      image: freezed == image
          ? _self.image
          : image // ignore: cast_nullable_to_non_nullable
              as String?,
      configSchema: freezed == configSchema
          ? _self.configSchema
          : configSchema // ignore: cast_nullable_to_non_nullable
              as dynamic,
      oauthProvider: freezed == oauthProvider
          ? _self.oauthProvider
          : oauthProvider // ignore: cast_nullable_to_non_nullable
              as String?,
      oauthTokenEnvVar: freezed == oauthTokenEnvVar
          ? _self.oauthTokenEnvVar
          : oauthTokenEnvVar // ignore: cast_nullable_to_non_nullable
              as String?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acpTransport: freezed == acpTransport
          ? _self.acpTransport
          : acpTransport // ignore: cast_nullable_to_non_nullable
              as McpServerAcpTransport?,
    ));
  }
}

// dart format on
