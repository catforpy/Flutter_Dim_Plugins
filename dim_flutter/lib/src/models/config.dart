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

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/group.dart';
import 'package:dim_client/pnf.dart' hide NotificationNames;

import '../common/constants.dart';
import '../filesys/upload.dart';

import 'config_loader.dart';
import 'newest.dart';

/// 全局配置管理类（单例）：封装配置的加载、访问和更新
class Config with Logging {
   /// 工厂构造函数，保证单例
  factory Config() => _instance;
  /// 单例实例
  static final Config _instance = Config._internal();
  /// 私有构造函数
  Config._internal();

  // TODO: 启动后台线程查询 'http://tarsier.dim.chat/config.json' 更新配置
  /// 远程配置入口URL
  static const String entrance = 'http://tarsier.dim.chat/v1/config.json';
  /// 本地资产配置路径
  static const String assets = 'assets/config.json';

  /// 配置数据Map（核心存储）
  Map? _info;

  /// 重写toString，输出配置关键信息
  @override
  String toString() {
    String clazz = className;
    return '<$clazz url="$entrance">\n$_info\n</$clazz>';
  }

  /// 获取管理员ID列表（不可拉黑）
  List<ID> get managers {
    var array = _info?['managers'];
    return _IDUtils.convert(array);
  }

  /// 获取默认联系人ID列表
  List<ID> get contacts {
    var array = _info?['contacts'];
    return _IDUtils.convert(array);
  }

  /// 获取翻译服务机器人ID列表
  List<ID> get translators {
    var array = _info?['translators'];
    return _IDUtils.convert(array);
  }

  /// 获取群通用助理ID列表
  List<ID> get assistants {
    var array = _info?['assistants'];
    return _IDUtils.convert(array);
  }

  /// 获取服务机器人列表
  List get services {
    var array = _info?['services'];
    if (array is List) {
      return array;
    }
    assert(array == null, 'services error: $array');
    return [];
  }
  // List get services => _info?['services'] ?? [];

  /// 获取服务提供商ID
  ID? get provider => _IDUtils.getIdentifier(_info);

  /// 获取基站列表
  List get stations {
    var array = _info?['stations'];
    if (array is List) {
      return array;
    }
    assert(array == null, 'stations error: $array');
    return [];
  }

  // List get stations => _info?['stations'] ?? [];

  // 上传API示例：
  // 'http://tfs.dim.chat:8081/upload/{ID}/avatar?md5={MD5}&salt={SALT}&enigma=123456'
  // 'http://106.52.25.169:8081/upload/{ID}/file?md5={MD5}&salt={SALT}&enigma=123456'
  /// 获取头像上传API地址
  String? get uploadAvatarAPI => _UploadAPI(_info ?? {}).uploadAvatarAPI;
  /// 获取文件上传API地址
  String? get uploadFileAPI => _UploadAPI(_info ?? {}).uploadFileAPI;

  /// 获取开源代码地址
  String get sourceURL => _info?['sources']
      ?? 'https://github.com/dimpart/tarsier';

  /// 获取服务条款网页地址
  String get termsURL => _info?['terms']
      ?? 'http://tarsier.dim.chat/v1/docs/terms.html';
  /// 获取隐私政策网页地址
  String get privacyURL => _info?['privacy']
      ?? 'http://tarsier.dim.chat/v1/docs/privacy.html';

  /// 获取最新版本信息
  Newest? get newest => NewestManager().parse(_info);

  /// 加载配置（优先级：缓存 > 资产 > 远程下载）
  /// 返回配置实例自身
  Future<Config> load() async {
    Map? cnf = _info;
    if (cnf == null) {
      _info = {};
      // 1. 从缓存路径加载
      var loader = ConfigLoader();
      cnf = await loader.loadConfig();
      // 2. 缓存不存在则从资产加载
      cnf ??= await loader.loadAssetsFile(assets);
      _info = cnf;
      // 3. 异步下载远程配置更新
      loader.downloadConfig(entrance).then((dict) {
        if (dict != null) {
          // 3.1 更新内存缓存
          _info = dict;
          // 3.2 保存到本地缓存
          loader.saveConfig(dict);
          // 3.3 初始化配置相关组件
          _initWithConfig(this);
          // 3.4 发送配置更新通知
          var nc = lnc.NotificationCenter();
          nc.postNotification(NotificationNames.kConfigUpdated, loader, {
            'config': dict,
          });
        }
      });
    }
    // 初始化配置相关组件
    _initWithConfig(this);
    return this;
  }
}

