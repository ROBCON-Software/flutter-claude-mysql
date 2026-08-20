class AppConfig {
  static const String lanIp = '192.168.23.200';
  static const int lanPort = 80;

  static const String wanIp = '195.80.183.109';
  static const int wanPort = 25001;

  static const bool useWan = true;

  static String get baseUrl {
    final ip = useWan ? wanIp : lanIp;
    final port = useWan ? wanPort : lanPort;
    final portPart = port == 80 ? '' : ':$port';
    return 'http://$ip$portPart/backend_php';
  }
}
