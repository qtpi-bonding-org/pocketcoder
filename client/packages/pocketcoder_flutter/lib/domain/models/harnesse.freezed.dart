// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harnesse.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Harnesse {
  String get id;
  String get name;
  String get cliId;
  String? get version;
  String? get description;
  @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
  HarnesseAcpTransport get acpTransport;
  String? get containerImage;
  dynamic get launchTemplate;
  bool? get supportsLiveConfig;
  bool? get supportsLiveCredentialRegistration;
  bool? get providerFanout;
  bool? get supportsOllama;
  bool? get supportsSessionDelete;
  bool? get supportsAdditionalDirectories;

  /// Create a copy of Harnesse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnesseCopyWith<Harnesse> get copyWith =>
      _$HarnesseCopyWithImpl<Harnesse>(this as Harnesse, _$identity);

  /// Serializes this Harnesse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Harnesse &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.cliId, cliId) || other.cliId == cliId) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.acpTransport, acpTransport) ||
                other.acpTransport == acpTransport) &&
            (identical(other.containerImage, containerImage) ||
                other.containerImage == containerImage) &&
            const DeepCollectionEquality()
                .equals(other.launchTemplate, launchTemplate) &&
            (identical(other.supportsLiveConfig, supportsLiveConfig) ||
                other.supportsLiveConfig == supportsLiveConfig) &&
            (identical(other.supportsLiveCredentialRegistration,
                    supportsLiveCredentialRegistration) ||
                other.supportsLiveCredentialRegistration ==
                    supportsLiveCredentialRegistration) &&
            (identical(other.providerFanout, providerFanout) ||
                other.providerFanout == providerFanout) &&
            (identical(other.supportsOllama, supportsOllama) ||
                other.supportsOllama == supportsOllama) &&
            (identical(other.supportsSessionDelete, supportsSessionDelete) ||
                other.supportsSessionDelete == supportsSessionDelete) &&
            (identical(other.supportsAdditionalDirectories,
                    supportsAdditionalDirectories) ||
                other.supportsAdditionalDirectories ==
                    supportsAdditionalDirectories));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      cliId,
      version,
      description,
      acpTransport,
      containerImage,
      const DeepCollectionEquality().hash(launchTemplate),
      supportsLiveConfig,
      supportsLiveCredentialRegistration,
      providerFanout,
      supportsOllama,
      supportsSessionDelete,
      supportsAdditionalDirectories);

  @override
  String toString() {
    return 'Harnesse(id: $id, name: $name, cliId: $cliId, version: $version, description: $description, acpTransport: $acpTransport, containerImage: $containerImage, launchTemplate: $launchTemplate, supportsLiveConfig: $supportsLiveConfig, supportsLiveCredentialRegistration: $supportsLiveCredentialRegistration, providerFanout: $providerFanout, supportsOllama: $supportsOllama, supportsSessionDelete: $supportsSessionDelete, supportsAdditionalDirectories: $supportsAdditionalDirectories)';
  }
}

/// @nodoc
abstract mixin class $HarnesseCopyWith<$Res> {
  factory $HarnesseCopyWith(Harnesse value, $Res Function(Harnesse) _then) =
      _$HarnesseCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String cliId,
      String? version,
      String? description,
      @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
      HarnesseAcpTransport acpTransport,
      String? containerImage,
      dynamic launchTemplate,
      bool? supportsLiveConfig,
      bool? supportsLiveCredentialRegistration,
      bool? providerFanout,
      bool? supportsOllama,
      bool? supportsSessionDelete,
      bool? supportsAdditionalDirectories});
}

/// @nodoc
class _$HarnesseCopyWithImpl<$Res> implements $HarnesseCopyWith<$Res> {
  _$HarnesseCopyWithImpl(this._self, this._then);

  final Harnesse _self;
  final $Res Function(Harnesse) _then;

