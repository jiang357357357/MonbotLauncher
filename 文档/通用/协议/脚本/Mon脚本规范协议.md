# Mon 项目脚本规范协议

**版本**: 1.1.0 | **更新日期**: 2026-04-17

---

## 1. 状态标识符系统

### 格式规范
```
[OPERATION_STATUS:STATE]
```

### 标准状态标识符

| 脚本类型 | 状态标识符 |
|---------|-----------|
| 环境检查 | `[ENV_STATUS:INSTALLED]` `[ENV_STATUS:NOT_INSTALLED]` |
| 环境安装 | `[INSTALL_STATUS:SUCCESS]` `[INSTALL_STATUS:FAILED]` |
| 环境删除 | `[REMOVE_STATUS:SUCCESS]` `[REMOVE_STATUS:FAILED]` `[REMOVE_STATUS:NOTHING]` |
| 服务启动 | `[SERVER_STATUS:STARTED]` `[SERVER_STATUS:STOPPED]` `[SERVER_STATUS:FAILED]` |
| 服务停止 | `[STOP_STATUS:SUCCESS]` `[STOP_STATUS:NOT_RUNNING]` `[STOP_STATUS:FAILED]` |
| 数据库迁移 | `[DB_STATUS:MIGRATED]` `[DB_STATUS:FAILED]` |
| 打包脚本 | `[PACK_STATUS:SUCCESS]` `[PACK_STATUS:FAILED]` |

---

## 2. 进程管理规范

### 进程标识符定义

| 模块 | 进程标识符 |
|------|-----------|
| MonCore | `MonCore-Django` |
| MonHub | `MonHub-Service` |
| MonOs | `MonOs-Service` |

### 进程标识符输出

```powershell
# 启动时
[PROCESS_NAME:MonCore-Django]
[PROCESS_PID:12345]           # 可选
[SERVER_STATUS:STARTED]

# 停止时
[PROCESS_NAME:MonCore-Django]
[STOP_STATUS:SUCCESS]
```

### 解析正则
```regex
\[PROCESS_NAME:([A-Za-z0-9_-]+)\]
\[PROCESS_PID:(\d+)\]
\[([A-Z_]+_STATUS):([A-Z_]+)\]
```

---

## 3. 输出格式规范

### 颜色编码

| 状态 | 颜色 | 符号 |
|------|------|------|
| 成功 | Green | ✓ |
| 失败 | Red | ✗ |
| 警告 | Yellow | ⚠ |
| 信息 | Cyan | • |
| 进度 | Magenta | [n/m] |

### 标准参数
- `$NoWait` - 不等待用户按回车（用于自动化调用）

### 退出码
- `0` - 成功
- `1` - 失败

---

## 4. 信息返回机制

### 输出流规范
- **标准输出 (stdout)**: 所有状态标识符、进程信息、正常日志
- **标准错误 (stderr)**: 错误堆栈、异常信息

### 返回信息结构
调用程序应从脚本输出中解析以下信息：

```json
{
  "exitCode": 0,
  "processName": "MonCore-Django",
  "processPid": 12345,
  "status": "STARTED",
  "operation": "SERVER_STATUS",
  "output": "完整的标准输出",
  "error": "错误信息（如果有）"
}
```

### 解析示例 (C#)
```csharp
public class ScriptResult
{
    public int ExitCode { get; set; }
    public string ProcessName { get; set; }
    public int? ProcessPid { get; set; }
    public string Status { get; set; }
    public string Output { get; set; }
}

// 解析脚本输出
var processMatch = Regex.Match(output, @"\[PROCESS_NAME:([A-Za-z0-9_-]+)\]");
var pidMatch = Regex.Match(output, @"\[PROCESS_PID:(\d+)\]");
var statusMatch = Regex.Match(output, @"\[([A-Z_]+_STATUS):([A-Z_]+)\]");

var result = new ScriptResult
{
    ExitCode = exitCode,
    ProcessName = processMatch.Success ? processMatch.Groups[1].Value : null,
    ProcessPid = pidMatch.Success ? int.Parse(pidMatch.Groups[1].Value) : null,
    Status = statusMatch.Success ? statusMatch.Groups[2].Value : null,
    Output = output
};
```

---

## 5. 脚本模板

### PowerShell 启动脚本
```powershell
param([switch]$NoWait)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProcessName = "MonCore-Django"

Write-Host "[PROCESS_NAME:$ProcessName]" -ForegroundColor Cyan
Write-Host "启动服务..." -ForegroundColor Cyan

# 启动逻辑...

Write-Host "[PROCESS_NAME:$ProcessName]" -ForegroundColor Green
Write-Host "[SERVER_STATUS:STARTED]" -ForegroundColor Green
```

### PowerShell 停止脚本
```powershell
param([switch]$NoWait)

$ProcessName = "MonCore-Django"
$process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

if ($process) {
    Stop-Process -Name $ProcessName -Force
    Write-Host "[PROCESS_NAME:$ProcessName]" -ForegroundColor Green
    Write-Host "[STOP_STATUS:SUCCESS]" -ForegroundColor Green
} else {
    Write-Host "[PROCESS_NAME:$ProcessName]" -ForegroundColor Yellow
    Write-Host "[STOP_STATUS:NOT_RUNNING]" -ForegroundColor Yellow
}
```

---

## 6. 环境变量配置

```env
# MonCore
MONCORE_PROCESS_NAME=MonCore-Django
MONCORE_START=MonBack\MonCore\scripts\Start\start_moncore.ps1
MONCORE_STOP=MonBack\MonCore\scripts\Start\stop_moncore.ps1

# MonHub
MONHUB_PROCESS_NAME=MonHub-Service
MONHUB_START=MonBack\MonHub\Script\main\start_monhub.ps1
MONHUB_STOP=MonBack\MonHub\Script\main\stop_monhub.ps1

# MonOs
MONOS_PROCESS_NAME=MonOs-Service
MONOS_START=MonBack\MonOs\Script\main\start_monos.ps1
MONOS_STOP=MonBack\MonOs\Script\main\stop_monos.ps1
```

---

**注意**: 所有脚本必须遵循此规范以确保系统的一致性和可维护性。
