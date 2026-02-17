# BananaHabit 推送服务（简版）

这是一个运行在 macOS 的 APNs 推送服务。

## 1. 准备

- macOS
- Python 3
- Apple 开发者账号里的 APNs `.p8` 密钥

## 2. 配置

```bash
cd macos_push_server
cp .env.example .env
```

编辑 `.env`，至少填这几个：

- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_AUTH_KEY_PATH`
- `APNS_BUNDLE_ID`
- `APNS_ENV`（开发机调试用 `development`）

## 3. 启动服务

```bash
cd macos_push_server
python3 server.py
```

## 4. App 里设置

1. 打开 App 的远程推送设置。
2. 把服务器地址设为你 Mac 的局域网 IP（例如 `http://192.168.31.217:8787`）。
3. 保存后重新注册推送。

## 5. 发送测试推送

发给所有已注册设备：

```bash
cd macos_push_server
./send_push.sh -t "BananaHabit" -b "测试推送" --all
```

发给单个设备：

```bash
./send_push.sh -t "BananaHabit" -b "测试推送" --token <device_token>
```

## 说明

- 真机可以收到推送（模拟器不行）。
- Xcode 真机调试通常用 `APNS_ENV=development`。
- TestFlight / App Store 版本请改为 `APNS_ENV=production`。
