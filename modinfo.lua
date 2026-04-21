name = "Hotpotfish's Enhanced Controller"
description = [[强化手柄功能，包含虚拟光标、地图自动寻路、按钮组合和游戏内配置。

控制变更与映射请见：CONTROL_CHANGE_TRACKING.md

主要操作：
• 键盘：Ctrl+K 打开配置界面；地图中可用鼠标左键选点、滚轮缩放、拖拽平移
• 手柄：LB+RB+Y 打开配置界面；LB+RB+RT 切换虚拟光标
• 地图：打开地图后点击目标自动寻路，关闭地图不会中止移动
• 视角：LB + 右摇杆上下缩放，LB + 右摇杆左右旋转
• 常用组合：LB + A 攻击，LB + Y 检查，RB + B / X / Y 切换装备
• 虫洞：自动记录配对并在地图上显示编号

配置文件位置：
client_save/enhanced_controller_config.json
]]

author = "hotpotfish"
version = "3.0.0"

forumthread = ""
api_version = 10

dst_compatible = true
client_only_mod = true
all_clients_require_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {}

-- 所有配置都通过游戏内配置界面进行设置（Ctrl+K 或 LB+RB+Y）
configuration_options = {}
