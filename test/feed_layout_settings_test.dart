import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserSetting setting;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    setting = UserSetting()..prefs = prefs;
  });

  test('feed layout defaults and selected dimensions are persisted', () async {
    expect(setting.feedRows, 1);
    expect(setting.feedColumns, 2);

    await setting.setFeedRows(4);
    await setting.setFeedColumns(3);
    await prefs.reload();

    expect(setting.feedRows, 4);
    expect(setting.feedColumns, 3);
    expect(prefs.getInt('feed_rows'), 4);
    expect(prefs.getInt('feed_columns'), 3);
  });

  test('feed dimensions persist only values within one to four', () async {
    await setting.setFeedRows(0);
    await setting.setFeedColumns(5);
    await prefs.reload();

    expect(setting.feedRows, 1);
    expect(setting.feedColumns, 4);
    expect(prefs.getInt('feed_rows'), 1);
    expect(prefs.getInt('feed_columns'), 4);

    await setting.setFeedRows(5);
    await setting.setFeedColumns(0);
    await prefs.reload();

    expect(setting.feedRows, 4);
    expect(setting.feedColumns, 1);
    expect(prefs.getInt('feed_rows'), 4);
    expect(prefs.getInt('feed_columns'), 1);
  });
}
