// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cubit_ui_flow/cubit_ui_flow.dart' as _i653;
import 'package:flutter_error_privserver/flutter_error_privserver.dart'
    as _i145;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:pocketbase/pocketbase.dart' as _i169;
import 'package:pocketbase_drift/pocketbase_drift.dart' as _i824;
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart'
    as _i1066;
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart'
    as _i710;
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart'
    as _i225;
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart'
    as _i312;
import 'package:pocketcoder_flutter/application/agent_config/agent_config_cubit.dart'
    as _i723;
import 'package:pocketcoder_flutter/application/billing/billing_cubit.dart'
    as _i304;
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart'
    as _i606;
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart'
    as _i110;
import 'package:pocketcoder_flutter/application/files/file_viewer_cubit.dart'
    as _i90;
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart' as _i328;
import 'package:pocketcoder_flutter/application/notifications/notification_rule_cubit.dart'
    as _i921;
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart'
    as _i273;
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart'
    as _i1031;
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart'
    as _i614;
import 'package:pocketcoder_flutter/application/sandbox_agent/sandbox_agent_cubit.dart'
    as _i655;
import 'package:pocketcoder_flutter/application/scheduler/scheduler_cubit.dart'
    as _i490;
import 'package:pocketcoder_flutter/application/skills/skills_cubit.dart'
    as _i67;
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart'
    as _i464;
import 'package:pocketcoder_flutter/application/system/health_cubit.dart'
    as _i967;
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart'
    as _i992;
import 'package:pocketcoder_flutter/application/system/status_cubit.dart'
    as _i506;
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart'
    as _i89;
import 'package:pocketcoder_flutter/design_system/theme/theme_service.dart'
    as _i704;
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart'
    as _i630;
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart' as _i50;
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart'
    as _i619;
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart'
    as _i34;
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart'
    as _i209;
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_accounts_repository.dart'
    as _i255;
import 'package:pocketcoder_flutter/domain/healthcheck/i_healthcheck_repository.dart'
    as _i623;
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart'
    as _i904;
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart' as _i922;
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart'
    as _i148;
import 'package:pocketcoder_flutter/domain/notifications/i_notification_rule_repository.dart'
    as _i821;
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart'
    as _i178;
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart'
    as _i611;
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart'
    as _i422;
import 'package:pocketcoder_flutter/domain/release/i_release_content_service.dart'
    as _i1033;
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart'
    as _i472;
import 'package:pocketcoder_flutter/domain/sandbox_agent/i_sandbox_agent_repository.dart'
    as _i184;
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart'
    as _i470;
import 'package:pocketcoder_flutter/domain/skills/i_skills_repository.dart'
    as _i165;
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart'
    as _i190;
import 'package:pocketcoder_flutter/domain/system/i_health_repository.dart'
    as _i800;
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart'
    as _i767;
import 'package:pocketcoder_flutter/infrastructure/agent/agent_actions_api.dart'
    as _i300;
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart'
    as _i763;
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart'
    as _i313;
import 'package:pocketcoder_flutter/infrastructure/agent/cache/agent_cache_db.dart'
    as _i619;
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart'
    as _i810;
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_repository.dart'
    as _i857;
import 'package:pocketcoder_flutter/infrastructure/auth/auth_repository.dart'
    as _i617;
import 'package:pocketcoder_flutter/infrastructure/chat/chat_dao.dart' as _i199;
import 'package:pocketcoder_flutter/infrastructure/chat/chat_list_repository.dart'
    as _i849;
import 'package:pocketcoder_flutter/infrastructure/communication/communication_daos.dart'
    as _i464;
import 'package:pocketcoder_flutter/infrastructure/core/auth_store.dart'
    as _i520;
import 'package:pocketcoder_flutter/infrastructure/core/external_module.dart'
    as _i1059;
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart'
    as _i935;
import 'package:pocketcoder_flutter/infrastructure/feedback/exception_mapper.dart'
    as _i976;
import 'package:pocketcoder_flutter/infrastructure/feedback/feedback_service.dart'
    as _i214;
import 'package:pocketcoder_flutter/infrastructure/feedback/loading_service.dart'
    as _i976;
import 'package:pocketcoder_flutter/infrastructure/feedback/localization_service.dart'
    as _i1000;
import 'package:pocketcoder_flutter/infrastructure/files/files_repository.dart'
    as _i369;
import 'package:pocketcoder_flutter/infrastructure/git/git_ssh_daos.dart'
    as _i920;
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_account_daos.dart'
    as _i730;
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_accounts_repository.dart'
    as _i467;
