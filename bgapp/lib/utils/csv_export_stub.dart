/// Stub for non-web platforms. 
/// On mobile/desktop, you could use path_provider + share instead.
void downloadCsv(String csvContent, String filename) {
  throw UnsupportedError('CSV download is only supported on web.');
}