  /// Create a copy of Harnesse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? cliId = null,
    Object? version = freezed,
    Object? description = freezed,
    Object? acpTransport = null,
    Object? containerImage = freezed,
    Object? launchTemplate = freezed,
    Object? supportsLiveConfig = freezed,
    Object? supportsLiveCredentialRegistration = freezed,
    Object? providerFanout = freezed,
    Object? supportsOllama = freezed,
    Object? supportsSessionDelete = freezed,
    Object? supportsAdditionalDirectories = freezed,
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
      cliId: null == cliId
          ? _self.cliId
          : cliId // ignore: cast_nullable_to_non_nullable
              as String,
      version: freezed == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      acpTransport: null == acpTransport
          ? _self.acpTransport
          : acpTransport // ignore: cast_nullable_to_non_nullable
              as HarnesseAcpTransport,
      containerImage: freezed == containerImage
          ? _self.containerImage
          : containerImage // ignore: cast_nullable_to_non_nullable
              as String?,
      launchTemplate: freezed == launchTemplate
          ? _self.launchTemplate
          : launchTemplate // ignore: cast_nullable_to_non_nullable
              as dynamic,
      supportsLiveConfig: freezed == supportsLiveConfig
          ? _self.supportsLiveConfig
          : supportsLiveConfig // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsLiveCredentialRegistration: freezed ==
              supportsLiveCredentialRegistration
          ? _self.supportsLiveCredentialRegistration
          : supportsLiveCredentialRegistration // ignore: cast_nullable_to_non_nullable
              as bool?,
      providerFanout: freezed == providerFanout
          ? _self.providerFanout
          : providerFanout // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsOllama: freezed == supportsOllama
          ? _self.supportsOllama
          : supportsOllama // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsSessionDelete: freezed == supportsSessionDelete
          ? _self.supportsSessionDelete
          : supportsSessionDelete // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsAdditionalDirectories: freezed == supportsAdditionalDirectories
          ? _self.supportsAdditionalDirectories
          : supportsAdditionalDirectories // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Harnesse].
extension HarnessePatterns on Harnesse {
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
    TResult Function(_Harnesse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Harnesse() when $default != null:
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
    TResult Function(_Harnesse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Harnesse():
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
    TResult? Function(_Harnesse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Harnesse() when $default != null:
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
            String cliId,
            String? version,
            String? description,
            @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
            HarnesseAcpTransport acpTransport,
            String? containerImage,
            dynamic launchTemplate,
            bool? supportsLiveConfig,
            bool? supportsLiveCredentialRegistration,
            bool? providerFanout,
            bool? supportsOllama,
            bool? supportsSessionDelete,
            bool? supportsAdditionalDirectories)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Harnesse() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.cliId,
            _that.version,
            _that.description,
            _that.acpTransport,
            _that.containerImage,
            _that.launchTemplate,
            _that.supportsLiveConfig,
            _that.supportsLiveCredentialRegistration,
            _that.providerFanout,
            _that.supportsOllama,
            _that.supportsSessionDelete,
            _that.supportsAdditionalDirectories);
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
            String cliId,
            String? version,
            String? description,
            @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
            HarnesseAcpTransport acpTransport,
            String? containerImage,
            dynamic launchTemplate,
            bool? supportsLiveConfig,
            bool? supportsLiveCredentialRegistration,
            bool? providerFanout,
            bool? supportsOllama,
            bool? supportsSessionDelete,
            bool? supportsAdditionalDirectories)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Harnesse():
        return $default(
            _that.id,
            _that.name,
            _that.cliId,
            _that.version,
            _that.description,
            _that.acpTransport,
            _that.containerImage,
            _that.launchTemplate,
            _that.supportsLiveConfig,
            _that.supportsLiveCredentialRegistration,
            _that.providerFanout,
            _that.supportsOllama,
            _that.supportsSessionDelete,
            _that.supportsAdditionalDirectories);
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
            String cliId,
            String? version,
            String? description,
            @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
            HarnesseAcpTransport acpTransport,
            String? containerImage,
            dynamic launchTemplate,
            bool? supportsLiveConfig,
            bool? supportsLiveCredentialRegistration,
            bool? providerFanout,
            bool? supportsOllama,
            bool? supportsSessionDelete,
            bool? supportsAdditionalDirectories)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Harnesse() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.cliId,
            _that.version,
            _that.description,
            _that.acpTransport,
            _that.containerImage,
            _that.launchTemplate,
            _that.supportsLiveConfig,
            _that.supportsLiveCredentialRegistration,
            _that.providerFanout,
            _that.supportsOllama,
            _that.supportsSessionDelete,
            _that.supportsAdditionalDirectories);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Harnesse implements Harnesse {
  const _Harnesse(
      {required this.id,
      required this.name,
      required this.cliId,
      this.version,
      this.description,
      @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
      required this.acpTransport,
      this.containerImage,
      this.launchTemplate,
      this.supportsLiveConfig,
      this.supportsLiveCredentialRegistration,
      this.providerFanout,
      this.supportsOllama,
      this.supportsSessionDelete,
      this.supportsAdditionalDirectories});
  factory _Harnesse.fromJson(Map<String, dynamic> json) =>
      _$HarnesseFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String cliId;
  @override
  final String? version;
  @override
  final String? description;
  @override
  @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
  final HarnesseAcpTransport acpTransport;
  @override
  final String? containerImage;
  @override
  final dynamic launchTemplate;
  @override
  final bool? supportsLiveConfig;
  @override
  final bool? supportsLiveCredentialRegistration;
  @override
  final bool? providerFanout;
  @override
  final bool? supportsOllama;
  @override
  final bool? supportsSessionDelete;
  @override
  final bool? supportsAdditionalDirectories;

  /// Create a copy of Harnesse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnesseCopyWith<_Harnesse> get copyWith =>
      __$HarnesseCopyWithImpl<_Harnesse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnesseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Harnesse &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.cliId, cliId) || other.cliId == cliId) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.acpTransport, acpTransport) ||
                other.acpTransport == acpTransport) &&
            (identical(other.containerImage, containerImage) ||
                other.containerImage == containerImage) &&
            const DeepCollectionEquality()
                .equals(other.launchTemplate, launchTemplate) &&
            (identical(other.supportsLiveConfig, supportsLiveConfig) ||
                other.supportsLiveConfig == supportsLiveConfig) &&
            (identical(other.supportsLiveCredentialRegistration,
                    supportsLiveCredentialRegistration) ||
                other.supportsLiveCredentialRegistration ==
                    supportsLiveCredentialRegistration) &&
            (identical(other.providerFanout, providerFanout) ||
                other.providerFanout == providerFanout) &&
            (identical(other.supportsOllama, supportsOllama) ||
                other.supportsOllama == supportsOllama) &&
            (identical(other.supportsSessionDelete, supportsSessionDelete) ||
                other.supportsSessionDelete == supportsSessionDelete) &&
            (identical(other.supportsAdditionalDirectories,
                    supportsAdditionalDirectories) ||
                other.supportsAdditionalDirectories ==
                    supportsAdditionalDirectories));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      cliId,
      version,
      description,
      acpTransport,
      containerImage,
      const DeepCollectionEquality().hash(launchTemplate),
      supportsLiveConfig,
      supportsLiveCredentialRegistration,
      providerFanout,
      supportsOllama,
      supportsSessionDelete,
      supportsAdditionalDirectories);

  @override
  String toString() {
    return 'Harnesse(id: $id, name: $name, cliId: $cliId, version: $version, description: $description, acpTransport: $acpTransport, containerImage: $containerImage, launchTemplate: $launchTemplate, supportsLiveConfig: $supportsLiveConfig, supportsLiveCredentialRegistration: $supportsLiveCredentialRegistration, providerFanout: $providerFanout, supportsOllama: $supportsOllama, supportsSessionDelete: $supportsSessionDelete, supportsAdditionalDirectories: $supportsAdditionalDirectories)';
  }
}