import 'package:pocketcoder_flutter/infrastructure/healthcheck/healthcheck_repository.dart'
    as _i40;
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart' as _i444;
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_oauth_service.dart'
    as _i732;
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_repository.dart'
    as _i662;
import 'package:pocketcoder_flutter/infrastructure/notifications/device_daos.dart'
    as _i849;
import 'package:pocketcoder_flutter/infrastructure/notifications/device_repository.dart'
    as _i301;
import 'package:pocketcoder_flutter/infrastructure/notifications/notification_rule_daos.dart'
    as _i870;
import 'package:pocketcoder_flutter/infrastructure/notifications/notification_rule_repository.dart'
    as _i821;
import 'package:pocketcoder_flutter/infrastructure/observability/observability_repository.dart'
    as _i310;
import 'package:pocketcoder_flutter/infrastructure/ollama/ollama_api.dart'
    as _i810;
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart'
    as _i294;
import 'package:pocketcoder_flutter/infrastructure/provider/provider_repository.dart'
    as _i549;
import 'package:pocketcoder_flutter/infrastructure/release/release_content_service.dart'
    as _i456;
import 'package:pocketcoder_flutter/infrastructure/release/server_release_status_service.dart'
    as _i175;
import 'package:pocketcoder_flutter/infrastructure/sandbox_agent/sandbox_agent_repository.dart'
    as _i853;
import 'package:pocketcoder_flutter/infrastructure/scheduler/schedule_owner_dao.dart'
    as _i479;
import 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart'
    as _i715;
import 'package:pocketcoder_flutter/infrastructure/skills/skill_dao.dart'
    as _i9;
import 'package:pocketcoder_flutter/infrastructure/skills/skills_repository.dart'
    as _i675;
import 'package:pocketcoder_flutter/infrastructure/status/status_repository.dart'
    as _i907;
import 'package:pocketcoder_flutter/infrastructure/system/health_daos.dart'
    as _i1065;
import 'package:pocketcoder_flutter/infrastructure/system/health_repository.dart'
    as _i700;
import 'package:pocketcoder_flutter/infrastructure/tool_permissions/tool_permission_daos.dart'
    as _i398;
