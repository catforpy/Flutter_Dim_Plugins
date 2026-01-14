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

import 'package:dim_client/ok.dart';    // DIM-SDK基础工具（MD5/编码）
import 'package:dim_client/pnf.dart' show MD5; // MD5加密
import 'package:dim_client/sdk.dart';   // DIM-SDK核心库

import '../../common/constants.dart';   // 项目常量（通知名）
import '../../common/dbi/app.dart';     // 应用自定义信息数据库接口
import '../shared.dart';                // 全局变量

/// 文本内容处理器：处理文本消息，识别并保存服务类文本内容
class TextContentProcessor extends BaseContentProcessor{

  /// 构造方法：初始化处理器，创建服务内容处理器
  TextContentProcessor(super.facebook, super.messenger) {
    GlobalVariable shared = GlobalVariable();
    _serviceContentHandler = ServiceContentHandler(shared.database);
  }

  late final ServiceContentHandler _serviceContentHandler; // 服务内容处理器

  /// 核心处理方法：检查并保存服务类文本内容
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async{
    // 断言：确保是文本消息
    assert(content is TextContent, 'text content error: $content');
    
    // 检查是否为服务类内容，若是则保存
    if(_serviceContentHandler.checkAppContent(content)){
      await _serviceContentHandler.saveAppContent(content,rMsg.sender);
    }
    // 文本消息无需回执，返回空列表
    return [];
  }
}

/// 服务内容处理器：处理/保存各类服务类自定义内容（搜索/视频/直播/网站）
/// 混合Logging：提供日志能力
/// 实现CustomizedContentHandler：适配DIM-SDK自定义内容处理接口
class ServiceContentHandler with Logging implements CustomizedContentHandler {
  /// 构造方法：初始化处理器，传入数据库接口
  ServiceContentHandler(this.database);

  final AppCustomizedInfoDBI database;    // 应用自定义信息数据库接口

  // ===================== 私有方法：构建内容存储Key =====================
  /// 构建唯一Key：用于存储/查询服务类内容
  /// [sender] - 发送者ID
  /// [mod] - 模块名（如users/playlist）
  /// [title] - 内容标题
  String buildKey(ID sender,String mod, String title){
    // 1.处理发送者地址（截取后16位）
    String address = sender.address.toString();
    if(address.length > 16){
      address = address.substring(address.length - 16);
    }
    // 2. 处理标题（超长则MD5加密）
    if(title.length > 32){
      var data = UTF8.encode(title);
      data = MD5.digest(data);
      title = Hex.encode(data);
    }
    // 3. 拼接Key
    String key = '$address:$mod:$title';
    // 4. Key超长处理（截取前65位，FIXME：建议改用MD5）
    if(key.length > 64){
      logWarning('trimming key: $key');
      key = key.substring(0, 65);
    }
    return key;
  }

  /// 根据Key获取服务类内容
  Future<Content?> getContent(ID sender,String mod,String title)async{
    String key = buildKey(sender, mod, title);
    Mapper? content = await database.getAppCustomizedInfo(key,mod:mod);
    return Content.parse(content);
  }

  // ===================== 服务应用模块配置 =====================
  /// 支持的服务应用模块：key=应用ID，value=模块列表
  static final Map<String,List<String>> appModules = {
    'chat.dim.search': ['users'],    // 在线用户搜索
    'chat.dim.video': ['playlist', 'season'], // 视频播放列表/剧集
    'chat.dim.tvbox': ['lives'],     // 直播源
    'chat.dim.sites': ['homepage'],  // 网站首页
  };

  // ===================== 核心方法：检查是否为服务类内容 =====================
  bool checkAppContent(Content content){
    String? app = content['app'];   //应用ID
    String? mod = content['mod'];   //模块名
    String? act = content['act'];  // 动作（如respond）

    // 缺少关键字段：不是服务类内容
    if (app == null || mod == null || act == null) {
      return false;
    }

    // 按应用ID过滤
    if (app == 'chat.dim.search') {
      return mod == 'users';       // 在线用户模块
    } else if (app == 'chat.dim.video') {
      return mod == 'playlist' || mod == 'season'; // 视频模块
    } else if (app == 'chat.dim.tvbox') {
      return mod == 'lives';       // 直播模块
    } else if (app == 'chat.dim.sites') {
      return mod == 'homepage';    // 网站模块
    } else {
      logWarning('unknown content: $app, $mod, $act');
      return false;
    }
  }

