// 定义南非荷兰语的语言标识常量
const String langAfrikaans = 'Afrikaans';

/// 南非荷兰语-南非 国际化翻译映射表
/// 键：通用英文标识 | 值：对应的南非荷兰语翻译
final Map<String, String> intlAfZa = {

  // 'OK': 'OK',
  // 'Customer Service': 'Customer Service',
  // '@total friends': '@total friends',

  //
  //  注册相关翻译
  //
  'Register': 'Registreer Rekening',                 // 注册账户
  'Import': 'Invoer Rekening',                       // 导入账户
  'Name': 'Naam',                                     // 姓名
  'Nickname': 'Bysnaam',                             // 昵称
  'Your nickname': 'Jou bynaam',                     // 你的昵称

  'Please choose your avatar': 'Kies asseblief \'n prentjie as jou avatar.', // 请选择你的头像
  'Please input your nickname': 'Voer asseblief jou bynaam in.',           // 请输入你的昵称
  'Please agree the privacy policy': 'Lees asseblief die privaatheidspolitiek en stem daarmee in.', // 请同意隐私政策
  'Failed to import account': 'Kon nie rekening invoer nie, kontroleer asseblief jou mnemoniese kodes.', // 导入账户失败，请检查你的助记词
  'Failed to generate ID': 'Kon nie ID genereer nie.', // 生成ID失败

  'Mnemonic Codes': 'Mnemoniese Kodes',               // 助记词
  'MnemonicCodes::Description': 'Mnemonies is die privaatsleutel vir \'n bestaande rekening,'
      ' as jy nie een het nie, klik asseblief op die "Registreer" knoppie in die boonste regterhoek om \'n nuwe een te genereer.', // 助记词是现有账户的私钥，如果你没有，请点击右上角的"注册"按钮生成新的

  'Show': 'Wys',                                     // 显示
  'Hide': 'Verberg',                                 // 隐藏
  'Accept': 'Aanvaar',                               // 接受/同意

  //
  //  图片相关翻译
  //
  'Camera': 'Kamera',                                 // 相机
  'Album': 'Album',                                   // 相册
  'Gallery': 'Galerie',                               // 图库
  'Pick Image': 'Kies Beeld',                         // 选择图片
  'Image File Error': 'Beeldlêer Fout',               // 图片文件错误
  'Upload Failed': 'Oplaai Misluk',                   // 上传失败

  'Save to Album': 'Stoor in Album',                 // 保存到相册
  'Sure to save this image?': 'Is jy seker jy wil hierdie beeld stoor?', // 确定要保存这张图片吗？
  'Image saved to album': 'Beeld suksesvol gestoor in album.', // 图片已成功保存到相册
  'Failed to save image to album': 'Kon nie die beeld stoor in jou album nie.', // 无法将图片保存到你的相册

  //
  //  时间相关翻译
  //
  'AM': 'VM',                                         // 上午 (Voor Middag)
  'PM': 'NM',                                         // 下午 (Nadat Middag)
  'Yesterday': 'Gister',                             // 昨天

  'Monday': 'Maandag',                               // 星期一
  'Tuesday': 'Dinsdag',                              // 星期二
  'Wednesday': 'Woensdag',                           // 星期三
  'Thursday': 'Donderdag',                           // 星期四
  'Friday': 'Vrydag',                                // 星期五
  'Saturday': 'Saterdag',                            // 星期六
  'Sunday': 'Sondag',                                // 星期日

  '@several seconds': '@several sekondes',           // 几秒前
  '@several minutes': '@several minute',             // 几分钟前
  '@several hours': '@several ure',                  // 几小时前
  '@several days': '@several dae',                   // 几天前
  '@several months': '@several maande',              // 几个月前

  'Daily': '24 uur',    // 'Dagelijks',               // 每日/24小时
  'Anon': '3 dae',                                   // 匿名/3天
  'Weakly': '7 dae',    // 'Weekliks',                // 每周/7天 (原拼写错误: Weakly 应为 Weekly)
  'Monthly': '30 dae',  // 'Maandeliks',              // 每月/30天
  'Manually': 'Handmatig',                           // 手动

  'Burn After Reading': 'Brand Na Lees',             // 阅后即焚

  //
  //  连接状态相关翻译
  //
  'Waiting': 'Wag',                                   // 等待
  'Connecting': 'Konnekteer',                         // 正在连接
  'Connected': 'Gekonnekteer',                       // 已连接
  'Handshaking': 'Identifiseer',                     // 握手/身份验证
  'Disconnected': 'Ongekonnekteer',                   // 已断开连接

  //
  //  弹窗/提示框相关翻译
  //
  'Cancel': 'Kanselleer',                             // 取消
  'Confirm': 'Bevestig',                             // 确认
  'Confirm Add': 'Bevestig Voeg By',                 // 确认添加
  'Confirm Delete': 'Bevestig Verwydering',           // 确认删除
  'Confirm Share': 'Bevestig Deling',                 // 确认分享
  'Confirm Forward': 'Bevestig Deurstuur',           // 确认转发

  'Continue': 'Gaan voort',                           // 继续
  'Deny': 'Weier',                                   // 拒绝
  'Allow': 'Toestaan',                               // 允许

  'Success': 'Sukses',                               // 成功
  'Error': 'Fout',                                   // 错误

  'Fatal Error': 'Fatale Fout',                       // 致命错误

  'Blocked': 'Geblokkeer',                           // 已拉黑
  'Unblocked': 'Ongeblokkeer',                       // 已解除拉黑
  'Muted': 'Onderdruk',                             // 已静音
  'Unmuted': 'Nie Onderdruk Nie',                     // 已取消静音
  'Permission Denied': 'Toestemming Geweier',         // 权限被拒绝

  'Refresh Stations': 'Verfris Koppelstasies',       // 刷新中继站
  'Refreshing all stations': 'Die vinnigste stasie sal volgende keer outomaties gekoppel word.', // 刷新所有中继站，下次将自动连接最快的站点

  'Shared': 'Suksesvol Gedeel',                       // 分享成功
  'Forwarded': 'Suksesvol Deurgestuur',               // 转发成功

  'Notice': 'Kennisgewing',                           // 通知/提示
  'Input Name': 'Voer Naam In',                       // 输入名称
  'Input text message': 'Voer teksboodskap in',       // 输入文字消息

  // 底部标签栏翻译
  'Chats': 'Geselskap',                               // 聊天
  'Contacts': 'Kontakte',                             // 联系人
  'Me': 'Ek',                                         // 我
  'Services': 'Dienste',                             // 服务
  'Service Bots': 'Diensbots',                       // 服务机器人

  // 联系人页面翻译
  'New Friends': 'Nuwe Vriende',                     // 新朋友
  'Group Chats': 'Groep Geselskappe',                 // 群聊
  'Blocked List': 'Geblokkeerde Lys',                 // 黑名单
  'Muted List': 'Onderdrukte Lys',                   // 静音列表

  'Search User': 'Soek Gebruiker',                   // 搜索用户
  'Input ID or nickname to search': 'Voer gebruiker ID of bynaam in om te soek', // 输入用户ID或昵称进行搜索

  'Data Empty': 'Data is leeg',                       // 数据为空

  // 设置页面翻译
  'Settings': 'Instellings',                         // 设置
  'Export': 'Voer Rekening Uit',                     // 导出账户
  'Mnemonic': 'Mnemoniese',                           // 助记词
  'Language': 'Taal',                                 // 语言
  'Brightness': 'Helderheid',                         // 亮度
  'Network': 'Netwerk',                               // 网络
  'Relay Stations': 'Koppelstasies',                 // 中继站
  'Open Source': 'Oopbron',                           // 开源
  'Terms': 'Voorwaardes',                             // 条款
  'Privacy Policy': 'Privaatheidsbeleid',             // 隐私政策
  'About': 'Oor',                                     // 关于

  'Edit Profile': 'Wysig Profiel',                   // 编辑资料
  'Change Avatar': 'Verander Avatar',                 // 更换头像
  'Update & Broadcast': 'Opdateer & Uitsaai',         // 更新并广播

  'System': 'Sisteem',                               // 系统
  'Light': 'Lig',                                     // 浅色
  'Dark': 'Donker',                                   // 深色

  //
  //  聊天框相关翻译
  //
  'Hold to Talk': 'Hou om Te Praat',                 // 按住说话
  'Release to Send': 'Laat Los om Te Stuur',         // 松开发送
  'Release to Cancel': 'Laat Los om Te Kanselleer',   // 松开取消

  'View More Members': 'Sien Meer Lede',             // 查看更多成员
  'Group Members (@count)': 'Groep Lede (@count)',   // 群成员(@count)
  'Non-Member': 'Nie-Lid',                           // 非群成员
  'Image Not Found': 'Beeld Nie Gevind Nie',         // 图片未找到
  'Failed to load image @filename': 'Kon nie beeld "@filename" laai nie.', // 无法加载图片@filename

  'Forward Rich Text': 'Stuur \'n ryk teksboodskap', // 转发富文本消息
  'Forward Text': 'Stuur Teksboodskap Deur',         // 转发文字消息
  'Forward Image': 'Stuur Beeld Voort',               // 转发图片
  'Forward Video': 'Stuur video',                     // 转发视频
  'Forward Web Page': 'Stuur Webblad Voort',         // 转发网页
  'Forward Name Card': 'Stuur Naamkaartjie Voort',   // 转发名片
  'Forward Service': 'Stuur Diens Vooruit',           // 转发服务

  'Text message forwarded to @chat': 'Teksboodskap is na "@chat" gestuur.', // 文字消息已转发至@chat
  'Failed to share text with @chat': 'Versoek om teksboodskap met "@chat" te deel, het gefaal.', // 无法与@chat分享文字消息

  'Image message forwarded to @chat': 'Beeldboodskap is na "@chat" deurgestuur.', // 图片消息已转发至@chat
  'Failed to share image with @chat': 'Kon nie beeld deel met "@chat" nie.', // 无法与@chat分享图片

  'Video message forwarded to @chat': 'Videoboodskap is na "@chat" gestuur.', // 视频消息已转发至@chat
  'Failed to share video with @chat': 'Kon nie video deel met "@chat".', // 无法与@chat分享视频 (原句末尾缺少 nie)

  'Web Page @title forwarded to @chat': 'Webblad "@title" is na "@chat" deurgestuur.', // 网页@title已转发至@chat
  'Failed to share Web Page @title with @chat': 'Kon nie webblad "@title" deel met "@chat" nie.', // 无法与@chat分享网页@title

  'Name Card @name forwarded to @chat': 'Naamkaartjie "@name" is na "@chat" deurgestuur.', // 名片@name已转发至@chat
  'Failed to share Name Card @name with @chat': 'Kon nie naamkaartjie "@name" deel met "@chat" nie.', // 无法与@chat分享名片@name

  'Service @title forwarded to @chat': 'Diens "@title" is vorentoe gestuur na "@chat".', // 服务@title已转发至@chat
  'Failed to share Service @title with @chat': 'Kon nie diens "@title" met "@chat" deel nie.', // 无法与@chat分享服务@title

  'Chat Details': 'Geselskap Besonderhede',           // 聊天详情
  'Group Chat Details (@count)': 'Groep Geselskap Besonderhede (@count)', // 群聊详情(@count)
  'Group Name': 'Groep Naam',                         // 群名称
  'Owner': 'Eienaar',                                 // 群主/拥有者
  'Administrators': 'Administrateurs',               // 管理员
  'Invitations': 'Uitnodigings',                       // 邀请

  'Select Participants': 'Kies Deelnemers',           // 选择参与者
  'Select a Chat': 'Kies \'n Geselskap',               // 选择一个聊天

  'Recall Message': 'Herroep Boodskap',               // 撤回消息
  'Sure to recall this message?': 'Is u seker dat u hierdie boodskap wil herroep?'
      ' (hierdie aksie kan moontlik nie suksesvol wees nie)', // 确定要撤回这条消息吗？(此操作可能无法成功)

  'Delete Message': 'Vee boodskap uit',               // 删除消息
  'Sure to delete this message?': 'Is jy seker jy wil hierdie boodskap uitvee?'
      ' (hierdie aksie kan nie teruggedraai word nie)', // 确定要删除这条消息吗？(此操作不可撤销)

  'Video error': 'Video fout',                         // 视频错误
  'Download not supported': 'Aflaai word nog nie ondersteun nie', // 暂不支持下载

  'Encrypting': 'Enkripteer',                         // 正在加密
  'Decrypting': 'De-enkipteer',                       // 正在解密

  'Waiting to upload': 'Data is enkripteer, wag om te stuur', // 数据已加密，等待发送
  'Waiting to send': 'Wag om te stuur (tik om te herprobeer)', // 等待发送(点击重试)
  'No response': 'Geen reaksie (tik om weer te stuur)', // 无响应(点击重发)
  'Stranded': 'Gestrand (tik om weer te stuur)',       // 发送失败(点击重发)
  'Encrypted and sent to relay station': 'Versleutel en gestuur na relaaisender', // 已加密并发送至中继站
  'Message is rejected': 'Boodskap word afgekeur',     // 消息被拒绝
  'Safely delivered': 'Veilig afgelewer',             // 安全送达
  'Safely delivered to @count members': 'Veilig afgelewer aan @count lid/lidmate', // 已安全送达@count位成员

  'Draft': 'Konsep',                                 // 草稿
  'Mentioned': 'Jy is genoem',                       // 你被@了

  'Translate': 'Vertaal',                             // 翻译

  //
  //  视频播放器相关翻译
  //
  'Video Player': 'Video Speler',                     // 视频播放器

  'Loading "@url"': 'Laai "@url" ...',                 // 正在加载@url
  'Failed to load "@url".': 'Kon nie "@url" laai nie.', // 无法加载@url

  'Select TV': 'Kies TV',                             // 选择电视
  'TV not found': 'TV nie gevind nie',                 // 未找到电视
  'Search again': 'Soek weer',                         // 重新搜索
  'Refresh': 'Herlaai',                               // 刷新

  //
  //  网页浏览器相关翻译
  //
  'Cannot launch "@url".': 'Kan nie "@url" oopmaak nie.', // 无法打开@url
  'Failed to launch "@url".': 'Kon nie "@url" oopmaak nie.', // 打开@url失败

  //
  //  检查更新相关翻译
  //
  'Please update app (@version, build @build).': 'Dateer asseblief die toepassing op na die nuutste weergawe (@version, bou @build).', // 请更新应用至最新版本(@version, build @build)
  'Upgrade': 'Opgradering',                           // 升级
  'Download': 'Aflaai',                               // 下载

  'Current version not support this service': 'Die huidige weergawe ondersteun nie hierdie diens nie, werk asseblief op na die nuutste weergawe.', // 当前版本不支持此服务，请升级至最新版本

  //
  //  个人资料相关翻译
  //
  'Remark': 'Opmerking',                             // 备注
  'Block Messages': 'Blokkeer Boodskappe',           // 屏蔽消息
  'Mute Notifications': 'Demper Kennisgewings',       // 静音通知

  'Send Message': 'Stuur Boodskap',                   // 发送消息
  'Clear History': 'Vee Geskiedenis Af',             // 清空历史记录
  'Add Contact': 'Voeg Kontak By',                   // 添加联系人
  'Share Contact': 'Deel Kontak',                     // 分享联系人
  'Delete Contact': 'Verwyder Kontak',               // 删除联系人
  'Quit Group': 'Verlaat Groep',                     // 退出群组
  'Report': 'Verslag',                               // 举报

  'Cannot block this contact': 'Kan nie hierdie kontak blokkeer nie.', // 无法屏蔽此联系人

  'Contact @name shared to @chat': 'Kontak "@name" gedeel na "@chat".', // 联系人@name已分享至@chat
  'Failed to share contact @name with @chat': 'Kon nie kontak "@name" deel met "@chat" nie.', // 无法与@chat分享联系人@name

  'Profile is updated': 'Jou profiel is opgedateer en uitgesaai na al jou vriende!', // 你的资料已更新并广播给所有好友！
  'Failed to update profile': 'Kon nie profiel opdateer nie.', // 无法更新资料

  'Failed to get private key': 'Kon nie privaatsleutel kry nie.', // 无法获取私钥
  'Failed to get visa': 'Kon nie visadokument kry nie.', // 无法获取签证文件
  'Failed to save visa': 'Kon nie visadokument stoor nie.', // 无法保存签证文件

  //
  //  提示语相关翻译
  //
  'Please input group name': 'Voer asseblief groepnaam in.', // 请输入群名称
  'Please input alias': 'Voer asseblief skuilnaam in.',     // 请输入别名
  'Please review invitations': 'Gaan asseblief eers deur die uitnodigings.', // 请先审核邀请

  'Current user not found': 'Huidige gebruiker nie gevind nie.', // 未找到当前用户
  'Failed to add contact': 'Dit was nie moontlik om kontak toe te voeg nie.', // 无法添加联系人
  'Failed to remove contact': 'Dit was nie moontlik om kontak te verwyder nie.', // 无法移除联系人
  'Failed to remove friend': 'Dit was nie moontlik om vriend te verwyder nie.', // 无法移除好友

  'Failed to add administrators': 'Dit was nie moontlik om administrateurs toe te voeg nie.', // 无法添加管理员

  'Invited by': 'Genooi deur',                         // 被邀请人
  'Invitation sent': ' \'n Nuwe uitnodiging is aan al die administrateurs gestuur, wag nou vir hersiening.', // 新的邀请已发送给所有管理员，等待审核

  'Sure to reject all invitations?': 'Is jy seker jy wil al hierdie uitnodigings weier?', // 确定要拒绝所有邀请吗？

  'Sure to add this friend?': 'Is jy seker jy wil hierdie vriend byvoeg?', // 确定要添加这位好友吗？
  'Sure to remove this friend?': 'Is jy seker jy wil hierdie vriend verwyder?'
      ' Hierdie aksie sal ook die geskiedenis van die geselskap skoonmaak.', // 确定要移除这位好友吗？此操作也会清除聊天历史
  'Sure to remove this group?': 'Is jy seker jy wil hierdie groep verwyder?'
      ' Hierdie aksie sal ook die geskiedenis van die geskiedenis skoonmaak.', // 确定要移除这个群组吗？此操作也会清除聊天历史 (原句重复 geskiedenis)

  'Sure to clear chat history of this friend?': 'Is jy seker jy wil die geskiedenis van hierdie vriend skoonmaak?'
      ' Hierdie aksie kan nie ongedaan gemaak word nie.', // 确定要清空这位好友的聊天记录吗？此操作不可撤销
  'Sure to clear chat history of this group?': 'Is jy seker jy wil die geskiedenis van hierdie groep skoonmaak?'
      ' Hierdie aksie kan nie ongedaan gemaak word nie.', // 确定要清空这个群组的聊天记录吗？此操作不可撤销
  'Failed to clear chat history': 'Kon nie geskiedenis skoonmaak nie.', // 无法清空聊天记录

  'Sure to remove this conversation?': 'Is jy seker jy wil hierdie gesprek verwyder? Hierdie aksie kan nie omgekeer word nie.', // 确定要移除这个会话吗？此操作不可撤销
  'Failed to remove conversation': 'Kon nie die gesprek verwyder nie.', // 无法移除会话

  'Failed to set remark': 'Kon nie opmerking stel nie.', // 无法设置备注

  'Never receive message from this contact': 'Jy sal nooit weer \'n boodskap van hierdie kontak ontvang nie.', // 你将不再收到此联系人的消息
  'Receive message from this contact': 'Jy kan nou boodskappe van hierdie kontak ontvang.', // 你现在可以接收此联系人的消息

  'Never receive notification from this contact': 'Jy sal nooit weer kennisgewings van hierdie kontak ontvang nie.', // 你将不再收到此联系人的通知
  'Receive notification from this contact': 'Jy kan nou kennisgewings van hierdie kontak ontvang.', // 你现在可以接收此联系人的通知

  'Grant to access external storage': 'Jy moet toestemming gee om toegang tot eksterne stoorruimte te verkry.'
      ' Please allow to create databases for local storage.', // 你需要授予访问外部存储的权限。请允许创建本地存储数据库
  'Grant to access photo album': 'Jy moet toestemming gee om toegang tot jou foto album te kry.'
      ' Please allow to send photos from your album or to change your profile picture,'
      ' or to save the image to your album.', // 你需要授予访问相册的权限。请允许从相册发送照片、更换头像或保存图片到相册
  'Grant to access camera': 'Jy moet toestemming gee om toegang tot die kamera te kry.'
      ' Please allow to take photos and send them to friends, or to change your profile picture.', // 你需要授予访问相机的权限。请允许拍照并发送给好友或更换头像
  'Grant to access microphone': 'Jy moet toestemming gee om toegang tot die mikrofoon te kry.'
      ' Please allow to record a voice message and send it to your friend.', // 你需要授予访问麦克风的权限。请允许录制语音消息并发送给好友
  'Grant to allow notifications': 'Jy moet toestemming gee om kennisgewings toe te laat.'
      ' Please allow for pushing notification for offline messages.', // 你需要授予允许通知的权限。请允许推送离线消息通知

  'Notification': 'Kennisgewing',                     // 通知
  'Enabled': 'Geaktiveer',                           // 已启用
  'Disabled': 'Deaktiveer',                           // 已禁用

  'Failed to get image file': 'Dit was nie moontlik om die beeldlêer te kry nie.', // 无法获取图片文件
  'Cannot save this image': 'Dit is nie moontlik om hierdie beeld te stoor nie.', // 无法保存此图片

  'Failed to send command': 'Dit was nie moontlik om die opdrag te stuur nie.', // 无法发送命令

  'Sure to remove this station (@remote)?': 'Is jy seker jy wil hierdie stasie (@remote) verwyder?', // 确定要移除这个中继站(@remote)吗？
  'Station (@remote) is removed': 'Stasie (@remote) is verwyder.', // 中继站(@remote)已移除
  'Failed to remove station (@remote)': 'Dit was nie moontlik om stasie (@remote) te verwyder nie.', // 无法移除中继站(@remote)
  'Cannot remove this station': 'Dit is nie moontlik om hierdie stasie te verwyder nie.', // 无法移除这个中继站

  'Add': 'Voeg by',                                   // 添加
  'New Station': 'Nuwe Relay Stasie',                 // 新增中继站

  'Failed to add station': 'Dit het gefaal om die nuwe relay stasie by te voeg.', // 添加新中继站失败
  'Please input station host': 'Voer die IP van die nuwe relay stasie in.', // 请输入新中继站的IP
  'Please input station port': 'Voer die poortnommer van die nuwe relay stasie in.', // 请输入新中继站的端口号
  'Station host error': 'Relay stasie IP fout.',       // 中继站IP错误
  'Port number error': 'Relay stasie poortnommer fout.', // 中继站端口号错误

  'Invite command error': 'Fout in die uitnodiging opdrag.', // 邀请命令错误
  'Expel command error': 'Fout in die uitwerp opdrag.',     // 踢出命令错误

  'Unsupported group command: @cmd': 'Nie-ondersteunde groep opdrag: @cmd.', // 不支持的群组命令: @cmd

  '"@commander" reset group': '"@commander" het die groeplede opgedateer.', // "@commander"更新了群成员
  '"@commander" join group': '"@commander" wil by hierdie groep aansluit.', // "@commander"请求加入本群
  '"@commander" left group': '"@commander" het die groep verlaat.',         // "@commander"退出了本群
  '"@commander" invite "@members"': '"@commander" nooi "@members" uit om by hierdie groep aan te sluit.', // "@commander"邀请"@members"加入本群
  '"@commander" invite "@member"': '"@commander" nooi "@member" uit om by hierdie groep aan te sluit.',   // "@commander"邀请"@member"加入本群
  '"@commander" expel "@members"': '"@commander" verwerp die lede "@members" uit hierdie groep.',       // "@commander"将"@members"移出本群
  '"@commander" expel "@member"': '"@commander" verwerp die lid "@member" uit hierdie groep.',         // "@commander"将"@member"移出本群

  //
  //  缓存文件管理相关翻译
  //
  'Storage': 'Stoorplek',                             // 存储空间
  'Cache Files Management': 'Cache-lêerbestuur',       // 缓存文件管理

  'Total Cached Data': 'Totale Gestoorde Data',       // 缓存数据总量
  'Cache Files': 'Cache-lêers',                       // 缓存文件
  'Database': 'Databasis',                             // 数据库
  'Avatars': 'Avatarre',                               // 头像
  'Message Files': 'Boodskap-lêers',                   // 消息文件
  'Temporary Files': 'Tydelike Lêers',                 // 临时文件
  'Upload Directory': 'Oplaai-gids',                   // 上传目录
  'Download Directory': 'Aflaai-gids',                 // 下载目录

  'Contains @count file, totaling @size': 'Bevat @count lêer, met ’n totale grootte van @size.', // 包含@count个文件，总大小@size (单数)
  'Contains @count files, totaling @size': 'Bevat @count lêers, met ’n totale grootte van @size.', // 包含@count个文件，总大小@size (复数)

  'Scan': 'Deursoek',                                 // 扫描
  'Clear': 'Maak Skoon',                               // 清空

  'Sure to clear all avatar images?': 'Is jy seker jy wil alle avatar-afbeeldings skoonmaak?', // 确定要清空所有头像图片吗？
  'Sure to clear all message files?': 'Is jy seker jy wil alle boodskap-lêers skoonmaak? Hierdie aksie kan nie ongedaan gemaak word nie!', // 确定要清空所有消息文件吗？此操作不可撤销！
  'Sure to clear these temporary files?': 'Is jy seker jy wil hierdie tydelike lêers skoonmaak?', // 确定要清空这些临时文件吗？

  'CacheFiles::Description': '* Avatar-afbeeldings en boodskap-lêers word op jou toestel gestoor.\n'
      '* Die boodskap-lêers wat oor die netwerk gestuur word, is versleutel,'
      ' en kan nie deur tussenliggende knope, soos relaaisentrums, dekripteer word nie.\n'
      '* Wanneer jy hierdie lêers vanaf plaaslike stoorplek verwyder,'
      ' mag jy nie in staat wees om hulle te herstel tensy jy die sender vra om hulle weer te stuur nie.\n'
      '* Let daarop dat ons lêer-relaisbediener slegs die versleutelde weergawes van die boodskap-lêers vir tot 7 dae kan stoor.\n'
      '* Daarom, hanteer asseblief hierdie data met sorg.', // 缓存文件说明：* 头像图片和消息文件存储在你的设备上。* 通过网络发送的消息文件已加密，中继站等中间节点无法解密。* 从本地存储删除这些文件后，除非请求发送方重新发送，否则无法恢复。* 注意我们的文件中继服务器仅能存储加密后的消息文件副本最多7天。* 因此，请谨慎处理这些数据。

  'TemporaryFiles::Description': '* Wanneer die app lêers oplaai of aflaai,'
      ' skep dit tydelike lêers wat gewoonlik outomaties deur die stelsel skoongemaak word as dit nodig is.\n'
      '* Indien jy wil hê dat hulle onmiddellik verwyder moet word, kan jy ook kies om hulle hier handmatig te verwyder.', // 临时文件说明：* 应用上传或下载文件时会创建临时文件，系统通常会在需要时自动清理。* 如果你希望立即删除它们，也可以选择在此手动删除。

  //
  //  页脚说明相关翻译
  //
  'ServiceBotList::Description': '* Gekeurde diensbots word hier getoon, sommige van derdeparty verskaffers;\n'
      '* As jy enige onwettige gedrag ontdek, klik asseblief op die "Verslag" knoppie in die regter boonste hoek om bewyse te verkry en te rapporteer;\n'
      '* Enige iemand kan sulke dienste ontwikkel en aan die publiek bied solank hulle die DIMP-protokol volg;\n'
      '* As jy jou eie diensbot wil skep, nooi ons jou uit om die DIMP-dokumente te lees,'
      ' voorbeeldprojekte van GitHub af te laai, of direk met "Albert Moky" in verbinding te tree.', // 服务机器人列表说明：* 此处显示已审核的服务机器人，部分由第三方提供；* 如发现任何违规行为，请点击右上角"举报"按钮收集证据并举报；* 任何人只要遵循DIMP协议，都可以开发并提供此类服务；* 如果你想创建自己的服务机器人，我们邀请你阅读DIMP文档、从GitHub下载示例项目，或直接联系"Albert Moky"。

  'ChatBox::Description': 'Hierdie app word aangedryf deur DIM, \'n E2EE (End-to-End Versleutelde) tegnologie.'
      ' Jou boodskappe sal versleutel word voordat dit uitgestuur word, niemand kan die inhoud ontsluit nie, behalwe die ontvanger.', // 聊天框说明：本应用基于DIM（端到端加密）技术构建。你的消息在发送前会被加密，除接收方外，无人能解密内容。

  'ChatBox::Remind': 'Moet asseblief nie enige onwettige inligting in hierdie kletstoepassing stuur nie, insluitend maar nie beperk tot obseen, bedrog of dreigende inhoud.'
      ' As jy onwettige inligting vind, klik asseblief op die knoppie in die regter boonste hoek om dit te rapporteer.'
      ' Handhaaf \'n goeie kommunikasieomgewing en volg saam die wette en regulasies. Dankie!', // 聊天框提醒：请勿在此聊天应用中发送任何非法信息，包括但不限于色情、欺诈或威胁内容。如发现非法信息，请点击右上角按钮举报。维护良好的沟通环境，遵守法律法规。谢谢！

  'ChatList::Description': '* Hier toon geskiedenis van geselskappe met jou vriende alleenlik;\n'
      '* Vreemdelinge sal in "Kontakte -> Nuwe Vriende" geplaas word.', // 聊天列表说明：* 此处仅显示与好友的聊天历史；* 陌生人将出现在"联系人->新朋友"中。

  'Strangers::Description': '* Hier toon vreemdelinge wat vriende met jou wil maak;\n'
      '* Jy kan hulle by jou kontakte voeg, of eenvoudig ignoreer.', // 陌生人列表说明：* 此处显示想要添加你为好友的陌生人；* 你可以将他们添加到联系人，或直接忽略。

  'GroupList::Description': '* Hier toon geskiedenis van al jou groepe.', // 群组列表说明：* 此处显示你所有群组的历史记录。

  'BlockList::Description': '* Hier toon mense wat jy geblok het as gevolg van ongewenste boodskappe;\n'
      '* Jy sal nooit boodskappe van hierdie lys ontvang nie.', // 黑名单说明：* 此处显示因骚扰消息被你拉黑的人；* 你将不会收到此列表中的人的消息。

  'MuteList::Description': '* Hier toon vriende wat baie geluide maak en nie baie werd vir jou is nie;\n'
      '* Jy kan steeds met hulle gesels, maar jy sal nooit kennisgewings van hierdie lys ontvang nie.', // 静音列表说明：* 此处显示那些消息较多且对你不重要的好友；* 你仍可与他们聊天，但不会收到此列表中的人的通知。

  'Mnemonic::Description': '* Mnemonies is jou privaatsleutel; enigiemand wat hierdie woorde het, kan jou rekening besit;\n'
      '* Jy kan dit op \'n stuk papier skryf en dit op \'n veilige plek bewaar,'
      ' om dit op \'n rekenaar af te neem en te stoor, word nie aanbeveel nie.', // 助记词说明：* 助记词是你的私钥；任何人拥有这些单词，都可以掌控你的账户；* 你可以将其写在纸上并保存在安全的地方，不建议在电脑上记录和存储。

  'Administrators::Description': 'Reëls:\n'
      '  1. Eienaar of administrateurs kan uitnodigings hersien;\n'
      '  2. Eienaar of administrateurs kan lede direk byvoeg/verwyder;\n'
      '  3. Eienaar kan administrateurs aanstel/ontslaan, administrateurs kan self bedank;\n'
      '  4. Eienaar kan die groep se naam wysig;\n'
      '  5. Eienaar kan nie die groep verlaat nie;\n'
      '  6. Administrateur kan nie die groep verlaat voordat hy afgetree is nie.', // 管理员规则：1. 群主或管理员可审核邀请；2. 群主或管理员可直接添加/移除成员；3. 群主可任命/罢免管理员，管理员可自行辞职；4. 群主可修改群名称；5. 群主不能退出群组；6. 管理员在卸任前不能退出群组。

  'Invitations::Description': 'Reëls:\n'
      '  1. Eienaar of administrateurs kan lede direk byvoeg;\n'
      '  2. Ander lede kan uitnodigings skep en wag vir hersiening deur administrateurs;\n'
      '  3. Enige administrateur kan die uitnodigings bevestig en die lede lys opdateer.', // 邀请规则：1. 群主或管理员可直接添加成员；2. 其他成员可创建邀请并等待管理员审核；3. 任何管理员都可确认邀请并更新成员列表。

  'BurnAfterReading::Description': 'Reëls:\n'
      '  1. Stel \'n tydperk vas, en die app sal outomaties alle boodskappe en lêers voor daardie tydperk uitvee;\n'
      '  2. Uitgevee boodskappe en lêers kan nie herstel word nie, gebruik hierdie funksie dus met omsigtigheid;\n'
      '  3. Instelling na handleiding sal nie meer boodskappe en lêers outomaties uitvee nie.', // 阅后即焚规则：1. 设置一个时间段，应用将自动删除该时间段前的所有消息和文件；2. 删除的消息和文件无法恢复，请谨慎使用此功能；3. 设置为手动后将不再自动删除消息和文件。

  'RelayStations::Description': 'Reëls:\n'
      '  1. Die stasie met die vinnigste reaksie sal gekies word as die huidige relaaisender;\n'
      '  2. As sommige stasies gekies is, sal die vinnigste een van die gekose stasies gekies word;\n'
      '  3. As daar geen stasies gekies is nie, kies outomaties van alle stasies.', // 中继站规则：1. 响应最快的站点将被选为当前中继站；2. 如果选择了部分站点，将从所选站点中选择最快的一个；3. 如果未选择任何站点，将自动从所有站点中选择。

  'UpdateVisa::Description': 'Kennisgewing:\n'
      '  1. Die avatar prent sal op \'n openbare lêerbediener opgelaai word sodat almal dit kan aflaai;\n'
      '  2. Wanneer jy jou profiel opdateer, moet jy dit proaktief aan almal in jou kontaklys uitzend,'
      ' aangesien daar geen sentrale bediener is wat dit vir jou sal doen nie.', // 更新签证说明：1. 头像图片将上传至公共文件服务器，以便所有人下载；2. 更新资料时，你需要主动向联系人列表中的所有人广播，因为没有中央服务器会为你完成此操作。
};