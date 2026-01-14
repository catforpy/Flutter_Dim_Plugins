/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */

import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';
// import 'package:get/get.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../models/chat.dart';
import '../models/chat_contact.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'table.dart';
import 'title.dart';

/// 成员选择回调函数类型
/// [members] - 选中的成员ID集合
typedef MemberPickerCallback = void Function(Set<ID> members);

/// 成员选择器组件
/// 用于选择聊天/群组参与者，支持字母分类、多选、返回选中结果
class MemberPicker extends StatefulWidget {
  /// 构造函数
  /// [candidates] - 可选成员ID集合
  /// [onPicked] - 选择完成回调
  const MemberPicker(this.candidates, {super.key, required this.onPicked});

  /// 可选成员ID集合
  final Set<ID> candidates;
  /// 选择完成回调
  final MemberPickerCallback onPicked;

  /// 打开成员选择器页面
  /// [context] - 上下文
  /// [candidates] - 可选成员ID集合
  /// [onPicked] - 选择完成回调
  static void open(BuildContext context, Set<ID> candidates, {required MemberPickerCallback onPicked}) =>
      appTool.showPage(
        context: context,
        builder: (context) => MemberPicker(candidates, onPicked: onPicked),
      );

  /// 创建状态对象
  @override
  State<StatefulWidget> createState() => _MemberPickerState();

}

/// 成员选择器状态类
class _MemberPickerState extends State<MemberPicker> {
  /// 构造函数：初始化数据源和适配器
  _MemberPickerState() {
    _dataSource = _ContactDataSource();
    _adapter = _ContactListAdapter(this);
  }

  /// 联系人数据源（处理字母分类）
  late final _ContactDataSource _dataSource;
  /// 列表适配器（绑定SectionListView）
  late final _ContactListAdapter _adapter;

  /// 已选中的成员ID集合
  final Set<ID> _selected = HashSet();

  /// 获取已选中成员（对外只读）
  Set<ID> get selected => _selected;

  /// 获取数据源
  _ContactDataSource get dataSource => _dataSource;

  /// 重新加载联系人数据
  Future<void> _reload() async {
    // 将可选成员转为列表
    List<ID> members = widget.candidates.toList();
    // 转为ContactInfo列表
    List<ContactInfo> array = ContactInfo.fromList(members);
    // 预加载每个联系人的详细数据
    for (ContactInfo item in array) {
      await item.reloadData();
    }
    // 刷新数据源
    _dataSource.refresh(array);
    // 更新UI
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  /// 初始化状态：加载数据
  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 构建成员选择器页面
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor, // 页面背景色
    // 导航栏
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor, // 导航栏背景色
      // 动态标题（支持国际化）
      middle: StatedTitleView.from(context, () => i18nTranslator.translate('Select Participants')),
      // 确认按钮：返回选中结果并关闭页面
      trailing: TextButton(child: Text(i18nTranslator.translate('OK')),
        onPressed: () {
          appTool.closePage(context); // 关闭页面
          widget.onPicked(_selected); // 回调选中结果
        },
      ),
    ),
    // 主体：字母分类列表
    body: buildSectionListView(
      enableScrollbar: true, // 显示滚动条
      adapter: _adapter,     // 列表适配器
    ),
  );
}

/// 联系人列表适配器（实现SectionAdapterMixin）
/// 处理字母分类列表的布局和数据绑定
class _ContactListAdapter with SectionAdapterMixin {
  /// 构造函数
  /// [state] - 父状态对象
  _ContactListAdapter(_MemberPickerState state)
      : _parent = state;

  /// 父状态对象
  final _MemberPickerState _parent;

  /// 获取分类数量
  @override
  int numberOfSections() => _parent.dataSource.getSectionCount();

  /// 是否显示分类头部
  @override
  bool shouldExistSectionHeader(int section) => true;

  /// 分类头部是否吸顶
  @override
  bool shouldSectionHeaderStick(int section) => true;

  /// 构建分类头部组件
  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Styles.colors.sectionHeaderBackgroundColor, // 分类头部背景色
    padding: Styles.sectionHeaderPadding,             // 分类头部内边距
    child: Text(_parent.dataSource.getSection(section),
      style: Styles.sectionHeaderTextStyle,          // 分类头部文字样式
    ),
  );

  /// 获取指定分类下的项目数量
  @override
  int numberOfItems(int section) => _parent.dataSource.getItemCount(section);

  /// 构建列表项组件
  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section; // 分类索引
    int index = indexPath.item;      // 项目索引
    // 获取联系人信息
    ContactInfo info = _parent.dataSource.getItem(section, index);
    // 构建联系人选择单元格
    return _PickContactCell(_parent, info, onTap: () {
      Set<ID> members = _parent.selected;
      // 切换选中状态
      if (members.contains(info.identifier)) {
        members.remove(info.identifier); // 取消选中
      } else {
        members.add(info.identifier);    // 选中
      }
      Log.info('selected members: $members'); // 日志输出选中结果
    });
  }

}

