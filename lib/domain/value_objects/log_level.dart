/// Sévérité d'un enregistrement de log.
///
/// Calée sur l'échelle `SeverityNumber` d'OpenTelemetry utilisée par Signoz,
/// pour que l'adapter d'infrastructure n'ait pas à réinventer la traduction :
///
/// | Niveau  | OTel severityNumber | OTel severityText |
/// |---------|--------------------:|-------------------|
/// | debug   | 5                   | DEBUG             |
/// | info    | 9                   | INFO              |
/// | warn    | 13                  | WARN              |
/// | error   | 17                  | ERROR             |
///
/// Volontairement court : pas de besoin de granularité `trace`/`fatal`, et
/// ajouter un niveau plus tard reste une évolution non cassante.
enum LogLevel {
  debug(5, 'DEBUG'),
  info(9, 'INFO'),
  warn(13, 'WARN'),
  error(17, 'ERROR');

  const LogLevel(this.otelSeverityNumber, this.otelSeverityText);

  /// Sévérité numérique OpenTelemetry. Utilisée par l'export OTLP.
  final int otelSeverityNumber;

  /// Sévérité textuelle OpenTelemetry. Affichée telle quelle dans Signoz.
  final String otelSeverityText;
}
