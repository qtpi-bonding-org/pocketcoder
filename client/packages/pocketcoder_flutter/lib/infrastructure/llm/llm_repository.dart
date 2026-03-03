import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/llm/i_llm_repository.dart';
import 'package:pocketcoder_flutter/domain/models/llm_key.dart';
import 'package:pocketcoder_flutter/domain/models/model_selection.dart';
import 'package:pocketcoder_flutter/domain/models/llm_provider.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import 'package:flutter_aeroform/core/try_operation.dart';
import 'llm_daos.dart';

@LazySingleton(as: ILlmRepository)
class LlmRepository implements ILlmRepository {
  final LlmKeyDao _keyDao;
  final ModelSelectionDao _configDao;
  final LlmProviderDao _providerDao;

  LlmRepository(this._keyDao, this._configDao, this._providerDao);

  // --- Keys ---

  @override
  Stream<List<LlmKey>> watchKeys() {
    return _keyDao.watch();
  }

  @override
  Future<void> saveKey(String providerId, Map<String, dynamic> envVars) async {
    return tryMethod(
      () async {
        await _keyDao.save(null, {
          'provider_id': providerId,
          'env_vars': envVars,
        });
      },
      LlmException.new,
      'saveKey',
    );
  }

  @override
  Future<void> deleteKey(String id) async {
    return tryMethod(
      () async {
        await _keyDao.delete(id);
      },
      LlmException.new,
      'deleteKey',
    );
  }

  // --- Providers ---

  @override
  Stream<List<LlmProvider>> watchProviders() {
    return _providerDao.watch(sort: 'name');
  }

  // --- Model Selection ---

  @override
  Stream<List<ModelSelection>> watchConfig() {
    return _configDao.watch();
  }

  @override
  Future<void> setModel(String model, {String? chat}) async {
    return tryMethod(
      () async {
        await _configDao.save(null, {
          'model': model,
          if (chat != null) 'chat': chat,
        });
      },
      LlmException.new,
      'setModel',
    );
  }
}
