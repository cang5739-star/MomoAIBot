<#
.SYNOPSIS
    Momo AI Bot - GitHub 自动部署与构建脚本
.DESCRIPTION
    将项目推送到 GitHub，触发 GitHub Actions 自动编译为 .deb 包
#>

Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Momo AI Bot - GitHub 自动部署脚本       ║" -ForegroundColor Cyan
Write-Host "║   适用于 Windows 用户（无需 Theos 环境）   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 检查 Git
Write-Host "[1/4] 检查 Git..." -ForegroundColor Yellow
$gitVer = git --version 2>$null
if (-not $gitVer) {
    Write-Host "❌ 请先安装 Git: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Git: $gitVer" -ForegroundColor Green

# 步骤 2: GitHub 仓库配置
Write-Host ""
Write-Host "[2/4] GitHub 仓库配置" -ForegroundColor Yellow
Write-Host ""
Write-Host "请在浏览器中完成以下步骤：" -ForegroundColor White
Write-Host "  1. 打开 https://github.com/new" -ForegroundColor Gray
Write-Host "  2. 仓库名: MomoAIBot" -ForegroundColor Gray
Write-Host "  3. 选择 Private 或 Public" -ForegroundColor Gray
Write-Host "  4. 不要勾选任何初始化选项" -ForegroundColor Gray
Write-Host "  5. 点击 Create repository" -ForegroundColor Gray
Write-Host ""

$githubUser = Read-Host "请输入你的 GitHub 用户名"
$repoName = Read-Host "请输入仓库名称 (默认: MomoAIBot)"
if (-not $repoName) { $repoName = "MomoAIBot" }

$remoteUrl = "https://github.com/$githubUser/$repoName.git"
Write-Host "`n仓库 URL: $remoteUrl" -ForegroundColor Cyan

# 步骤 3: 推送代码
Write-Host ""
Write-Host "[3/4] 推送代码到 GitHub..." -ForegroundColor Yellow

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

# 检查是否已有 remote
$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    Write-Host "已存在 remote origin: $existingRemote" -ForegroundColor Gray
    $overwrite = Read-Host "是否覆盖? (y/n)"
    if ($overwrite -eq 'y') {
        git remote set-url origin $remoteUrl
    }
} else {
    git remote add origin $remoteUrl
}

# 推送到 GitHub
Write-Host "正在推送代码到 GitHub..." -ForegroundColor Cyan
git branch -M main 2>$null
git push -u origin main 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 代码推送成功!" -ForegroundColor Green
} else {
    Write-Host "❌ 推送失败。请检查：" -ForegroundColor Red
    Write-Host "  1. GitHub 用户名和仓库名是否正确" -ForegroundColor Yellow
    Write-Host "  2. 是否已登录 GitHub (可能需要配置 Personal Access Token)" -ForegroundColor Yellow
    Write-Host "  3. 仓库是否已创建" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "如果未登录，请配置 token:" -ForegroundColor Cyan
    Write-Host "  1. 访问 https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host '  2. 生成 token，勾选 repo 权限' -ForegroundColor Gray
    Write-Host '  3. 运行: git remote set-url origin https://TOKEN@github.com/$githubUser/$repoName.git' -ForegroundColor Gray
    Write-Host "  4. 重新运行本脚本" -ForegroundColor Gray
    exit 1
}

# 步骤 4: 完成
Write-Host ""
Write-Host "[4/4] 构建状态" -ForegroundColor Yellow
Write-Host ""
Write-Host "🎉 代码已推送！GitHub Actions 正在自动构建..." -ForegroundColor Green
Write-Host ""
Write-Host "查看构建进度:" -ForegroundColor Cyan
Write-Host "  https://github.com/$githubUser/$repoName/actions" -ForegroundColor White
Write-Host ""
Write-Host "下载 .deb 文件:" -ForegroundColor Cyan
Write-Host "  1. 打开上方链接" -ForegroundColor Gray
Write-Host "  2. 点击正在运行的 Workflow" -ForegroundColor Gray
Write-Host "  3. 滚动到 Artifacts 部分" -ForegroundColor Gray
Write-Host "  4. 下载 momo-aibot-deb" -ForegroundColor Gray
Write-Host ""
Write-Host "安装到 iPhone:" -ForegroundColor Cyan
Write-Host "  解压后得到 .deb 文件，通过 Filza 安装或 SSH 执行:" -ForegroundColor Gray
Write-Host "  dpkg -i com.momo.aibot_1.0.0_iphoneos-arm.deb" -ForegroundColor Gray
Write-Host "  killall SpringBoard" -ForegroundColor Gray
