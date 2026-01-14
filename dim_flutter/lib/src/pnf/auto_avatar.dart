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

import 'package:flutter/cupertino.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/pnf.dart' hide NotificationNames;

import '../client/shared.dart';
import '../common/constants.dart';
import '../filesys/local.dart';
import '../filesys/upload.dart';
import '../ui/icons.dart';
import '../ui/styles.dart';

import 'gallery.dart';
import 'image.dart';
import 'loader.dart';
import 'net_image.dart';


/// 预览头像图片（点击头像时调用，打开画廊预览）
/// [context] 上下文
/// [identifier] 用户/群组ID
/// [avatar] 头像的PNF对象
/// [fit] 图片填充模式
void previewAvatar(BuildContext context, ID identifier, PortableNetworkFile avatar, {
  BoxFit? fit,
}) {
  var image = AvatarFactory().getImageView(identifier, avatar, fit: fit);
  Gallery([image], 0).show(context);
}

/// 自动头像工厂（单例）：管理头像加载器和视图缓存，避免重复创建
class AvatarFactory {

  factory AvatarFactory() => _instance;
  static final AvatarFactory _instance = AvatarFactory._internal();
  AvatarFactory._internal();

  /// 头像加载器缓存：URL/文件名 -> 加载器（弱引用）
  final Map<String,_AvatarImageLoader> _loaders = WeakValueMap();
  /// 头像视图缓存：URL -> 视图集合（弱引用）
  final Map<Uri,Set<_AvatarImageView>> _views = {};
  /// 自动头像视图缓存：用户ID -> 视图集合（弱引用
  final Map<ID,Set<_AutoAvatarView>> _avatars = {};

  /// 获取PNF对应的头像加载器
  /// [pnf] 便携网络文件对象
  /// 返回头像加载器
  PortableImageLoader getImageLoader(PortableNetworkFile pnf) {
    _AvatarImageLoader? runner;
    var filename = pnf.filename;
    var url = pnf.url;
    if(url !=null ){
      // 从URL获取加载器
      runner = _loaders[url.toString()];
      if(runner == null){
        runner = _createLoader(pnf);
        _loaders[url.toString()] = runner;
      }
    }else if (filename != null){
      // 从文件名获取加载器
      runner = _loaders[filename];
      if (runner == null) {
        runner = _createUpper(pnf);
        _loaders[filename] = runner;
      }
    } else {
      throw FormatException('PNF error: $pnf');
    }
    return runner;
  }

  /// 创建下载加载器（针对有URL的PNF）
  /// [pnf] 便携网络文件对象
  /// 返回头像加载器
  _AvatarImageLoader _createLoader(PortableNetworkFile pnf) {
    _AvatarImageLoader loader = _AvatarImageLoader(pnf);
    if (pnf.data == null) {
      /*await */loader.prepare(); // 预加载（异步）
    }
    return loader;
  }

  /// 创建上传加载器（针对有文件名但无URL的PNF）
  /// [pnf] 便携网络文件对象
  /// 返回头像加载器
  _AvatarImageLoader _createUpper(PortableNetworkFile pnf) {
    _AvatarImageLoader loader = _AvatarImageLoader(pnf);
    if (pnf['enigma'] != null) {
      /*await */loader.prepare(); // 预加载（异步）
    }
    return loader;
  }

  /// 获取头像视图（带缓存）
  /// [user] 用户ID
  /// [pnf] 便携网络文件对象
  /// [width/height] 视图尺寸
  /// [fit] 图片填充模式
  /// 返回头像视图
  PortableImageView getImageView(ID user, PortableNetworkFile pnf, {
    double? width, double? height, BoxFit? fit,
  }) {
    var loader = getImageLoader(pnf);
    Uri? url = pnf.url;
    if (url == null) {
      // 无URL，直接创建视图
      return _AvatarImageView(user, loader, width: width, height: height, fit: fit,);
    }
    _AvatarImageView? img;
    Set<_AvatarImageView>? table = _views[url];
    if (table == null) {
      // 无缓存，创建新集合
      table = WeakSet();
      _views[url] = table;
    } else {
      // 查找缓存中匹配的视图（尺寸+ID一致）
      for (_AvatarImageView item in table) {
        if (item.width != width || item.height != height) {
          // 尺寸不匹配
        } else if (item.identifier != user) {
          // ID不匹配
        } else {
          // 找到匹配视图
          img = item;
          break;
        }
      }
    }
    if (img == null) {
      // 创建新视图并加入缓存
      img = _AvatarImageView(user, loader, width: width, height: height, fit: fit,);
      table.add(img);
    }
    return img;
  }

