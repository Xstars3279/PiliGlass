import 'package:PiliPlus/models/common/enum_with_label.dart';

enum MineTabType implements EnumWithLabel {
  favorite('我的收藏'),
  history('观看记录'),
  later('稍后再看'),
  sub('我的订阅'),
  download('我的下载');

  static const Set<MineTabType> kDefault = {
    .favorite,
    .history,
    .later,
    .sub,
    .download,
  };

  @override
  final String label;

  const MineTabType(this.label);
}
