/// Appel du QG. Ouvre le composeur du téléphone (ne compose jamais en silence,
/// cf. ARCHITECTURE §12).
abstract interface class DialerPort {
  Future<void> callHq();
}