/// 配置初始化：更新群助理和文件上传器
/// [config] 配置实例
void _initWithConfig(Config config){
  // 更新群通用助理
  var bots = config.assistants;
  if(bots.isNotEmpty){
    SharedGroupManager man = SharedGroupManager();
    man.delegate.setCommonAssistants(bots);
  }
  // 更新文件上传配置
  var ftp = SharedFileUploader();
  ftp.initWithConfig(config);
}

/// 上传API解析工具类：从配置中解析头像/文件上传API
class _UploadAPI with Logging {
  /// 构造函数
  /// [_info] 配置Map
  _UploadAPI(this._info);

  /// 配置Map
  final Map _info;

  /// 获取头像上传API列表
  List get avatars => _fetch('avatar');
  /// 获取文件上传API列表
  List get files => _fetch('file');

  /// 从配置中提取指定类型的上传API列表
  /// [name] 类型（avatar/file）
  /// 返回API列表
  List _fetch(String name) {
    var info = _info['uploads'] ?? _info;
    info = info['uploads'] ?? info[name];
    return info is List ? info : [];
  }

  /// 从API列表中选择最快的API（TODO：实现测速逻辑）
  /// [apiList] API列表
  /// 返回最快的API地址
  String? _fastestAPI(List apiList) {
    List<String> array = _APIUtils.fetch(apiList);
    // TODO: 选择最快的URL
    return array.isEmpty ? null : array.first;
  }

  //
  //  对外提供的API地址
  //
  /// 头像上传API地址
  String? get uploadAvatarAPI => _fastestAPI(avatars);
  /// 文件上传API地址
  String? get uploadFileAPI   => _fastestAPI(files);
}

/// API工具类：解析API列表中的有效地址
abstract interface class _APIUtils {

  /// 从API列表中提取有效URL
  /// [apiList] API列表（包含String/Map类型）
  /// 返回有效URL列表
  static List<String> fetch(List apiList) {
    List<String> array = [];
    String? item;
    for(var api in apiList){
      if(api is String && api.contains('://')){
        array.add(api);
      }else if(api is Map){
        item = join(api);
        if(item != null){
          array.add(item);
        }
      }
    }
    return array;
  }

  /// 将Map类型的API配置拼接为URL
  /// [api] API配置Map（包含url/enigma等）
  /// 返回拼接后的URL
  static String? join(Map api) {
    String? url = api['url'] ?? api['URL'];
    if(url == null){
      assert(false, 'api error: $api');
      return null;
    }
    String? enigma = api['enigma'];
    return enigma == null ? url : Template.replaceQueryParam(url, 'enigma', enigma);
  }
}

/// ID工具类：转换/解析ID
abstract interface class _IDUtils {

  /// 将动态数据转换为ID列表
  /// [array] 动态数据（List/其他）
  /// 返回ID列表
  static List<ID> convert(dynamic array) {
    if (array == null || array is! List) {
      return [];
    }
    List<ID> users = [];
    ID? uid;
    for (var item in array) {
      uid = getIdentifier(item);
      if (uid != null) {
        users.add(uid);
      }
    }
    return users;
  }

  /// 从动态数据中解析ID
  /// [info] 动态数据（Map/String/其他）
  /// 返回ID实例
  static ID? getIdentifier(dynamic info) {
    if (info == null) {
      return null;
    } else if (info is Map) {
      info = info['did'] ?? info['ID'];
    }
    return ID.parse(info);
  }

}