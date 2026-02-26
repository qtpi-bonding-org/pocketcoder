// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cubit_ui_flow/cubit_ui_flow.dart' as _i653;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:pocketbase/pocketbase.dart' as _i169;
import 'package:pocketbase_drift/pocketbase_drift.dart' as _i824;
import 'package:pocketcoder_flutter/application/ai/ai_config_cubit.dart'
    as _i616;
import 'package:pocketcoder_flutter/application/auth/auth_cubit.dart' as _i938;
import 'package:pocketcoder_flutter/application/auth/auth_message_mapper.dart'
    as _i677;
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart'
    as _i304;
import 'package:pocketcoder_flutter/application/chat/communication_cubit.dart'
    as _i907;
import 'package:pocketcoder_flutter/application/config/config_cubit.dart'
    as _i816;
import 'package:pocketcoder_flutter/application/deployment/deployment_cubit.dart'
    as _i332;
import 'package:pocketcoder_flutter/application/deployment/deployment_message_mapper.dart'
    as _i883;
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart' as _i328;
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart'
    as _i273;
import 'package:pocketcoder_flutter/application/permission/permission_cubit.dart'
    as _i955;
import 'package:pocketcoder_flutter/application/sop/sop_cubit.dart' as _i252;
import 'package:pocketcoder_flutter/application/subagent/subagent_cubit.dart'
    as _i440;
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart'
    as _i464;
import 'package:pocketcoder_flutter/application/system/health_cubit.dart'
    as _i967;
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart'
    as _i992;
import 'package:pocketcoder_flutter/application/system/status_cubit.dart'
    as _i506;
import 'package:pocketcoder_flutter/application/terminal/terminal_cubit.dart'
    as _i1000;
import 'package:pocketcoder_flutter/application/whitelist/whitelist_cubit.dart'
    as _i528;
import 'package:pocketcoder_flutter/design_system/theme/theme_service.dart'
    as _i704;
import 'package:pocketcoder_flutter/domain/ai_config/i_ai_config_repository.dart'
    as _i536;
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart' as _i50;
import 'package:pocketcoder_flutter/domain/auth/i_oauth_service.dart' as _i205;
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart'
    as _i619;
import 'package:pocketcoder_flutter/domain/cloud_provider/i_cloud_provider_api_client.dart'
    as _i240;
import 'package:pocketcoder_flutter/domain/communication/i_communication_repository.dart'
    as _i215;
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_service.dart'
    as _i565;
import 'package:pocketcoder_flutter/domain/evolution/i_evolution_repository.dart'
    as _i656;
import 'package:pocketcoder_flutter/domain/healthcheck/i_healthcheck_repository.dart'
    as _i623;
import 'package:pocketcoder_flutter/domain/hitl/i_hitl_repository.dart' as _i20;
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart' as _i922;
import 'package:pocketcoder_flutter/domain/models/app_config.dart' as _i796;
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart'
    as _i148;
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart'
    as _i611;
import 'package:pocketcoder_flutter/domain/security/i_certificate_manager.dart'
    as _i980;
import 'package:pocketcoder_flutter/domain/security/i_password_generator.dart'
    as _i780;
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart'
    as _i190;
import 'package:pocketcoder_flutter/domain/storage/i_secure_storage.dart'
    as _i598;
import 'package:pocketcoder_flutter/domain/subagent/i_subagent_repository.dart'
    as _i322;
import 'package:pocketcoder_flutter/domain/system/i_health_repository.dart'
    as _i800;
import 'package:pocketcoder_flutter/domain/validation/i_validation_service.dart'
    as _i843;
import 'package:pocketcoder_flutter/infrastructure/ai_config/ai_config_daos.dart'
    as _i61;
import 'package:pocketcoder_flutter/infrastructure/ai_config/ai_config_repository.dart'
    as _i846;
import 'package:pocketcoder_flutter/infrastructure/auth/auth_daos.dart'
    as _i589;
import 'package:pocketcoder_flutter/infrastructure/auth/auth_repository.dart'
    as _i617;