  /// 获取自动刷新的头像视图（带缓存）
  /// [user] 用户ID
  /// [width/height] 视图尺寸（默认32）
  /// [fit] 图片填充模式
  /// 返回头像视图
  Widget getAvatarView(ID user, {
    double? width, double? height, BoxFit? fit,
  }) {
    width ??= 32;
    height ??= 32;
    _AutoAvatarView? avt;
    Set<_AutoAvatarView>? table = _avatars[user];
    if(table == null){
      // 无缓存，创建新集合
      table = WeakSet();
      _avatars[user] = table;
    } else {
      // 查找缓存中匹配的视图（尺寸一致）
      for(_AutoAvatarView item in table){
        if (item.width != width || item.height != height) {
          // 尺寸不匹配
        } else {
          assert(item.identifier == user, 'should not happen: ${item.identifier}, $user');
          // 找到匹配视图
          avt = item;
          break;
        }
      }
    }
    if (avt == null) {
      // 创建新视图并加入缓存
      avt = _AutoAvatarView(user, width: width, height: height, fit: fit,);
      table.add(avt);
    }
    return avt;
  }
}

/// 头像信息封装：存储用户ID、尺寸、头像PNF和视图
class _Info {
  _Info(this.identifier, {required this.width, required this.height, required this.fit});

  /// 用户/群组ID
  final ID identifier;
  /// 视图宽度
  final double width;
  /// 视图高度
  final double height;
  /// 图片填充模式
  final BoxFit? fit;

  /// 头像PNF
  PortableNetworkFile? avatar;
  /// 头像视图
  PortableImageView? avatarView;

  /// 静态构造方法：异步加载用户签证并获取头像
  static from(ID identifier, {
    required double width,required double height,required BoxFit? fit,
  }){
    var info = _Info(identifier, width: width, height: height, fit: fit);
    GlobalVariable shared = GlobalVariable();
    // 异步获取用户签证
    shared.facebook.getVisa(identifier).then((visa){
      var avatar = visa?.avatar;
      if(avatar != null){
        info.avatar = avatar;
        var factory = AvatarFactory();
        // 创建头像视图
        info.avatarView = factory.getImageView(identifier, avatar,
          width: width,height: height,fit: fit);
        // 发送头像更新通知
        var nc = lnc.NotificationCenter();
        nc.postNotification(_kAutoAvatarUpdate, info,{
          'ID' : identifier,
        });
      }
    });
    return info;
  }
}

/// 自动头像更新通知名称
const String _kAutoAvatarUpdate = '_AutoAvatarUpdate';

/// 自动刷新头像视图：监听文档更新和头像更新通知，自动刷新UI
class _AutoAvatarView extends StatefulWidget {
  _AutoAvatarView(ID identifier, {
    required double width, required double height, required BoxFit? fit,
  }) : info = _Info.from(identifier, width: width, height: height, fit: fit);

  /// 头像信息封装
  final _Info info;

  /// 用户/群组ID
  ID get identifier => info.identifier;
  /// 视图宽度
  double get width => info.width;
  /// 视图高度
  double get height => info.height;
  /// 图片填充模式
  BoxFit? get fit => info.fit;

  @override
  State<StatefulWidget> createState() => _AutoAvatarState();
}

class _AutoAvatarState extends State<_AutoAvatarView> implements lnc.Observer {
  _AutoAvatarState() {
    // 注册通知监听：文档更新、头像更新
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, _kAutoAvatarUpdate);
  }

  @override
  void dispose(){
    // 移除通知监听，避免内存泄漏
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this,_kAutoAvatarUpdate);
    nc.removeObserver(this,NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  /// 接收通知回调：处理文档更新和头像更新
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if(name == NotificationNames.kDocumentUpdated){
      // 文档更新通知（如前正更新）
      ID? identifier = userInfo?['ID'];
      Document? visa = userInfo?['document'];
      assert(identifier != null && visa != null, 'notification error: $notification');
      if(identifier == widget.identifier && visa is Visa){
        Log.info('document updated, refreshing avatar: $identifier');
        // 重新加载头像
        return _reload();
      }
    } else if (name == _kAutoAvatarUpdate){
      // 头像更新通知
      ID? identifier = userInfo?['ID'];
      if(identifier == widget.identifier){
        Log.info('avatar updated, refreshing avatar: $identifier');
        // 刷新UI
        if(mounted){
          setState(() {
            
          });
        }
      }
    }else{
      assert(false, 'should not happen');
    }
  }

  /// 重新加载头像数据并更新视图
  Future<void> _reload() async {
    ID identifier = widget.identifier;
    GlobalVariable shared = GlobalVariable();
    Visa? doc = await shared.facebook.getVisa(identifier);
    if(doc == null){
      Log.warning('visa document not found: $identifier');
      return; 
    }
    // 获取签证中的头像
    PortableNetworkFile? avatar = doc.avatar;
    if(avatar == null){
      Log.warning('avatar not found: $doc');
      return;
    }else if (avatar == widget.info.avatar) {
      Log.warning('avatar not changed: $identifier, $avatar');
      return;
    } else {
      widget.info.avatar = avatar;
    }
    var factory = AvatarFactory();
    // 创建新的头像视图
    widget.info.avatarView = factory.getImageView(identifier, avatar,
      width: widget.width,height: widget.height,fit: widget.fit);
    if (mounted) {
      // 刷新UI
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = widget.width;
    double height = widget.height;
    ID identifier = widget.identifier;
    // 获取头像视图（无则显示默认图标）
    Widget? view = widget.info.avatarView;
    view ??= _AvatarImageView.getNoImage(identifier, width: width, height: height);
    // 圆角裁剪
    return ClipRRect( 
      borderRadius: BorderRadius.all(
        Radius.elliptical(width / 8, height / 8),
      ),
      child: view,
    );
  }
}

