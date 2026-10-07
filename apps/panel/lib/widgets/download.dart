/// Tarayıcıda dosya indirme; testlerde (VM) etkisiz bir sürüm kullanılır.
library;

export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
