# ══════════════════════════════════════════════════════════
# MomoAIBot .deb 打包脚本 (Windows PowerShell)
# 需要: Theos (iOS越狱开发环境) 或 dpkg-deb
# ══════════════════════════════════════════════════════════

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LayoutDir = Join-Path $ProjectDir "layout"
$DebFile = Join-Path $ProjectDir "..\..\outputs\com.momo.aibot_1.0.0_iphoneos-arm.deb"

Write-Host "🔨 MomoAIBot .deb 打包工具" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

# 检查 layout 目录
if (-not (Test-Path $LayoutDir)) {
    Write-Host "❌ 错误: layout 目录不存在" -ForegroundColor Red
    exit 1
}

# 选项 1: 使用 Theos (macOS/Linux 推荐)
$UseTheos = $false
if (Get-Command "make" -ErrorAction SilentlyContinue) {
    Write-Host "📦 检测到 Theos 环境，尝试使用 make 编译..." -ForegroundColor Yellow
    $UseTheos = $true
}

# 选项 2: 使用 dpkg-deb (需要 WSL 或 Linux)
$UseDpkg = $false
if (Get-Command "dpkg-deb" -ErrorAction SilentlyContinue) {
    Write-Host "📦 检测到 dpkg-deb，直接打包..." -ForegroundColor Yellow
    $UseDpkg = $true
}

if ($UseTheos) {
    # Theos 方式
    Push-Location $ProjectDir
    try {
        make package
        Write-Host "✅ Theos 打包完成!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Theos 编译失败: $_" -ForegroundColor Red
        Write-Host "尝试使用 dpkg-deb 直接打包..." -ForegroundColor Yellow
    }
    Pop-Location
} elseif ($UseDpkg) {
    # dpkg-deb 方式 (WSL/Linux)
    $LayoutDir_Unix = $LayoutDir -replace '\\', '/' -replace 'C:', '/mnt/c'
    $DebFile_Unix = $DebFile -replace '\\', '/' -replace 'C:', '/mnt/c'
    
    # 确保 postinst/prerm 有执行权限
    & chmod 755 "$LayoutDir/DEBIAN/postinst" 2>$null
    & chmod 755 "$LayoutDir/DEBIAN/prerm" 2>$null
    
    # 打包
    & dpkg-deb -b "$LayoutDir_Unix" "$DebFile_Unix"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ .deb 打包成功!" -ForegroundColor Green
        Write-Host "📦 输出: $DebFile" -ForegroundColor Green
    } else {
        Write-Host "❌ dpkg-deb 失败" -ForegroundColor Red
        exit 1
    }
} else {
    # 手动构建 .deb 文件 (ar + tar)
    Write-Host "⚠️  未检测到 Theos 或 dpkg-deb" -ForegroundColor Yellow
    Write-Host "  将在 macOS/Linux 上使用 Theos 环境进行编译" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "📋 手动编译步骤:" -ForegroundColor Cyan
    Write-Host "  1. 将项目复制到 macOS/Linux 设备" -ForegroundColor White
    Write-Host "  2. 安装 Theos: git clone https://github.com/theos/theos.git" -ForegroundColor White
    Write-Host "  3.  cd 到项目目录" -ForegroundColor White
    Write-Host "  4. 执行: make package" -ForegroundColor White
    Write-Host "  5. 生成的 .deb 在 packages/ 目录下" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "📂 项目结构已完整生成，可直接在 Theos 环境中编译" -ForegroundColor Green
    Write-Host "  源文件路径: $ProjectDir" -ForegroundColor Green
}

Write-Host ""
Write-Host "📂 项目文件清单:" -ForegroundColor Cyan
Get-ChildItem -Path $ProjectDir -Recurse -File | ForEach-Object {
    Write-Host "  $($_.FullName)" -ForegroundColor Gray
}
