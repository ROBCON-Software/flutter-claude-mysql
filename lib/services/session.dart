/// Jednoduchy singleton drziaci info o prihlasenom pouzivatelovi pocas behu appky.
class Session {
  Session._();

  static String? username;

  static void logout() {
    username = null;
  }
}
