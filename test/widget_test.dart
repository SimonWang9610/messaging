// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:messaging/utils/store.dart';

void main() {
  test("GetStore container", () async {
    const first = "TzWi21xBmrL8VpstcZud";
    const second = "Y8C4TmFks3cWjzzOsTkK";

    await LocalStorage.init(first);

    LocalStorage.write("first", 1);

    expect(LocalStorage.read("first") as int, 1);
    expect(LocalStorage.read("userId", useGlobal: true) as String, first);

    await LocalStorage.init(second);

    LocalStorage.write("second", 2);

    expect(LocalStorage.read("second") as int, 2);
    expect(LocalStorage.read("userId", useGlobal: true) as String, second);

    await LocalStorage.init(first);

    expect(LocalStorage.read("first") as int, 1);

    LocalStorage.clear();
  });
}