import 'package:pocketcoder_flutter/infrastructure/auth/linode_oauth_service.dart'
    as _i383;
import 'package:pocketcoder_flutter/infrastructure/cloud_provider/linode_api_client.dart'
    as _i995;
import 'package:pocketcoder_flutter/infrastructure/communication/communication_daos.dart'
    as _i464;
import 'package:pocketcoder_flutter/infrastructure/communication/communication_repository.dart'
    as _i728;
import 'package:pocketcoder_flutter/infrastructure/core/api_client.dart'
    as _i589;
import 'package:pocketcoder_flutter/infrastructure/core/auth_store.dart'
    as _i520;
import 'package:pocketcoder_flutter/infrastructure/core/external_module.dart'
    as _i1059;
import 'package:pocketcoder_flutter/infrastructure/deployment/deployment_service.dart'
    as _i262;
import 'package:pocketcoder_flutter/infrastructure/evolution/evolution_daos.dart'
    as _i197;
import 'package:pocketcoder_flutter/infrastructure/evolution/evolution_repository.dart'
    as _i379;
import 'package:pocketcoder_flutter/infrastructure/feedback/exception_mapper.dart'
    as _i976;
import 'package:pocketcoder_flutter/infrastructure/feedback/feedback_service.dart'
    as _i214;
import 'package:pocketcoder_flutter/infrastructure/feedback/loading_service.dart'
    as _i976;
import 'package:pocketcoder_flutter/infrastructure/feedback/localization_service.dart'
    as _i1000;
import 'package:pocketcoder_flutter/infrastructure/healthcheck/healthcheck_repository.dart'
    as _i40;
import 'package:pocketcoder_flutter/infrastructure/hitl/hitl_daos.dart'
    as _i658;
import 'package:pocketcoder_flutter/infrastructure/hitl/hitl_repository.dart'
    as _i441;
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart' as _i444;
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_repository.dart'
    as _i662;
import 'package:pocketcoder_flutter/infrastructure/notifications/device_daos.dart'
    as _i849;
import 'package:pocketcoder_flutter/infrastructure/notifications/device_repository.dart'
    as _i301;
import 'package:pocketcoder_flutter/infrastructure/observability/observability_repository.dart'
    as _i310;
import 'package:pocketcoder_flutter/infrastructure/security/certificate_manager.dart'
    as _i532;
import 'package:pocketcoder_flutter/infrastructure/security/password_generator.dart'
    as _i765;
import 'package:pocketcoder_flutter/infrastructure/status/status_repository.dart'
    as _i907;
import 'package:pocketcoder_flutter/infrastructure/storage/secure_storage.dart'
    as _i523;
import 'package:pocketcoder_flutter/infrastructure/subagent/subagent_repository.dart'
    as _i186;
import 'package:pocketcoder_flutter/infrastructure/system/health_daos.dart'
    as _i1065;
import 'package:pocketcoder_flutter/infrastructure/system/health_repository.dart'
    as _i700;