/// @nodoc
abstract mixin class _$HarnesseCopyWith<$Res>
    implements $HarnesseCopyWith<$Res> {
  factory _$HarnesseCopyWith(_Harnesse value, $Res Function(_Harnesse) _then) =
      __$HarnesseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String cliId,
      String? version,
      String? description,
      @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
      HarnesseAcpTransport acpTransport,
      String? containerImage,
      dynamic launchTemplate,
      bool? supportsLiveConfig,
      bool? supportsLiveCredentialRegistration,
      bool? providerFanout,
      bool? supportsOllama,
      bool? supportsSessionDelete,
      bool? supportsAdditionalDirectories});
}

/// @nodoc
class __$HarnesseCopyWithImpl<$Res> implements _$HarnesseCopyWith<$Res> {
  __$HarnesseCopyWithImpl(this._self, this._then);

  final _Harnesse _self;
  final $Res Function(_Harnesse) _then;

  /// Create a copy of Harnesse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? cliId = null,
    Object? version = freezed,
    Object? description = freezed,
    Object? acpTransport = null,
    Object? containerImage = freezed,
    Object? launchTemplate = freezed,
    Object? supportsLiveConfig = freezed,
    Object? supportsLiveCredentialRegistration = freezed,
    Object? providerFanout = freezed,
    Object? supportsOllama = freezed,
    Object? supportsSessionDelete = freezed,
    Object? supportsAdditionalDirectories = freezed,
  }) {
    return _then(_Harnesse(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      cliId: null == cliId
          ? _self.cliId
          : cliId // ignore: cast_nullable_to_non_nullable
              as String,
      version: freezed == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      acpTransport: null == acpTransport
          ? _self.acpTransport
          : acpTransport // ignore: cast_nullable_to_non_nullable
              as HarnesseAcpTransport,
      containerImage: freezed == containerImage
          ? _self.containerImage
          : containerImage // ignore: cast_nullable_to_non_nullable
              as String?,
      launchTemplate: freezed == launchTemplate
          ? _self.launchTemplate
          : launchTemplate // ignore: cast_nullable_to_non_nullable
              as dynamic,
      supportsLiveConfig: freezed == supportsLiveConfig
          ? _self.supportsLiveConfig
          : supportsLiveConfig // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsLiveCredentialRegistration: freezed ==
              supportsLiveCredentialRegistration
          ? _self.supportsLiveCredentialRegistration
          : supportsLiveCredentialRegistration // ignore: cast_nullable_to_non_nullable
              as bool?,
      providerFanout: freezed == providerFanout
          ? _self.providerFanout
          : providerFanout // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsOllama: freezed == supportsOllama
          ? _self.supportsOllama
          : supportsOllama // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsSessionDelete: freezed == supportsSessionDelete
          ? _self.supportsSessionDelete
          : supportsSessionDelete // ignore: cast_nullable_to_non_nullable
              as bool?,
      supportsAdditionalDirectories: freezed == supportsAdditionalDirectories
          ? _self.supportsAdditionalDirectories
          : supportsAdditionalDirectories // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
