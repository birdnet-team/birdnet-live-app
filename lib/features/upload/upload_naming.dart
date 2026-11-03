// =============================================================================
// Upload Naming — what a destination's folder looks like to the project lead
// =============================================================================
//
// Uploads must read well in a Nextcloud folder listing, and a folder listing
// must never leak or collide on anything a person typed. So paths carry ids
// only, and people live in the metadata:
//
//   .birdnet-live/<deviceCode>.json      one registration per device, hidden
//                                        by Nextcloud's default file list;
//                                        carries the participant identifier
//   <deviceCode>/BirdNET_Live_<start>_#<n>[_<name>].zip
//                                        one ZIP per session, named like the
//                                        Share export it contains; its JSON
//                                        record carries the participant too
//
// `<deviceCode>` is the first eight hex digits of the install's random id,
// shown to the user as "Your upload folder". Two devices sharing a code is a
// one-in-a-million event in a hundred-device project, and even then their
// files differ by start time and session number. Servers that refuse folders
// get the same two files with the path folded into the name:
// `.birdnet-live__<deviceCode>.json` and `<deviceCode>__BirdNET_Live_….zip`.
// =============================================================================

/// Folder that holds device registrations; the leading dot hides it in
/// Nextcloud's default file list.
const String uploadRegistrationFolder = '.birdnet-live';

/// Separator used in place of `/` when the server refuses folders.
const String uploadFlatSeparator = '__';

/// Length of [uploadDeviceCode].
const int uploadDeviceCodeLength = 8;

/// The folder name for [deviceId] (a UUID): its first eight hex digits.
String uploadDeviceCode(String deviceId) {
  final hex = deviceId.replaceAll('-', '').toLowerCase();
  return hex.length > uploadDeviceCodeLength
      ? hex.substring(0, uploadDeviceCodeLength)
      : hex;
}
