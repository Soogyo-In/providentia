enum GoogleDriveMimeType {
  /// Google Docs
  document('application/vnd.google-apps.document'),

  /// Third-party shortcut
  driveSdk('application/vnd.google-apps.drive-sdk'),

  /// Google Drawings
  drawing('application/vnd.google-apps.drawing'),

  /// Google Drive file
  file('application/vnd.google-apps.file'),

  /// Google Drive folder
  folder('application/vnd.google-apps.folder'),

  /// Google Forms
  form('application/vnd.google-apps.form'),

  /// Google Fusion Tables
  fusiontable('application/vnd.google-apps.fusiontable'),

  /// Google Jamboard
  jam('application/vnd.google-apps.jam'),

  /// Email layout
  mailLayout('application/vnd.google-apps.mail-layout'),

  /// Google My Maps
  map('application/vnd.google-apps.map'),

  /// Google Photos
  photo('application/vnd.google-apps.photo'),

  /// Google Slides
  presentation('application/vnd.google-apps.presentation'),

  /// Google Apps Script
  script('application/vnd.google-apps.script'),

  /// Shortcut
  shortcut('application/vnd.google-apps.shortcut'),

  /// Google Sites
  site('application/vnd.google-apps.site'),

  /// Google Sheets
  spreadsheet('application/vnd.google-apps.spreadsheet'),

  /// Google Vids
  vid('application/vnd.google-apps.vid'),
  audio('application/vnd.google-apps.audio'),
  unknown('application/vnd.google-apps.unknown'),
  video('application/vnd.google-apps.video');

  const GoogleDriveMimeType(this.mimeType);

  final String mimeType;
}
