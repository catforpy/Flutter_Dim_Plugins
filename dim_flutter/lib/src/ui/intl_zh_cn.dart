// 定义简体中文的语言标识常量
const String langChinese = '简体中文';

/// 简体中文 国际化翻译映射表
/// 键：通用英文标识 | 值：对应的简体中文翻译
final Map<String, String> intlZhCn = {

  // 'OK': '好',

  // 'Customer Service': 'Customer Service',
  // '@total friends': '@total friends',

  //
  //  注册相关翻译
  //
  'Register': '注册新账号',                          // 注册新的用户账号
  'Import': '导入旧账号',                            // 导入已有的用户账号
  'Name': '名称',                                    // 姓名/名称
  'Nickname': '昵称',                                // 用户昵称
  'Your nickname': '怎么称呼',                        // 询问用户的称呼（口语化表达）

  'Please choose your avatar': '请选择一张图片作为您的头像。', // 提示用户选择头像图片
  'Please input your nickname': '请问怎么称呼？',           // 口语化询问用户昵称
  'Please agree the privacy policy': '请阅读并同意 DIM 隐私政策。', // 提示用户同意隐私政策
  'Failed to import account': '导入账号失败，请检查助记词是否正确。', // 账号导入失败的提示
  'Failed to generate ID': '无法生成 ID。',           // 生成用户ID失败

  'Mnemonic Codes': '助记词',                        // 区块链/加密领域的助记词（私钥的易记形式）
  'MnemonicCodes::Description': '助记词是已有账号的私钥，'
      '如果您尚未拥有账号，请点击右上角的"注册"按钮生成新的账号。', // 助记词的说明文本

  'Show': '显示',                                    // 显示（如显示密码/助记词）
  'Hide': '隐藏',                                    // 隐藏（如隐藏密码/助记词）
  'Accept': '接受',                                  // 接受/同意

  //
  //  图片相关翻译
  //
  'Camera': '相机',                                  // 相机（拍照功能）
  'Album': '相册',                                  // 手机相册
  'Gallery': '图库',                                  // 图片图库
  'Pick Image': '选取图片',                          // 选择图片
  'Image File Error': '图片文件错误',                // 图片文件损坏/格式错误
  'Upload Failed': '上传失败',                        // 图片上传失败

  'Save to Album': '保存到相册',                      // 将图片保存到手机相册
  'Sure to save this image?': '确定要保存这张图片吗？', // 保存图片的确认提示
  'Image saved to album': '图片成功保存到相册。',      // 图片保存成功的提示
  'Failed to save image to album': '无法将图片保存到相册。', // 图片保存失败的提示

  //
  //  时间相关翻译
  //
  'AM': '上午',                                      // 上午（时间标识）
  'PM': '下午',                                      // 下午（时间标识）
  'Yesterday': '昨天',                                // 昨天

  'Monday': '周一',                                  // 星期一
  'Tuesday': '周二',                                 // 星期二
  'Wednesday': '周三',                               // 星期三
  'Thursday': '周四',                                // 星期四
  'Friday': '周五',                                  // 星期五
  'Saturday': '周六',                                // 星期六
  'Sunday': '周日',                                  // 星期日

  '@several seconds': '@several 秒',                  // 几秒（占位符@several表示具体数字）
  '@several minutes': '@several 分钟',                // 几分钟
  '@several hours': '@several 小时',                  // 几小时
  '@several days': '@several 天',                    // 几天
  '@several months': '@several 个月',                // 几个月

  'Daily': '24 小时',                                // 每天/24小时（注释中标注了备选翻译'每天'）
  'Anon': '3 天',                                    // 匿名模式持续3天
  'Weakly': '7 天',                                  // 每周/7天（原拼写错误：Weakly 应为 Weekly）
  'Monthly': '30 天',                                // 每月/30天（注释中标注了备选翻译'每个月'）
  'Manually': '手动',                                // 手动操作

  'Burn After Reading': '阅后即焚',                  // 消息阅读后自动销毁的功能

  //
  //  连接状态相关翻译
  //
  'Waiting': '等待中',                                // 等待连接
  'Connecting': '正在连接',                          // 正在建立网络连接
  'Connected': '已连接',                              // 网络连接成功
  'Handshaking': '验证中',                            // 握手验证（网络连接的身份验证阶段）
  'Disconnected': '已断开连接',                      // 网络连接断开

  //
  //  弹窗/提示框相关翻译
  //
  'Cancel': '取消',                                  // 取消操作
  'Confirm': '确认',                                  // 确认操作
  'Confirm Add': '确认添加',                          // 确认添加（如添加好友/群组）
  'Confirm Delete': '确认删除',                      // 确认删除（如删除消息/联系人）
  'Confirm Share': '确认分享',                        // 确认分享（如分享文件/链接）
  'Confirm Forward': '确认转发',                      // 确认转发（如转发消息）

  'Continue': '继续',                                // 继续操作
  'Deny': '拒绝',                                    // 拒绝（如拒绝权限/好友请求）
  'Allow': '允许',                                  // 允许（如允许权限/好友请求）

  'Success': '成功',                                // 操作成功
  'Error': '错误',                                  // 操作错误

  'Fatal Error': '严重错误',                          // 致命/严重错误（影响程序运行）

  'Blocked': '已拦截',                                // 消息/联系人已被拦截
  'Unblocked': '拦截已取消',                          // 取消对消息/联系人的拦截
  'Muted': '已屏蔽',                                // 消息/通知已被屏蔽
  'Unmuted': '屏蔽已取消',                            // 取消对消息/通知的屏蔽
  'Permission Denied': '权限被拒绝',                  // 操作权限被系统拒绝

  'Refresh Stations': '刷新基站列表',                  // 刷新中继站/基站列表
  'Refreshing all stations': '所有站点正在刷新，下一次将自动连接最快的站点。', // 刷新站点的提示

  'Shared': '已分享',                                // 分享操作完成
  'Forwarded': '已转发',                              // 转发操作完成

  'Notice': '请注意',                                // 提示/通知（语气偏正式）
  'Input Name': '请输入名字',                        // 提示输入名称
  'Input text message': '请输入文本消息',              // 提示输入聊天消息

  // 底部标签栏翻译
  'Chats': '聊天',                                  // 聊天页面
  'Contacts': '联系人',                              // 联系人页面
  'Me': '我',                                        // 个人中心页面
  'Services': '服务',                                // 服务页面
  'Service Bots': '服务机器人',                      // 服务机器人页面

  // 联系人页面翻译
  'New Friends': '新的朋友',                          // 新朋友/好友请求页面
  'Group Chats': '群组聊天',                          // 群聊列表
  'Blocked List': '屏蔽列表',                        // 被屏蔽的联系人列表
  'Muted List': '静音列表',                          // 静音的联系人/群组列表

  'Search User': '搜索用户',                          // 搜索用户功能
  'Input ID or nickname to search': '输入用户ID或昵称进行搜索', // 搜索用户的提示
  'Data Empty': '数据为空',                          // 列表无数据的提示

  // 设置页面翻译
  'Settings': '设置',                                // 设置页面
  'Export': '导出账号',                              // 导出用户账号
  'Mnemonic': '助记词',                              // 助记词（同Mnemonic Codes）
  'Language': '语言',                                // 语言设置
  'Brightness': '亮度',                              // 屏幕亮度设置
  'Network': '网络',                                // 网络设置
  'Relay Stations': '中继站',                        // 网络中继站设置
  'Open Source': '开源代码',                          // 开源代码页面
  'Terms': '服务条款',                              // 服务条款页面
  'Privacy Policy': '隐私政策',                      // 隐私政策页面
  'About': '关于',                                  // 关于页面

  'Edit Profile': '修改个人资料',                      // 编辑个人资料
  'Change Avatar': '更换头像',                        // 更换个人头像
  'Update & Broadcast': '更新并广播',                  // 更新资料并广播给好友

  'System': '系统',                                  // 系统设置
  'Light': '浅色',                                  // 浅色主题
  'Dark': '深色',                                    // 深色主题

  //
  //  聊天框相关翻译
  //
  'Hold to Talk': '按住说话',                        // 按住按钮发语音
  'Release to Send': '松开发送',                      // 松开按钮发送语音
  'Release to Cancel': '松开取消',                    // 松开按钮取消发送

  'View More Members': '查看更多群组成员',            // 查看群聊的更多成员
  'Group Members (@count)': '群组成员 (@count)',      // 群成员（@count为成员数量占位符）
  'Non-Member': '非会员',                            // 非群成员/非会员（此处应为"非群成员"更准确）
  'Image Not Found': '图片不存在',                    // 图片文件不存在
  'Failed to load image @filename': '无法读取图片"@filename"。', // 加载图片失败（@filename为文件名占位符）

  'Forward Rich Text': '转发富文本消息',              // 转发带格式的文本消息
  'Forward Text': '转发文本消息',                    // 转发纯文本消息
  'Forward Image': '转发图片',                        // 转发图片消息
  'Forward Video': '转发视频',                        // 转发视频消息
  'Forward Web Page': '转发网页',                    // 转发网页链接
  'Forward Name Card': '转发名片',                    // 转发联系人名片
  'Forward Service': '转发服务',                      // 转发服务链接

  'Text message forwarded to @chat': '文本消息已转发至 "@chat"。', // 文本消息转发成功（@chat为聊天对象占位符）
  'Failed to share text with @chat': '未能与 "@chat" 分享文本消息。', // 文本消息转发失败

  'Image message forwarded to @chat': '图片消息已转发给 "@chat"。', // 图片消息转发成功
  'Failed to share image with @chat': '无法转发图片给 "@chat"。', // 图片消息转发失败

  'Video message forwarded to @chat': '视频消息已转发给"@chat"。', // 视频消息转发成功（标点不统一：缺少空格）
  'Failed to share video with @chat': '无法与"@chat"分享视频。', // 视频消息转发失败（标点不统一：缺少空格）

  'Web Page @title forwarded to @chat': '网页 "@title" 已转发给 "@chat"。', // 网页转发成功（@title为网页标题占位符）
  'Failed to share Web Page @title with @chat': '无法转发网页 "@title" 给 "@chat"。', // 网页转发失败

  'Name Card @name forwarded to @chat': '名片 "@name" 已转发给 "@chat"。', // 名片转发成功（@name为联系人名称占位符）
  'Failed to share Name Card @name with @chat': '无法转发名片 "@name" 给 "@chat"。', // 名片转发失败

  'Service @title forwarded to @chat': '服务“@title”已转发到“@chat”。', // 服务转发成功（标点不统一：使用全角引号）
  'Failed to share Service @title with @chat': '无法与“@chat”共享服务“@title”。', // 服务转发失败（标点不统一：全角引号）

  'Chat Details': '聊天资料',                        // 聊天/群聊的详情页面
  'Group Chat Details (@count)': '群聊资料 (@count)',  // 群聊详情（@count为成员数量）
  'Group Name': '群组名称',                          // 群聊名称
  'Owner': '群主',                                  // 群聊的创建者/拥有者
  'Administrators': '管理员',                        // 群管理员
  'Invitations': '邀请函',                            // 加入群组的邀请

  'Select Participants': '选择与会人员',              // 选择参与聊天/会议的人
  'Select a Chat': '选择一个会话',                    // 选择一个聊天对象/群聊

  'Recall Message': '撤回消息',                      // 撤回已发送的消息
  'Sure to recall this message?': '确定撤回此消息吗？'
      '（此操作可能不会成功）', // 撤回消息的确认提示

  'Delete Message': '删除消息',                      // 删除消息
  'Sure to delete this message?': '确定要删除这条消息吗？（此操作不可恢复）', // 删除消息的确认提示

  'Video error': '视频错误',                          // 视频播放/加载错误
  'Download not supported': '暂不支持下载',            // 不支持下载功能

  'Encrypting': '加密中',                            // 消息正在加密
  'Decrypting': '解密中',                            // 消息正在解密

  'Waiting to upload': '数据已加密，等待上传',        // 消息加密完成，等待上传
  'Waiting to send': '等待发送（点击重试）',          // 消息等待发送（可点击重试）
  'No response': '无应答（点击重新发送）',            // 发送无响应（可点击重发）
  'Stranded': '未发送（点击重新发送）',              // 消息发送失败（可点击重发）
  'Encrypted and sent to relay station': '已加密并发送到中继站', // 消息加密并发送至中继站
  'Message is rejected': '消息被拒收',                // 消息被接收方拒收
  'Safely delivered': '已安全送达',                  // 消息安全送达
  'Safely delivered to @count members': '已安全送达 @count 位成员', // 群消息送达成功（@count为成员数）

  'Draft': '草稿',                                  // 未发送的消息草稿
  'Mentioned': '有人@我',                            // 被他人@提醒

  'Translate': '翻译',                              // 消息翻译功能

  //
  //  视频播放器相关翻译
  //
  'Video Player': '视频播放器',                      // 视频播放组件
  'Loading "@url"': '正在加载 "@url" ...',            // 正在加载视频（@url为视频链接占位符）
  'Failed to load "@url".': '无法加载 "@url"。',       // 视频加载失败

  'Select TV': '选择电视',                          // 选择投屏的电视设备
  'TV not found': '未找到电视',                      // 未发现可投屏的电视
  'Search again': '重新搜索',                        // 重新搜索设备
  'Refresh': '刷新',                                // 刷新设备列表

  //
  //  网页浏览器相关翻译
  //
  'Cannot launch "@url".': '无法启动 "@url"。',        // 无法打开网页（@url为链接占位符）
  'Failed to launch "@url".': '启动 "@url" 失败。',    // 打开网页失败

  //
  //  检查更新相关翻译
  //
  'Please update app (@version, build @build).': '请更新应用到最新版本 (@version, 构建号 @build)。', // 更新提示（@version版本号，@build构建号）
  'Upgrade': '升级',                                // 应用升级
  'Download': '下载',                                // 下载更新包

  'Current version not support this service': '当前版本不支持此服务，请更新到最新版本。', // 版本不兼容提示

  //
  //  个人资料相关翻译
  //
  'Remark': '备注',                                  // 对联系人的备注名称
  'Block Messages': '拦截消息',                      // 拦截联系人的消息
  'Mute Notifications': '屏蔽通知',                  // 屏蔽联系人的消息通知

  'Send Message': '发送消息',                        // 给联系人发消息
  'Clear History': '清空聊天记录',                    // 清空与联系人的聊天记录
  'Add Contact': '加为好友',                        // 将用户添加为好友
  'Share Contact': '分享联系人',                    // 分享联系人信息
  'Delete Contact': '删除联系人',                    // 删除联系人
  'Quit Group': '退出群组',                          // 退出群聊
  'Report': '举报',                                  // 举报违规联系人/群聊

  'Cannot block this contact': '无法屏蔽此联系人。',  // 屏蔽联系人失败

  'Contact @name shared to @chat': '联系人 "@name" 已分享给 "@chat"。', // 分享联系人成功
  'Failed to share contact @name with @chat': '无法分享联系人 "@name" 给 "@chat"。', // 分享联系人失败

  'Profile is updated': '您的资料文件已更新并广播给所有朋友。', // 个人资料更新成功
  'Failed to update profile': '无法更新个人资料文件。', // 个人资料更新失败

  'Failed to get private key': '无法获取私钥。',      // 获取加密私钥失败
  'Failed to get visa': '无法获取个人资料文件。',      // 获取个人签证/资料文件失败
  'Failed to save visa': '我发保存个人资料文件。',    // 保存个人资料失败（原错别字："我发"应为"无法"）

  //
  //  提示语相关翻译
  //
  'Please input group name': '请输入群名称',          // 提示输入群聊名称
  'Please input alias': '请输入别名',                // 提示输入别名/昵称
  'Please review invitations': '请先审查邀请函',      // 提示先审核邀请

  'Current user not found': '未找到当前用户。',        // 未找到当前登录用户
  'Failed to add contact': '添加联系人失败。',        // 添加联系人失败
  'Failed to remove contact': '移除联系人失败。',      // 移除联系人失败
  'Failed to remove friend': '移除朋友失败。',        // 移除好友失败

  'Failed to add administrators': '添加管理员失败。',  // 添加群管理员失败

  'Invited by': '邀请人',                            // 邀请者
  'Invitation sent': '新的邀请函已发送给所有管理员，请耐心等待审核。', // 邀请已发送提示

  'Sure to reject all invitations?': '确定拒绝所有邀请吗？', // 拒绝所有邀请的确认提示

  'Sure to add this friend?': '确定要添加这个朋友吗？', // 添加好友的确认提示
  'Sure to remove this friend?': '确定要删除这个朋友吗？该操作将同时清除聊天记录。', // 删除好友的确认提示
  'Sure to remove this group?': '确定要删除这个群组吗？该操作将同时清除聊天记录。', // 删除群组的确认提示

  'Sure to clear chat history of this friend?': '确定要清除该朋友的聊天记录吗？该操作无法撤销。', // 清空好友聊天记录的确认提示
  'Sure to clear chat history of this group?': '确定要清除该群组的聊天记录吗？该操作无法撤销。', // 清空群聊记录的确认提示
  'Failed to clear chat history': '无法清除聊天记录。', // 清空聊天记录失败

  'Sure to remove this conversation?': '确定要删除此对话吗？此操作不可恢复。', // 删除会话的确认提示
  'Failed to remove conversation': '删除对话失败。',    // 删除会话失败

  'Failed to set remark': '设置备注失败。',            // 设置联系人备注失败

  'Never receive message from this contact': '您将不再接收该联系人的消息。', // 不再接收联系人消息的提示
  'Receive message from this contact': '现在开始可以接收该联系人的消息。', // 恢复接收联系人消息的提示

  'Never receive notification from this contact': '您将不再接收来自该联系人消息的通知。', // 屏蔽联系人通知的提示
  'Receive notification from this contact': '现在开始可以接收来自该联系人消息的通知。', // 恢复联系人通知的提示

  'Grant to access external storage': '您需要授予访问外部存储的权限。请允许创建本地存储的数据库。', // 申请外部存储权限
  'Grant to access photo album': '您需要授予访问照片相册的权限。请允许发送相册中的照片或更改您的个人资料图片，或将图片保存到您的相册。', // 申请相册权限
  'Grant to access camera': '您需要授予访问相机的权限。请允许拍摄照片并发送给朋友，或更改您的个人资料图片。', // 申请相机权限
  'Grant to access microphone': '您需要授予访问麦克风的权限。请允许录制语音消息并发送给您的朋友。', // 申请麦克风权限
  'Grant to allow notifications': '您需要授予允许通知的权限。请允许推送通知以接收离线消息。', // 申请通知权限

  'Notification': '通知',                            // 系统通知
  'Enabled': '已启用',                                // 功能已启用
  'Disabled': '已禁用',                              // 功能已禁用

  'Failed to get image file': '获取图片文件失败。',    // 获取图片文件失败
  'Cannot save this image': '无法保存此图片。',        // 保存图片失败

  'Failed to send command': '发送命令失败。',          // 发送操作命令失败

  'Sure to remove this station (@remote)?': '确定要移除此站点 (@remote) 吗？', // 删除中继站的确认提示（@remote为站点标识）
  'Station (@remote) is removed': '站点 (@remote) 已被移除。', // 中继站删除成功
  'Failed to remove station (@remote)': '移除站点 (@remote) 失败。', // 中继站删除失败
  'Cannot remove this station': '无法移除此站点。',    // 无法删除中继站

  'Add': '添加',                                    // 添加操作
  'New Station': '新中继站',                          // 添加新的中继站

  'Failed to add station': '添加新中继站失败。',      // 添加中继站失败
  'Please input station host': '请输入新中继站IP。',  // 提示输入中继站IP
  'Please input station port': '请输入新中继站端口号。', // 提示输入中继站端口
  'Station host error': '中继站IP错误。',            // 中继站IP格式错误
  'Port number error': '中继站端口号错误。',          // 中继站端口格式错误

  'Invite command error': '邀请命令错误。',            // 邀请命令执行错误
  'Expel command error': '驱逐命令错误。',            // 踢出成员命令错误

  'Unsupported group command: @cmd': '不支持的群组命令: @cmd。', // 不支持的群命令（@cmd为命令占位符）

  '"@commander" reset group': '"@commander" 已更新群组成员。', // 群成员更新提示（@commander为操作人）
  '"@commander" join group': '"@commander" 想要加入该群组。', // 申请入群提示
  '"@commander" left group': '"@commander" 离开了该群组。', // 成员退群提示
  '"@commander" invite "@members"': '"@commander" 正邀请 "@members" 加入该群组。', // 邀请入群提示（@members为被邀请人）
  '"@commander" invite "@member"': '"@commander" 正邀请 "@member" 加入该群组。', // 邀请入群提示（@member为单个被邀请人）
  '"@commander" expel "@members"': '"@commander" 正在驱逐成员 "@members" 出该群组。', // 踢出成员提示
  '"@commander" expel "@member"': '"@commander" 正在驱逐成员 "@member" 出该群组。', // 踢出单个成员提示

  //
  //  缓存文件管理相关翻译
  //
  'Storage': '存储',                                // 存储空间/存储管理
  'Cache Files Management': '缓存文件管理',          // 缓存文件管理页面

  'Total Cached Data': '总缓存数据',                  // 缓存数据总量
  'Cache Files': '缓存文件',                          // 缓存文件
  'Database': '数据库',                              // 本地数据库文件
  'Avatars': '头像',                                  // 缓存的头像图片
  'Message Files': '消息文件',                        // 缓存的消息文件（图片/视频等）
  'Temporary Files': '临时文件',                      // 应用生成的临时文件
  'Upload Directory': '上传目录',                      // 文件上传目录
  'Download Directory': '下载目录',                  // 文件下载目录

  'Contains @count file, totaling @size': '包含 @count 个文件，总计 @size。', // 文件统计（单数）
  'Contains @count files, totaling @size': '包含 @count 个文件，总计 @size。', // 文件统计（复数）

  'Scan': '扫描',                                    // 扫描缓存文件
  'Clear': '清除',                                  // 清除缓存文件

  'Sure to clear all avatar images?': '确定要清除所有头像图片吗？', // 清除头像缓存的确认提示
  'Sure to clear all message files?': '确定要清除所有消息文件吗？此操作无法恢复！', // 清除消息缓存的确认提示
  'Sure to clear these temporary files?': '确定要清除这些临时文件吗？', // 清除临时文件的确认提示

  'CacheFiles::Description': '* 头像和消息文件会存储在您的设备上。\n'
      '* 网络传输的消息文件已加密，中间节点（如中继站）无法解密。\n'
      '* 一旦您从本地存储中删除这些文件，除非您要求发送者重新发送，否则将无法恢复。\n'
      '* 请注意，我们的文件中继服务器仅会将消息文件的加密版本缓存最多 7 天。\n'
      '* 因此，请谨慎处理这些数据。', // 缓存文件说明

  'TemporaryFiles::Description': '* 当应用程序上传或下载文件时，会生成临时文件，'
      '通常在必要时由系统自动清除。\n'
      '* 如果您希望立即删除它们，也可以在此手动清除。', // 临时文件说明

  //
  //  页脚说明相关翻译
  //
  'ServiceBotList::Description': '* 这里展示了已经过审核的服务机器人，其中一些来自第三方提供商;\n'
      '* 如果你发现其中存在不法行为，请点击右上角的“举报”按钮取证举报;\n'
      '* 任何人都可以开发并提供此类服务，只要他们遵循 DIMP 协议;\n'
      '* 如果您想创建自己的服务机器人，我们邀请您阅读 DIMP 文档，从 GitHub 下载示例项目，或直接与 "Albert Moky" 联系。', // 服务机器人列表说明

  'ChatBox::Description': '该应用程序由DIM（去中心化端到端加密）技术提供支持。'
      '您的消息将在发送前进行加密，除了接收者，没有人能解密内容。', // 聊天框安全说明

  'ChatBox::Remind': '请勿在此聊天应用中发送任何违法信息，包括但不限于淫秽、诈骗或威胁内容。'
      '如果发现违法信息，请点击右上角按钮举报。'
      '维护良好交流环境，共同遵守法律法规，谢谢！', // 聊天框合规提醒

  'ChatList::Description': '* 这里只显示你朋友的聊天记录；\n'
      '* 陌生人将被放置在 "联系人 -> 新的朋友" 中。', // 聊天列表说明

  'Strangers::Description': '* 这里展示了想和你交朋友的陌生人；\n'
      '* 你可以将它们添加到你的联系人中，也可以忽略它们。', // 陌生人列表说明

  'GroupList::Description': '* 这里显示您所有群组的聊天记录。', // 群组列表说明

  'BlockList::Description': '* 这里显示你屏蔽的用户；\n'
      '* 您将永远不会收到来自此列表的消息。', // 黑名单说明

  'MuteList::Description': '* 这里展示了那些你不太重视的吵闹的朋友；\n'
      '* 您仍然可以与他们聊天，但不会收到来自此列表的通知。', // 静音列表说明

  'Mnemonic::Description': '* 助记词是你的私钥，任何得到这些单词的人都可以拥有你的账户；\n'
      '* 你可以把它写在一张纸上，并保存在安全的地方，不建议将其截图保存在电脑中。', // 助记词安全说明

  'Administrators::Description': '规则：\n'
      '  1、群主或管理员可以查看邀请；\n'
      '  2、群主或管理员可以直接添加/删除成员；\n'
      '  3、群主可以雇佣/解雇管理员，管理员可以自行辞职；\n'
      '  4、群主可以编辑群组名称；\n'
      '  5、群主不能离开该群组；\n'
      '  6、管理员在辞职之前不能离开群组。', // 群管理员规则（"雇佣/解雇"表述偏口语）

  'Invitations::Description': '规则：\n'
      '  1、群主或管理员可以直接添加成员；\n'
      '  2、其他成员可以创建邀请并等待管理员审核；\n'
      '  3、任何管理员都可以确认邀请并刷新成员列表。', // 群邀请规则

  'BurnAfterReading::Description': '规则：\n'
      '  1. 设置一个时间段，应用会自动删除该时间之前的所有消息和文件；\n'
      '  2. 删除的消息和文件无法恢复，所以请谨慎使用此功能；\n'
      '  3. 设置为手动模式将不再自动删除消息和文件。', // 阅后即焚规则（标点混用：顿号/点）

  'RelayStations::Description': '规则:\n'
      '  1. 选择响应速度最快的站点作为当前中继站;\n'
      '  2. 如果选择了一些站点，则从已选择的站点中选择速度最快的一个;\n'
      '  3. 如果没有选择站点，则自动从所有站点中进行选择。', // 中继站选择规则（缺少冒号）

  'UpdateVisa::Description': '注意：\n'
      '  1. 头像图片将上传至公共文件服务器，供大家下载；\n'
      '  2. 更新个人资料时，需要主动广播给您的联系人列表中的每个人，'
      ' 因为没有中央服务器为您处理此事。', // 资料更新说明
};