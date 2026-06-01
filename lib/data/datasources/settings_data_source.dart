import '../models/app_settings.dart';

abstract class ISettingsDataSource {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
