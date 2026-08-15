class RouteUtils {
  RouteUtils._();

  static String getInitialRoute(String? userId) {
    return userId != null ? '/home' : '/login';
  }

  static String getRouteName(String feature) {
    return '/$feature';
  }
}