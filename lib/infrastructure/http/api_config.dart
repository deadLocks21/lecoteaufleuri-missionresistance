/// Base d'API du backend, partagée par **tous** les adapters réseau de l'app
/// (login, radio, scénario, émissions) **et le suivi GPS** (isolate de fond).
///
/// On privilégie `API_BASE_URL` ; à défaut on retombe sur `TRACKING_API_URL`
/// (rétro-compat) pour ne garder **qu'une seule URL** à définir au build.
/// Constante de compilation → lisible dans n'importe quel isolate.
///
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
///
/// **Vide → pas de backend** : l'app sert le jumeau de démo (`InMemoryAuth`,
/// code `6450` → `LES RENARDS`).
library;

const String kApiBaseUrl = bool.hasEnvironment('API_BASE_URL')
    ? String.fromEnvironment('API_BASE_URL')
    : String.fromEnvironment('TRACKING_API_URL');