/// 自动刷新头像图片视图：继承自PortableImageView，提供默认图标
class _AvatarImageView extends PortableImageView {
  const _AvatarImageView(this.identifier, super.loader, {super.width, super.height, super.fit});

  /// 用户/群组ID
  final ID identifier;

  /// 获取默认图标（根据ID类型）
  /// [identifier] 用户/群组/基站等ID
  /// [width/height] 图标尺寸
  /// 返回默认图标Widget
  static Widget getNoImage(ID identifier, {double? width, double? height}) {
    double? size = width ?? height;
    if (identifier.type == EntityType.STATION) {
      return Icon(AppIcons.stationIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.BOT) {
      return Icon(AppIcons.botIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.ISP) {
      return Icon(AppIcons.ispIcon, size: size, color: Styles.colors.avatarColor);
    } else if (identifier.type == EntityType.ICP) {
      return Icon(AppIcons.icpIcon, size: size, color: Styles.colors.avatarColor);
    }
    if (identifier.isUser) {
      return Icon(AppIcons.userIcon, size: size, color: Styles.colors.avatarDefaultColor);
    } else {
      return Icon(AppIcons.groupIcon, size: size, color: Styles.colors.avatarDefaultColor);
    }
  }
}

/// 头像图片加载器：继承自PortableImageLoader，处理头像的加载和缓存
class _AvatarImageLoader extends PortableImageLoader {
  _AvatarImageLoader(super.pnf);

  /// 构建头像图片Widget（无图片时显示默认图标）
  @override
  Widget getImage(PortableImageView widget, {BoxFit? fit}) {
    _AvatarImageView aiv = widget as _AvatarImageView;
    ID identifier = aiv.identifier;
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if (image == null) {
      // 无图片，显示默认图标
      return _AvatarImageView.getNoImage(identifier, width: width, height: height);
    } else if (width == null && height == null) {
      // 无尺寸限制，直接显示图片
      return ImageUtils.image(image, fit: fit);
    } else {
      // 有尺寸限制，指定尺寸显示
      return ImageUtils.image(image, width: width, height: height, fit: fit ?? BoxFit.cover,);
    }
  }

  /// 预加载处理：区分下载和上传场景
  @override
  Future<void> prepare() async {
    if (pnf.url == null) {
      // 无URL，走父类上传逻辑
      return await super.prepare();
    } else {
      // 有URL，创建下载任务并加入上传器队列
      var ftp = SharedFileUploader();
      var task = _AvatarDownloadTask(pnf);
      downloadTask = task;
      await ftp.addAvatarTask(task);
    }
  }

  /// 获取头像缓存文件路径
  @override
  Future<String?> get cacheFilePath async => await _getAvatarPath(filename, pnf);

}

/// 头像下载任务：继承自PortableFileDownloadTask，指定优先级
class _AvatarDownloadTask extends PortableFileDownloadTask {
  _AvatarDownloadTask(super.pnf);

  /// 下载优先级：低速（不占用过多带宽）
  @override
  int get priority => DownloadPriority.SLOWER;

  /// 获取头像缓存文件路径
  @override
  Future<String?> get cacheFilePath async => await _getAvatarPath(filename, pnf);

}

/// 获取头像缓存文件路径
/// [filename] 文件名
/// [pnf] 便携网络文件对象
/// 返回缓存路径
Future<String?> _getAvatarPath(String? filename, PortableNetworkFile pnf) async {
  if (filename == null || filename.isEmpty) {
    assert(false, 'PNF error: $pnf');
    return null;
  }
  LocalStorage cache = LocalStorage();
  return await cache.getAvatarFilePath(filename);
}