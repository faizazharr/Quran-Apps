import '../../core/result/result.dart';
import '../datasources/settings_data_source.dart';
import '../models/app_settings.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements ISettingsRepository {
  final ISettingsDataSource _local;

  SettingsRepositoryImpl(this._local);

  @override
  Future<Result<AppSettings>> load() => runCatching(() => _local.load());

  @override
  Future<Result<void>> save(AppSettings settings) =>
      runCatching(() => _local.save(settings));
}
