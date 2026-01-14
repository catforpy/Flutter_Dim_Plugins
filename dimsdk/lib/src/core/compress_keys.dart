/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

/*
 * 中文解析：
 * 作用：DIM 协议的「消息字段压缩工具」，将消息的长字段名（如 "sender"）缩短为单字符（如 "F"），减少消息体积。
 * 依赖关系：无额外依赖，是独立的工具类。
 * 核心方法：
 * 1. compressContent(Map content)：压缩消息内容的字段名；
 * 2. extractContent(Map content)：还原消息内容的字段名；
 * 3. compressSymmetricKey(Map key)：压缩对称密钥的字段名；
 * 4. extractSymmetricKey(Map key)：还原对称密钥的字段名；
 * 5. compressReliableMessage(Map msg)：压缩可靠消息的字段名；
 * 6. extractReliableMessage(Map msg)：还原可靠消息的字段名；
 * 方法含义：
 * - 通过 `shortenKeys/restoreKeys` 实现「长字段名 ↔ 短字段名」的映射（如 "sender"→"F"）；
 * - 压缩后消息体积更小，适合网络传输；还原后便于业务层解析。
 */

abstract interface class Shortener {

  /**
   * 短字段名映射表（核心规则）
   * 
    ======+==================================================+==================
          |   Message        Content        Symmetric Key    |    字段说明
    ------+--------------------------------------------------+------------------
    "A"   |                                 "algorithm"      | 加密算法（如AES/RSA）
    "C"   |   "content"      "command"                       | 消息内容/指令类型
    "D"   |   "data"                        "data"           | 加密数据/密钥数据
    "F"   |   "sender"                                       | 发送方（From）
    "G"   |   "group"        "group"                         | 群组ID
    "I"   |                                 "iv"             | 初始向量（加密用）
    "K"   |   "key", "keys"                                  | 对称密钥（单聊）/密钥集合（群聊）
    "M"   |   "meta"                                         | 元数据（用户/服务器身份核心信息）
    "N"   |                  "sn"                            | 消息序号（Serial Number）
    "P"   |   "visa"                                         | 签证文档（Profile）
    "R"   |   "receiver"                                     | 接收方
    "S"   |   ...                                            | 废弃（易混淆 sender/signature）
    "T"   |   "type"         "type"                          | 类型（消息/内容/密钥类型）
    "V"   |   "signature"                                    | 签名（Verification）
    "W"   |   "time"         "time"                          | 时间戳（When）
    ======+==================================================+==================
   * 
   * 注意：
   *   "S" 字段已废弃，原因是容易混淆 "sender"（发送方）和 "signature"（签名），避免解析错误。
   */

  /// 压缩消息内容的字段名
  /// 核心逻辑：将内容Map中的长字段名（如 "type"/"command"）替换为短字段名（如 "T"/"C"），
  /// 适用于 InstantMessage 的 content 字段压缩。
  /// @param content - 原始消息内容Map（包含长字段名）
  /// @return 压缩后的内容Map（包含短字段名）
  Map compressContent(Map content);

  /// 还原消息内容的字段名
  /// 核心逻辑：将内容Map中的短字段名（如 "T"/"C"）还原为长字段名（如 "type"/"command"），
  /// 适用于接收方解析压缩后的内容。
  /// @param content - 压缩后的内容Map（包含短字段名）
  /// @return 还原后的内容Map（包含长字段名）
  Map extractContent(Map content);

  /// 压缩对称密钥的字段名
  /// 核心逻辑：将对称密钥Map中的长字段名（如 "algorithm"/"iv"）替换为短字段名（如 "A"/"I"），
  /// 适用于 SymmetricKey 序列化后的Map压缩。
  /// @param key - 原始对称密钥Map（包含长字段名）
  /// @return 压缩后的密钥Map（包含短字段名）
  Map compressSymmetricKey(Map key);

  /// 还原对称密钥的字段名
  /// 核心逻辑：将对称密钥Map中的短字段名（如 "A"/"I"）还原为长字段名（如 "algorithm"/"iv"），
  /// 适用于接收方解析压缩后的密钥。
  /// @param key - 压缩后的密钥Map（包含短字段名）
  /// @return 还原后的密钥Map（包含长字段名）
  Map extractSymmetricKey(Map key);

  /// 压缩可靠消息的字段名
  /// 核心逻辑：将 ReliableMessage 序列化后的Map中的长字段名（如 "sender"/"signature"）
  /// 替换为短字段名（如 "F"/"V"），适用于消息传输前的最终压缩。
  /// @param msg - 原始可靠消息Map（包含长字段名）
  /// @return 压缩后的消息Map（包含短字段名）
  Map compressReliableMessage(Map msg);

  /// 还原可靠消息的字段名
  /// 核心逻辑：将压缩后的可靠消息Map中的短字段名（如 "F"/"V"）还原为长字段名（如 "sender"/"signature"），
  /// 是 compressReliableMessage 的逆操作，适用于接收方解析消息。
  /// @param msg - 压缩后的消息Map（包含短字段名）
  /// @return 还原后的消息Map（包含长字段名）
  Map extractReliableMessage(Map msg);
}

/// 消息字段压缩工具实现类
/// 实现 Shortener 接口的所有方法，提供具体的字段压缩/还原逻辑，
/// 核心依赖 `moveKey/shortenKeys/restoreKeys` 三个辅助方法完成字段名映射。
class MessageShortener implements Shortener {

