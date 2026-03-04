//@GeneratedMicroModule;FlutterAeroformPackageModule;package:flutter_aeroform/flutter_aeroform.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:flutter_aeroform/domain/auth/i_oauth_service.dart' as _i172;
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart'
    as _i432;
import 'package:flutter_aeroform/domain/deployment/i_deployment_service.dart'
    as _i440;
import 'package:flutter_aeroform/domain/security/i_certificate_manager.dart'
    as _i698;
import 'package:flutter_aeroform/domain/security/i_password_generator.dart'
    as _i395;
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart' as _i571;
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart'
    as _i280;
import 'package:flutter_aeroform/infrastructure/auth/linode_oauth_service.dart'
    as _i764;
import 'package:flutter_aeroform/infrastructure/cloud_provider/linode_api_client.dart'
    as _i732;
import 'package:flutter_aeroform/infrastructure/deployment/deployment_service.dart'
    as _i877;
import 'package:flutter_aeroform/infrastructure/security/certificate_manager.dart'
    as _i653;
import 'package:flutter_aeroform/infrastructure/security/password_generator.dart'
    as _i888;
import 'package:flutter_aeroform/infrastructure/storage/secure_storage.dart'
    as _i436;
import 'package:flutter_aeroform/infrastructure/validation/validation_service.dart'
    as _i489;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;

class FlutterAeroformPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i432.ICloudProviderAPIClient>(() => _i732.LinodeAPIClient(
          gh<_i519.Client>(),
          gh<String>(instanceName: 'linodeClientId'),
        ));
    gh.lazySingleton<_i280.IValidationService>(() => _i489.ValidationService());
    gh.lazySingleton<_i395.IPasswordGenerator>(() => _i888.PasswordGenerator());
    gh.lazySingleton<_i571.ISecureStorage>(
        () => _i436.SecureStorage(storage: gh<_i558.FlutterSecureStorage>()));
    gh.lazySingleton<_i172.IOAuthService>(() => _i764.LinodeOAuthService(
          gh<_i571.ISecureStorage>(),
          gh<_i432.ICloudProviderAPIClient>(),
          gh<String>(instanceName: 'linodeClientId'),
        ));
    gh.lazySingleton<_i698.ICertificateManager>(
        () => _i653.CertificateManager(gh<_i571.ISecureStorage>()));
    gh.lazySingleton<_i440.IDeploymentService>(() => _i877.DeploymentService(
          apiClient: gh<_i432.ICloudProviderAPIClient>(),
          certManager: gh<_i698.ICertificateManager>(),
          passwordGenerator: gh<_i395.IPasswordGenerator>(),
          secureStorage: gh<_i571.ISecureStorage>(),
          validationService: gh<_i280.IValidationService>(),
        ));
  }
}
