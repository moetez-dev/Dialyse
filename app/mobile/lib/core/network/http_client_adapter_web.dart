import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Flutter Web: browser must send/receive cookies (sessionid) itself.
/// Manually setting the Cookie header is forbidden by browsers.
void configureHttpClientAdapter(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
