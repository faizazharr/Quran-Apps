import '../../core/result/result.dart';
import '../models/app_settings.dart';

abstract class ISettingsRepository {
  Future<Result<AppSettings>> load();
  Future<Result<void>> save(AppSettings settings);
}