import 'package:pocketcoder_flutter/infrastructure/tool_permissions/tool_permission_repository.dart'
    as _i220;

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
    gh.singleton<_i704.ThemeService>(() => _i704.ThemeService());
    await gh.singletonAsync<_i824.PocketBase>(
      () => externalModule.pocketBase,
      preResolve: true,
    );
    gh.singleton<_i520.AuthStoreConfig>(() => externalModule.authStoreConfig);
    gh.singleton<_i558.FlutterSecureStorage>(
        () => externalModule.flutterSecureStorage);
    gh.lazySingleton<_i992.PocoCubit>(() => _i992.PocoCubit());
    gh.lazySingleton<_i619.AgentCacheDb>(() => _i619.AgentCacheDb());
    gh.lazySingleton<_i519.Client>(() => externalModule.httpClient);
    gh.lazySingleton<_i145.ErrorBoxStorage>(
        () => externalModule.errorBoxStorage);
    gh.lazySingleton<_i935.PocketCoderApiClient>(
        () => externalModule.pocketCoderApiClient(gh<_i824.PocketBase>()));
    gh.lazySingleton<_i611.IObservabilityRepository>(
        () => _i310.ObservabilityRepository(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i623.IHealthcheckRepository>(
        () => _i40.HealthcheckRepository(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i653.IExceptionKeyMapper>(
        () => _i976.AppExceptionKeyMapper());
    gh.lazySingleton<_i653.IFeedbackService>(() => _i214.AppFeedbackService());
    gh.lazySingleton<String>(
      () => externalModule.oauthRelayBaseUrl,
      instanceName: 'oauthRelayBaseUrl',
    );
    gh.lazySingleton<_i50.IAuthRepository>(() => _i617.AuthRepository(
          gh<_i824.PocketBase>(),
          gh<_i520.AuthStoreConfig>(),
          gh<_i558.FlutterSecureStorage>(),
          gh<_i619.BillingService>(),
          gh<_i178.PushService>(),
          gh<_i935.PocketCoderApiClient>(),
        ));
    gh.lazySingleton<_i653.ILoadingService>(() => _i976.AppLoadingService());
    gh.lazySingleton<_i810.OllamaApi>(() => _i810.OllamaApi(
          gh<_i169.PocketBase>(),
          gh<_i519.Client>(),
          gh<_i935.PocketCoderApiClient>(),
        ));
    gh.lazySingleton<String>(
      () => externalModule.releaseBaseUrl,
      instanceName: 'releaseBaseUrl',
    );
    gh.factory<_i304.BillingCubit>(
        () => _i304.BillingCubit(gh<_i619.BillingService>()));
    gh.lazySingleton<_i653.ILocalizationService>(
        () => _i1000.AppLocalizationService());
    gh.lazySingleton<_i810.PocoConfigDao>(
        () => _i810.PocoConfigDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i810.PromptDao>(
        () => _i810.PromptDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i199.ChatDao>(
        () => _i199.ChatDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i464.SandboxAgentDao>(
        () => _i464.SandboxAgentDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i920.GitSshCredentialDao>(
        () => _i920.GitSshCredentialDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i920.GitRepositoryAccessDao>(
        () => _i920.GitRepositoryAccessDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i730.HarnessAccountDao>(
        () => _i730.HarnessAccountDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i730.HarnessAccountSelectionDao>(
        () => _i730.HarnessAccountSelectionDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i444.McpServerDao>(
        () => _i444.McpServerDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i849.DeviceDao>(
        () => _i849.DeviceDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i870.NotificationRuleDao>(
        () => _i870.NotificationRuleDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i294.HarnesseDao>(
        () => _i294.HarnesseDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i294.ModelDao>(
        () => _i294.ModelDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i294.HarnessModelDao>(
        () => _i294.HarnessModelDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i294.ProviderKeyDao>(
        () => _i294.ProviderKeyDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i479.ScheduleOwnerDao>(
        () => _i479.ScheduleOwnerDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i9.SkillDao>(() => _i9.SkillDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i1065.HealthcheckDao>(
        () => _i1065.HealthcheckDao(gh<_i169.PocketBase>()));
    gh.lazySingleton<_i398.ToolPermissionDao>(
        () => _i398.ToolPermissionDao(gh<_i169.PocketBase>()));
    gh.factory<_i273.ObservabilityCubit>(
        () => _i273.ObservabilityCubit(gh<_i611.IObservabilityRepository>()));
    gh.lazySingleton<_i148.IDeviceRepository>(() => _i301.DeviceRepository(
          gh<_i849.DeviceDao>(),
          gh<_i169.PocketBase>(),
        ));
    gh.factory<_i464.AuthCubit>(
        () => _i464.AuthCubit(gh<_i50.IAuthRepository>()));
    gh.lazySingleton<_i767.IToolPermissionRepository>(
        () => _i220.ToolPermissionRepository(gh<_i398.ToolPermissionDao>()));
    gh.lazySingleton<_i821.INotificationRuleRepository>(
        () => _i821.NotificationRuleRepository(
              gh<_i870.NotificationRuleDao>(),
              gh<_i169.PocketBase>(),
            ));
    gh.factory<_i921.NotificationRuleCubit>(() =>
        _i921.NotificationRuleCubit(gh<_i821.INotificationRuleRepository>()));
    gh.lazySingleton<_i922.IMcpRepository>(() => _i662.McpRepository(
          gh<_i444.McpServerDao>(),
          gh<_i935.PocketCoderApiClient>(),
        ));
    gh.lazySingleton<_i34.IChatListRepository>(() => _i849.ChatListRepository(
          gh<_i199.ChatDao>(),
          gh<_i50.IAuthRepository>(),
        ));
    gh.lazySingleton<_i472.IServerReleaseStatusService>(
        () => _i175.ServerReleaseStatusService(
              gh<_i824.PocketBase>(),
              gh<_i935.PocketCoderApiClient>(),
            ));
    gh.lazySingleton<_i313.AgentStreamClient>(() => _i313.AgentStreamClient(
          pocketBase: gh<_i169.PocketBase>(),
          httpClient: gh<_i519.Client>(),
        ));
    gh.lazySingleton<_i300.AgentActionsApi>(
        () => _i300.AgentActionsApi(gh<_i935.PocketCoderApiClient>()));
    gh.lazySingleton<_i209.IFilesRepository>(
        () => _i369.FilesRepository(gh<_i935.PocketCoderApiClient>()));
    gh.lazySingleton<_i630.IAgentConfigRepository>(
        () => _i857.AgentConfigRepository(
              gh<_i810.PocoConfigDao>(),
              gh<_i810.PromptDao>(),
            ));
    gh.lazySingleton<_i904.IMcpOAuthService>(() => _i732.McpOAuthService(
          gh<_i519.Client>(),
          gh<String>(instanceName: 'oauthRelayBaseUrl'),
        ));
    gh.factory<_i506.StatusCubit>(
        () => _i506.StatusCubit(gh<_i50.IAuthRepository>()));
    gh.lazySingleton<_i190.IStatusRepository>(
        () => _i907.StatusRepository(gh<_i824.PocketBase>()));
    gh.lazySingleton<_i1033.IReleaseContentService>(
        () => _i456.ReleaseContentService(
              gh<_i519.Client>(),
              gh<_i558.FlutterSecureStorage>(),
              gh<String>(instanceName: 'releaseBaseUrl'),
            ));
    gh.lazySingleton<_i422.IProviderRepository>(() => _i549.ProviderRepository(
          gh<_i294.HarnesseDao>(),
          gh<_i294.ModelDao>(),
          gh<_i294.HarnessModelDao>(),
          gh<_i294.ProviderKeyDao>(),
        ));
    gh.lazySingleton<_i800.IHealthRepository>(
        () => _i700.HealthRepository(gh<_i1065.HealthcheckDao>()));
    gh.factory<_i89.ToolPermissionsCubit>(
        () => _i89.ToolPermissionsCubit(gh<_i767.IToolPermissionRepository>()));
    gh.factory<_i328.McpCubit>(() => _i328.McpCubit(
          gh<_i922.IMcpRepository>(),
          gh<_i904.IMcpOAuthService>(),
        ));
    gh.lazySingleton<_i255.IHarnessAccountsRepository>(
        () => _i467.HarnessAccountsRepository(
              gh<_i730.HarnessAccountDao>(),
              gh<_i730.HarnessAccountSelectionDao>(),
            ));
    gh.factory<_i723.AgentConfigCubit>(
        () => _i723.AgentConfigCubit(gh<_i630.IAgentConfigRepository>()));
    gh.lazySingleton<_i184.ISandboxAgentRepository>(
        () => _i853.SandboxAgentRepository(gh<_i464.SandboxAgentDao>()));
    gh.factory<_i614.ReleaseStatusCubit>(() =>
        _i614.ReleaseStatusCubit(gh<_i472.IServerReleaseStatusService>()));
    gh.lazySingleton<_i470.ISchedulerRepository>(
        () => _i715.SchedulerRepository(
              gh<_i935.PocketCoderApiClient>(),
              gh<_i479.ScheduleOwnerDao>(),
            ));
    gh.lazySingleton<_i165.ISkillsRepository>(
        () => _i675.SkillsRepository(gh<_i9.SkillDao>()));
    gh.factory<_i67.SkillsCubit>(() => _i67.SkillsCubit(
          gh<_i165.ISkillsRepository>(),
          gh<_i630.IAgentConfigRepository>(),
        ));
    gh.factory<_i655.SandboxAgentCubit>(
        () => _i655.SandboxAgentCubit(gh<_i184.ISandboxAgentRepository>()));
    gh.factory<_i110.FileBrowserCubit>(
        () => _i110.FileBrowserCubit(gh<_i209.IFilesRepository>()));
    gh.factory<_i90.FileViewerCubit>(
        () => _i90.FileViewerCubit(gh<_i209.IFilesRepository>()));
    gh.lazySingleton<_i763.AgentChatRepository>(() => _i763.AgentChatRepository(
          gh<_i313.AgentStreamClient>(),
          gh<_i619.AgentCacheDb>(),
          gh<_i300.AgentActionsApi>(),
        ));
    gh.factory<_i1031.ProviderCubit>(
        () => _i1031.ProviderCubit(gh<_i422.IProviderRepository>()));
    gh.factory<_i606.ChatListCubit>(
        () => _i606.ChatListCubit(gh<_i34.IChatListRepository>()));
    gh.factory<_i967.HealthCubit>(
        () => _i967.HealthCubit(gh<_i800.IHealthRepository>()));
    gh.factory<_i1066.ChatCubit>(
        () => _i1066.ChatCubit(gh<_i763.AgentChatRepository>()));
    gh.factory<_i710.ElicitationCubit>(
        () => _i710.ElicitationCubit(gh<_i763.AgentChatRepository>()));
    gh.factory<_i225.PermissionCubit>(
        () => _i225.PermissionCubit(gh<_i763.AgentChatRepository>()));
    gh.factory<_i312.SessionControlsCubit>(
        () => _i312.SessionControlsCubit(gh<_i763.AgentChatRepository>()));
    gh.factory<_i490.SchedulerCubit>(
        () => _i490.SchedulerCubit(gh<_i470.ISchedulerRepository>()));
    return this;
  }
}

class _$ExternalModule extends _i1059.ExternalModule {}
