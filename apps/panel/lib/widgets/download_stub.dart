/// Tarayıcı dışı ortamlarda (testler) son indirilen dosyayı saklar.
String? lastDownloadName;
String? lastDownloadContent;

void downloadText(String filename, String content, {String mime = 'text/csv'}) {
  lastDownloadName = filename;
  lastDownloadContent = content;
}