/// 联系人数据源
/// 处理联系人的字母分类和数据管理
class _ContactDataSource {

  /// 分类名称列表（字母）
  List<String> _sections = [];
  /// 分类项目映射（分类索引 -> 联系人列表）
  Map<int, List<ContactInfo>> _items = {};

  /// 刷新联系人数据并重新分类
  /// [contacts] - 联系人列表
  void refresh(List<ContactInfo> contacts) {
    Log.debug('refreshing ${contacts.length} contact(s)'); // 调试日志
    // 创建联系人排序器并进行字母分类
    ContactSorter sorter = ContactSorter.build(contacts);
    _sections = sorter.sectionNames; // 更新分类名称
    _items = sorter.sectionItems;    // 更新分类项目
  }

  /// 获取分类数量
  int getSectionCount() => _sections.length;

  /// 获取指定分类的名称
  String getSection(int sec) => _sections[sec];

  /// 获取指定分类下的项目数量
  int getItemCount(int sec) => _items[sec]?.length ?? 0;

  /// 获取指定分类下的指定项目
  ContactInfo getItem(int sec, int idx) => _items[sec]![idx];
}

/// 联系人选择单元格组件
class _PickContactCell extends StatefulWidget {
  /// 构造函数
  /// [state] - 父状态对象
  /// [info] - 联系人信息
  /// [onTap] - 点击回调
  const _PickContactCell(_MemberPickerState state, this.info, {this.onTap})
      : _parent = state;

  /// 父状态对象
  final _MemberPickerState _parent;
  /// 联系人信息
  final ContactInfo info;
  /// 点击回调
  final GestureTapCallback? onTap;

  /// 判断当前联系人是否被选中
  bool get isSelected => _parent.selected.contains(info.identifier);

  /// 创建状态对象
  @override
  State<StatefulWidget> createState() => _PickContactState();

}

/// 联系人选择单元格状态类
class _PickContactState extends State<_PickContactCell> {
  _PickContactState();

  /// 构建单元格UI
  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: widget.info.getImage(), // 左侧头像
    // 标题：选中时显示红色
    title: widget.info.getNameLabel(
      style: widget.isSelected ? const TextStyle(color: CupertinoColors.systemRed) : null,
    ),
    // 尾部：选中时显示勾选图标
    trailing: !widget.isSelected ? null : Icon(AppIcons.selectedIcon,
      color: Styles.colors.primaryTextColor,
    ),
    // 点击事件：更新选中状态
    onTap: () => setState(() {
      GestureTapCallback? callback = widget.onTap;
      if (callback != null) {
        callback();
      }
    }),
  );

}

/// 预览选中的成员列表
/// [members] - 成员ID列表
/// 返回：水平滚动的成员头像+名称预览组件
Future<Widget> previewMembers(List<ID> members) async {
  List<Widget> children = [];
  Conversation? chat;
  // 遍历成员ID创建预览组件
  for (ID item in members) {
    chat = Conversation.fromID(item);
    if (chat == null) {
      assert(false, 'failed to get conversation: $item'); // 断言：获取会话失败
      continue;
    }
    // 添加单个成员预览
    children.add(Container(
      padding: const EdgeInsets.all(4), // 内边距4
      child: previewEntity(chat),      // 构建成员预览组件
    ));
  }
  // 水平滚动的预览列表
  return Center(
    child: buildScrollView(
      enableScrollbar: true,          // 显示滚动条
      scrollDirection: Axis.horizontal, // 水平滚动
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
        children: children,
      ),
    ),
  );
}

/// 构建单个实体（联系人/群组）的预览组件
/// [info] - 会话信息
/// [width] - 头像宽度（默认48）
/// [height] - 头像高度（默认48）
/// [fit] - 图片适配方式
/// [textStyle] - 名称文字样式
/// 返回：头像+名称的垂直布局组件
Widget previewEntity(Conversation info, {double width = 48, double height = 48, BoxFit? fit, TextStyle? textStyle}) => Column(
  children: [
    // 头像
    info.getImage(width: width, height: height, fit: fit),
    // 名称（单行省略）
    SizedBox(
      width: width,
      child: info.getNameLabel(
        textAlign: TextAlign.center,    // 居中对齐
        overflow: TextOverflow.ellipsis, // 单行省略
        style: textStyle,               // 文字样式
      ),
    ),
  ],
);