  // ===================== 实现接口方法：处理自定义内容动作 =====================
  @override
  Future<List<Content>> handleAction(String act,ID sender,CustomizedContent content,ReliableMessage rMsg) async {
    await saveAppContent(content,sender);
    return [];
  }

  // ===================== 核心方法：保存服务类内容 =====================
  /// 保存服务类内容到数据库，并发送更新通知
  /// [content] - 服务类内容
  /// [sender] - 发送者ID
  /// [expires] - 过期时间
  /// 返回：是否保存成功
  Future<bool> saveAppContent(Content content, ID sender, {Duration? expires}) async {
    // 文本内容超长处理(截取前后部分，中间省略)
    String? text = content['text'];
    if(text != null && text.length > 128){
      String head = text.substring(0,100);
      String tail = text.substring(105);
      text = '$head...$tail';
    }

    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];

    var nc = NotificationCenter();
    bool ok = false;

    // 校验关键字段
    if(app == null || mod == null){
      logError('service content error: $content');
    }
    // 1. 在线用户搜索内容
    else if(app == 'chat.dim.search'){
      String title = content['title'] ?? '';
      logInfo('got customized text content: $title, $text');
      if (mod == 'users' && title.isNotEmpty){
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key,expires: expires);
        var users = content['users'];
        logInfo('got ${users?.length} users');
        // 发送在线用户更新通知
        nc.postNotification(NotificationNames.kActiveUsersUpdated, this,{
          'cmd' : content,
          'users' : users,
        });
      }
    }
    // 2. 视频内容（播放列表/剧集）
    else if(app == 'chat.dim.video'){
      Map? season = content['season'];
      String page = season?['page'] ?? '';
      String title = content['title'] ?? '';

      // 播放列表
      if(mod == 'playlist' && title.isNotEmpty){
        assert(act == 'respond', 'customized content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key,expires: expires);
        var playlist = content['playlist'];
        logInfo('got ${playlist?.length} videos in playlist');
        nc.postNotification(NotificationNames.kPlaylistUpdated, this, {
          'cmd': content,
          'playlist': playlist,
        });
      }
      // 剧集
      else if (mod == 'season' && page.isNotEmpty) {
        assert(act == 'respond', 'customized content error: $text');
        String key = buildKey(sender, mod, page);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        nc.postNotification(NotificationNames.kVideoItemUpdated, this, {
          'cmd': content,
          'season': season,
        });
      }
    }
    // 3. 直播内容
    else if (app == 'chat.dim.tvbox') {
      String title = content['title'] ?? '';
      logInfo('got customized text content: $title, $text');
      if (mod == 'lives' && title.isNotEmpty) {
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        var lives = content['lives'];
        logInfo('got ${lives?.length} lives');
        nc.postNotification(NotificationNames.kLiveSourceUpdated, this, {
          'cmd': content,
          'lives': lives,
        });
      }
    }
    // 4. 网站内容
    else if (app == 'chat.dim.sites') {
      String title = content['title'] ?? '';
      logInfo('got customized text content: $title, $text');
      if (mod == 'homepage' && title.isNotEmpty) {
        assert(act == 'respond', 'customized text content error: $text');
        String key = buildKey(sender, mod, title);
        ok = await database.saveAppCustomizedInfo(content, key, expires: expires);
        nc.postNotification(NotificationNames.kWebSitesUpdated, this, {
          'cmd': content,
        });
      }
    }

    return ok;
  }

  /// 清理过期的服务类内容
  Future<bool> clearExpiredContents() async =>
      await database.clearExpiredAppCustomizedInfo();
}