import 'package:pocketcoder_flutter/infrastructure/validation/validation_service.dart'
    as _i293;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final externalModule = _$ExternalModule();
    gh.factory<_i677.AuthMessageMapper>(() => _i677.AuthMessageMapper());
    gh.factory<_i883.DeploymentMessageMapper>(
        () => _i883.DeploymentMessageMapper());
    gh.singleton<_i704.ThemeService>(() => _i704.ThemeService());
    await gh.singletonAsync<_i824.PocketBase>(
      () => externalModule.pocketBase,
      preResolve: true,
    );
    gh.singleton<_i520.AuthStoreConfig>(() => externalModule.authStoreConfig);
    gh.singleton<_i558.FlutterSecureStorage>(
        () => externalModule.flutterSecureStorage);
    gh.singleton<_i796.AppConfig>(() => externalModule.appConfig);
    gh.lazySingleton<_i992.PocoCubit>(() => _i992.PocoCubit());
    gh.lazySingleton<_i519.Client>(() => externalModule.httpClient);
    gh.lazySingleton<_i598.ISecureStorage>(
        () => _i523.SecureStorage(storage: gh<_i558.FlutterSecureStorage>()));
    gh.lazySingleton<_i980.ICertificateManager>(
        () => _i532.CertificateManager(gh<_i598.ISecureStorage>()));
    gh.factory<_i1000.SshTerminalCubit>(
        () => _i1000.SshTerminalCubit(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i589.PocketCoderApi>(
        () => _i589.PocketCoderApi(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i611.IObservabilityRepository>(
        () => _i310.ObservabilityRepository(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i190.IStatusRepository>(
        () => _i907.StatusRepository(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i623.IHealthcheckRepository>(
        () => _i40.HealthcheckRepository(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i653.IExceptionKeyMapper>(
        () => _i976.AppExceptionKeyMapper());
    gh.lazySingleton<_i780.IPasswordGenerator>(() => _i765.PasswordGenerator());
    gh.lazySingleton<_i653.IFeedbackService>(() => _i214.AppFeedbackService());
    gh.lazySingleton<_i653.ILoadingService>(() => _i976.AppLoadingService());
    gh.factory<_i304.BillingCubit>(
        () => _i304.BillingCubit(gh<_i619.BillingService>()));
    gh.lazySingleton<_i653.ILocalizationService>(
        () => _i1000.AppLocalizationService());
    gh.lazySingleton<_i843.IValidationService>(() => _i293.ValidationService());
    gh.lazySingleton<_i589.UserDao>(
        () => _i589.UserDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i589.SshKeyDao>(
        () => _i589.SshKeyDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i658.PermissionDao>(
        () => _i658.PermissionDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i658.WhitelistTargetDao>(
        () => _i658.WhitelistTargetDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i658.WhitelistActionDao>(
        () => _i658.WhitelistActionDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i444.McpServerDao>(
        () => _i444.McpServerDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i1065.HealthcheckDao>(
        () => _i1065.HealthcheckDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i197.ProposalDao>(
        () => _i197.ProposalDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i197.SopDao>(() => _i197.SopDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i61.AiAgentDao>(
        () => _i61.AiAgentDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i61.AiPromptDao>(
        () => _i61.AiPromptDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i61.AiModelDao>(
        () => _i61.AiModelDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i61.SubagentDao>(
        () => _i61.SubagentDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i464.ChatDao>(
        () => _i464.ChatDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i464.MessageDao>(
        () => _i464.MessageDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i464.SubagentDao>(
        () => _i464.SubagentDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i849.DeviceDao>(
        () => _i849.DeviceDao(gh<_i169.PocketBase>()));
    gh.factory<_i273.ObservabilityCubit>(
        () => _i273.ObservabilityCubit(gh<_i611.IObservabilityRepository>()));
    gh.singleton<String>(
      () => externalModule.linodeClientId,
      instanceName: 'linodeClientId',
    );
    gh.lazySingleton<_i20.IHitlRepository>(() => _i441.HitlRepository(
          gh<_i658.PermissionDao>(),
          gh<_i658.WhitelistTargetDao>(),
          gh<_i658.WhitelistActionDao>(),
          gh<_i589.PocketCoderApi>(),
        ));
    gh.lazySingleton<_i148.IDeviceRepository>(() => _i301.DeviceRepository(
          gh<_i849.DeviceDao>(),
          gh<_i169.PocketBase>(),
        ));
    gh.lazySingleton<_i656.IEvolutionRepository>(
        () => _i379.EvolutionRepository(
              gh<_i197.ProposalDao>(),
              gh<_i197.SopDao>(),
            ));
    gh.lazySingleton<_i922.IMcpRepository>(
        () => _i662.McpRepository(gh<_i444.McpServerDao>()));
    gh.factory<_i252.SopCubit>(
        () => _i252.SopCubit(gh<_i656.IEvolutionRepository>()));
    gh.lazySingleton<_i322.ISubagentRepository>(
        () => _i186.SubagentRepository(gh<_i464.SubagentDao>()));
    gh.factory<_i328.McpCubit>(
        () => _i328.McpCubit(gh<_i922.IMcpRepository>()));
    gh.lazySingleton<_i50.IAuthRepository>(() => _i617.AuthRepository(
          gh<_i824.PocketBase>(),
          gh<_i520.AuthStoreConfig>(),
          gh<_i589.UserDao>(),
          gh<_i589.SshKeyDao>(),
        ));
    gh.lazySingleton<_i800.IHealthRepository>(
        () => _i700.HealthRepository(gh<_i1065.HealthcheckDao>()));
    gh.lazySingleton<_i536.IAiConfigRepository>(() => _i846.AiConfigRepository(
          gh<_i61.AiAgentDao>(),
          gh<_i61.AiPromptDao>(),
          gh<_i61.AiModelDao>(),
          gh<_i61.SubagentDao>(),
        ));
    gh.lazySingleton<_i240.ICloudProviderAPIClient>(() => _i995.LinodeAPIClient(
          gh<_i519.Client>(),
          gh<String>(instanceName: 'linodeClientId'),
        ));
    gh.lazySingleton<_i205.IOAuthService>(() => _i383.LinodeOAuthService(
          gh<_i598.ISecureStorage>(),
          gh<_i240.ICloudProviderAPIClient>(),
          gh<String>(instanceName: 'linodeClientId'),
        ));
    gh.factory<_i528.WhitelistCubit>(
        () => _i528.WhitelistCubit(gh<_i20.IHitlRepository>()));
    gh.factory<_i955.PermissionCubit>(
        () => _i955.PermissionCubit(gh<_i20.IHitlRepository>()));
    gh.lazySingleton<_i565.IDeploymentService>(() => _i262.DeploymentService(
          apiClient: gh<_i240.ICloudProviderAPIClient>(),
          certManager: gh<_i980.ICertificateManager>(),
          passwordGenerator: gh<_i780.IPasswordGenerator>(),
          secureStorage: gh<_i598.ISecureStorage>(),
          validationService: gh<_i843.IValidationService>(),
        ));
    gh.factory<_i938.AuthCubit>(() => _i938.AuthCubit(
          gh<_i205.IOAuthService>(),
          gh<_i598.ISecureStorage>(),
        ));
    gh.factory<_i464.AuthCubit>(
        () => _i464.AuthCubit(gh<_i50.IAuthRepository>()));
    gh.factory<_i440.SubagentCubit>(
        () => _i440.SubagentCubit(gh<_i322.ISubagentRepository>()));
    gh.factory<_i816.ConfigCubit>(() => _i816.ConfigCubit(
          gh<_i843.IValidationService>(),
          gh<_i240.ICloudProviderAPIClient>(),
          gh<_i598.ISecureStorage>(),
        ));
    gh.factory<_i616.AiConfigCubit>(
        () => _i616.AiConfigCubit(gh<_i536.IAiConfigRepository>()));
    gh.factory<_i967.HealthCubit>(
        () => _i967.HealthCubit(gh<_i800.IHealthRepository>()));
    gh.factory<_i506.StatusCubit>(
        () => _i506.StatusCubit(gh<_i50.IAuthRepository>()));
    gh.factory<_i332.DeploymentCubit>(
        () => _i332.DeploymentCubit(gh<_i565.IDeploymentService>()));
    gh.lazySingleton<_i215.ICommunicationRepository>(
        () => _i728.CommunicationRepository(
              gh<_i464.ChatDao>(),
              gh<_i464.MessageDao>(),
              gh<_i61.AiAgentDao>(),
              gh<_i50.IAuthRepository>(),
              gh<_i589.PocketCoderApi>(),
            ));
    gh.factory<_i907.CommunicationCubit>(
        () => _i907.CommunicationCubit(gh<_i215.ICommunicationRepository>()));
    return this;
  }
}

class _$ExternalModule extends _i1059.ExternalModule {}
