import 'package:flutter/foundation.dart';

/// Số lần phải dựng lại toàn bộ trạng thái ứng dụng (đăng xuất, phiên hết hạn).
///
/// `main.dart` gắn khóa của `ProviderScope` vào giá trị này, nên mỗi lần tăng thì mọi provider
/// (hồ sơ, feed, bạn bè, chat, cache trong bộ nhớ...) bị hủy và dựng lại từ đầu. Nhờ vậy không
/// có dữ liệu của tài khoản cũ sót lại khi đăng nhập tài khoản khác trên cùng thiết bị.
final ValueNotifier<int> sessionEpoch = ValueNotifier<int>(0);

void resetAppSession() => sessionEpoch.value++;