  /// 移动Map中的字段名（核心辅助方法）
  /// 核心逻辑：将Map中指定的「原字段名」对应的值，迁移到「目标字段名」，
  /// 并删除原字段名，确保字段名替换后数据不丢失、不重复。
  /// @param from - 原字段名（如 "sender"）
  /// @param to - 目标字段名（如 "F"）
  /// @param info - 待处理的Map（消息/密钥/内容）
  /// @throws AssertionError - 目标字段名已存在值时触发断言（避免数据覆盖）
  void moveKey(String from, String to, Map info) {
    var value = info[from];
    if (value != null) {
      // 断言目标字段为空，防止数据覆盖丢失
      assert(info[to] == null, '字段名冲突: "$from" -> "$to", $info');
      info.remove(from);
      info[to] = value;
    }
  }

  /// 批量缩短字段名（辅助方法）
  /// 核心逻辑：遍历字段名映射列表，批量调用 moveKey 完成「长字段名→短字段名」的替换，
  /// 映射列表格式：[短字段名, 长字段名, 短字段名, 长字段名, ...]（如 ["T", "type", "W", "time"]）。
  /// @param keys - 字段名映射列表（短字段在前，长字段在后）
  /// @param info - 待压缩的Map（消息/密钥/内容）
  void shortenKeys(List<String> keys, Map info) {
    int i = 1;
    while (i < keys.length) {
      // keys[i-1] = 短字段名，keys[i] = 长字段名
      moveKey(keys[i], keys[i - 1], info);
      i += 2;
    }
  }

  /// 批量还原字段名（辅助方法）
  /// 核心逻辑：遍历字段名映射列表，批量调用 moveKey 完成「短字段名→长字段名」的还原，
  /// 是 shortenKeys 的逆操作，映射列表格式与 shortenKeys 一致。
  /// @param keys - 字段名映射列表（短字段在前，长字段在后）
  /// @param info - 待还原的Map（消息/密钥/内容）
  void restoreKeys(List<String> keys, Map info) {
    int i = 1;
    while (i < keys.length) {
      // keys[i-1] = 短字段名，keys[i] = 长字段名
      moveKey(keys[i - 1], keys[i], info);
      i += 2;
    }
  }

  // ======================== 消息内容压缩/还原 ========================

  /// 消息内容的字段名映射列表（短字段名 → 长字段名）
  /// 覆盖内容的核心字段：类型、序号、时间戳、群组、指令
  List<String> contentShortKeys = [
    "T", "type",      // 内容类型（如文本/图片/指令）
    "N", "sn",        // 消息序号
    "W", "time",      // 时间戳（When）
    "G", "group",     // 群组ID
    "C", "command",   // 指令类型（如创建群组/加入群组）
  ];

  @override
  Map compressContent(Map content) {
    // 批量将内容的长字段名替换为短字段名
    shortenKeys(contentShortKeys, content);
    return content;
  }

  @override
  Map extractContent(Map content) {
    // 批量将内容的短字段名还原为长字段名
    restoreKeys(contentShortKeys, content);
    return content;
  }

  // ======================== 对称密钥压缩/还原 ========================

  /// 对称密钥的字段名映射列表（短字段名 → 长字段名）
  /// 覆盖密钥的核心字段：算法、数据、初始向量
  List<String> cryptoShortKeys = [
    "A", "algorithm",  // 加密算法（如"AES-256-CBC"）
    "D", "data",       // 密钥数据（二进制序列化后的内容）
    "I", "iv",         // 初始向量（对称加密的随机数，增强安全性）
  ];

  @override
  Map compressSymmetricKey(Map key) {
    // 批量将密钥的长字段名替换为短字段名
    shortenKeys(cryptoShortKeys, key);
    return key;
  }

  @override
  Map extractSymmetricKey(Map key) {
    // 批量将密钥的短字段名还原为长字段名
    restoreKeys(cryptoShortKeys, key);
    return key;
  }

  // ======================== 可靠消息压缩/还原 ========================

  /// 可靠消息的字段名映射列表（短字段名 → 长字段名）
  /// 覆盖消息的核心字段：收发方、时间戳、类型、群组、密钥、数据、签名、元数据、签证
  List<String> messageShortKeys = [
    "F", "sender",      // 发送方（From）
    "R", "receiver",    // 接收方（Rcpt to）
    "W", "time",        // 时间戳（When）
    "T", "type",        // 消息类型
    "G", "group",       // 群组ID
    "K", "key",         // 对称密钥（单聊，群聊会单独处理"keys"）
    "D", "data",        // 加密后的消息内容
    "V", "signature",   // 消息签名（Verification）
    "M", "meta",        // 发送方元数据
    "P", "visa",        // 发送方签证（Profile）
  ];

  @override
  Map compressReliableMessage(Map msg) {
    // 特殊处理：群聊的"keys"字段统一映射为"K"（单聊的"key"也映射为"K"）
    moveKey("keys", "K", msg);
    // 批量将消息的长字段名替换为短字段名
    shortenKeys(messageShortKeys, msg);
    return msg;
  }

  @override
  Map extractReliableMessage(Map msg) {
    // 特殊处理：还原"K"字段为"key"（单聊）或"keys"（群聊）
    var keys = msg["K"];
    if (keys != null) {
      if (keys is Map) {
        // 群聊场景："K"对应Map类型 → 还原为"keys"
        assert(msg["keys"] == null, "消息keys字段重复: $msg");
        msg.remove("K");
        msg["keys"] = keys;
      } else if (keys is String) {
        // 单聊场景："K"对应String类型 → 还原为"key"
        assert(msg["key"] == null, "消息key字段重复: $msg");
        msg.remove("K");
        msg["key"] = keys;
      } else {
        // 非法类型：触发断言，提示字段错误
        assert(false, "消息key字段类型错误: $msg");
      }
    }
    // 批量将消息的短字段名还原为长字段名
    restoreKeys(messageShortKeys, msg);
    return msg;
  }
}