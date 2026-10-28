// =============================================================================
// Upload Messages — one sentence per probe failure and warning
// =============================================================================

import 'package:birdnet_live/l10n/app_localizations.dart';

import 'upload_service.dart';
import 'webdav_probe.dart';

/// The sentence shown for a failed [ProbeResult].
String probeFailureMessage(AppLocalizations l10n, ProbeResult result) {
  switch (result.failure) {
    case ProbeFailure.invalidUrl:
      return l10n.uploadProbeInvalidUrl;
    case ProbeFailure.insecureHttp:
      return l10n.uploadProbeInsecureHttp;
    case ProbeFailure.hostNotFound:
      return l10n.uploadProbeHostNotFound;
    case ProbeFailure.tlsFailure:
      return l10n.uploadProbeTlsFailure;
    case ProbeFailure.connectionFailed:
      return l10n.uploadProbeConnectionFailed;
    case ProbeFailure.timeout:
      return l10n.uploadProbeTimeout;
    case ProbeFailure.unauthorized:
      return l10n.uploadProbeUnauthorized;
    case ProbeFailure.notWebDav:
      return l10n.uploadProbeNotWebDav;
    case ProbeFailure.uploadForbidden:
      return l10n.uploadProbeUploadForbidden;
    case ProbeFailure.notFound:
      return l10n.uploadProbeNotFound;
    case ProbeFailure.quotaExceeded:
      return l10n.uploadProbeQuotaExceeded;
    case ProbeFailure.serverError:
      return l10n.uploadProbeServerError(result.statusCode ?? 0);
    case null:
      return l10n.uploadJoinSuccess;
  }
}

/// The sentence shown for an [UploadJob.lastError] code.
String uploadErrorMessage(AppLocalizations l10n, String code) {
  switch (code) {
    case UploadErrorCode.offline:
      return l10n.uploadStatusOffline;
    case UploadErrorCode.waitingForWifi:
      return l10n.uploadStatusWaitingForWifi;
    case UploadErrorCode.unauthorized:
      return l10n.uploadProbeUnauthorized;
    case UploadErrorCode.forbidden:
      return l10n.uploadProbeUploadForbidden;
    case UploadErrorCode.quota:
      return l10n.uploadProbeQuotaExceeded;
    case UploadErrorCode.server:
      return l10n.uploadErrorServer;
    case UploadErrorCode.network:
      return l10n.uploadErrorNetwork;
    case UploadErrorCode.exportFailed:
      return l10n.uploadErrorExport;
    case UploadErrorCode.destinationMissing:
      return l10n.uploadErrorDestinationMissing;
    case UploadErrorCode.secretMissing:
      return l10n.uploadDestinationSecretMissing;
    case UploadErrorCode.sessionMissing:
      return l10n.uploadErrorSessionMissing;
    default:
      return l10n.uploadErrorNetwork;
  }
}

/// The sentence shown for a [ProbeWarning].
String probeWarningMessage(AppLocalizations l10n, ProbeWarning warning) {
  switch (warning) {
    case ProbeWarning.canReadRemote:
      return l10n.uploadWarnCanReadRemote;
    case ProbeWarning.shareWithoutPassword:
      return l10n.uploadWarnShareWithoutPassword;
    case ProbeWarning.insecureLan:
      return l10n.uploadWarnInsecureLan;
  }
}
