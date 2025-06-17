import 'dart:convert';

const projectId = String.fromEnvironment('GCP_PROJECT_ID');
final credentials = utf8.decode(
  base64.decode(
    String.fromEnvironment('GOOGLE_APPLICATION_CREDENTIALS_BASE64'),
  ),
);
const serviceUrl = String.fromEnvironment('SERVICE_URL');
const googleDriveChannelToken = String.fromEnvironment(
  'GOOGLE_DRIVE_CHANNEL_TOKEN',
);
