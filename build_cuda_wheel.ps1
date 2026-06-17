#!/usr/bin/env powershell
# 本地编译 CUDA 版本的 llama-cpp-python whl 包（包含自定义修改）
#
# 使用场景：当你修改了 vendor/llama.cpp 的功能，需要编译包含这些修改的 wheel 包

# ============================================================================
# 第一步：准备工作
# ============================================================================

Write-Host "========================================" -ForegroundColor Green
Write-Host "步骤 1: 准备编译环境" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 1.1 检查 Python 版本
$pythonVersion = python --version
Write-Host "Python版本: $pythonVersion" -ForegroundColor Yellow

# 1.2 检查 CUDA 是否安装
if (-not $env:CUDA_PATH) {
    Write-Host "错误: CUDA_PATH 环境变量未设置" -ForegroundColor Red
    Write-Host "请先安装 CUDA Toolkit 并设置环境变量" -ForegroundColor Red
    Write-Host "示例: $env:CUDA_PATH = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8'" -ForegroundColor Yellow
    exit 1
}

Write-Host "CUDA路径: $env:CUDA_PATH" -ForegroundColor Yellow

# 1.3 检查 Visual Studio
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
if (-not (Test-Path $vsPath)) {
    $vsPath = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools"
}

if (-not (Test-Path $vsPath)) {
    Write-Host "错误: 未找到 Visual Studio 2022" -ForegroundColor Red
    Write-Host "请安装 Visual Studio 2022 Build Tools" -ForegroundColor Red
    exit 1
}

Write-Host "Visual Studio: $vsPath" -ForegroundColor Yellow

# ============================================================================
# 第二步：确保 submodule 包含你的修改
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "步骤 2: 检查 llama.cpp submodule" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 2.1 检查 submodule 状态
Write-Host "检查 submodule 状态..." -ForegroundColor Yellow
git submodule status vendor/llama.cpp

# 2.2 如果你有未提交的修改，提醒你
$llamaCppPath = "vendor/llama.cpp"
Push-Location $llamaCppPath
$hasChanges = git status --porcelain
if ($hasChanges) {
    Write-Host "警告: llama.cpp submodule 有未提交的修改" -ForegroundColor Red
    Write-Host "这些修改会被包含在编译中" -ForegroundColor Yellow
    Write-Host "建议先提交修改以确保追踪" -ForegroundColor Yellow
} else {
    Write-Host "llama.cpp submodule 状态正常" -ForegroundColor Green
}
Pop-Location

# ============================================================================
# 第三步：设置编译环境
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "步骤 3: 设置编译环境" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 3.1 设置 CUDA 相关环境变量
$env:CUDA_HOME = $env:CUDA_PATH
$env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH
Write-Host "CUDA_HOME: $env:CUDA_HOME" -ForegroundColor Yellow

# 3.2 设置 MSVC 环境（关键步骤！）
Write-Host "设置 MSVC 环境..." -ForegroundColor Yellow
$vcvarsallPath = "$vsPath\VC\Auxiliary\Build\vcvarsall.bat"

if (-not (Test-Path $vcvarsallPath)) {
    Write-Host "错误: 未找到 vcvarsall.bat" -ForegroundColor Red
    Write-Host "路径: $vcvarsallPath" -ForegroundColor Red
    exit 1
}

# 执行 vcvarsall.bat 并导入环境变量
cmd /c "call `"$vcvarsallPath`" x64 && set" | ForEach-Object {
    if ($_ -match "=") {
        $parts = $_.split("=", 2)
        $varName = $parts[0]
        $varValue = $parts[1]
        Set-Item -force -path "ENV:\$varName" -value "$varValue"
    }
}

Write-Host "MSVC 环境已设置" -ForegroundColor Green

# 3.3 安装必要的 Python 包
Write-Host "安装构建工具..." -ForegroundColor Yellow
pip install --upgrade pip build wheel setuptools packaging scikit-build-core ninja

# ============================================================================
# 第四步：配置编译参数
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "步骤 4: 配置 CUDA 编译参数" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 4.1 选择 CUDA 架构（根据你的 GPU）
Write-Host "请选择你的 GPU 系列:" -ForegroundColor Yellow
Write-Host "  1. RTX 20系列 (2070, 2080) - 架构 75"
Write-Host "  2. RTX 30系列 (3070, 3080, 3090) - 架构 80,86,87"
Write-Host "  3. RTX 40系列 (4070, 4080, 4090) - 架构 89,90"
Write-Host "  4. 所有架构（通用包）"

$gpuChoice = Read-Host "请输入选择 (1-4)"

switch ($gpuChoice) {
    "1" {
        $env:CUDAARCHS = "75-real"
        Write-Host "已选择: RTX 20系列"
    }
    "2" {
        $env:CUDAARCHS = "80-real;86-real;87-real"
        Write-Host "已选择: RTX 30系列"
    }
    "3" {
        $env:CUDAARCHS = "89-real;90-real"
        Write-Host "已选择: RTX 40系列"
    }
    "4" {
        $env:CUDAARCHS = "75-real;80-real;86-real;87-real;89-real;90-real;100-real;120-real"
        Write-Host "已选择: 所有架构（通用包）"
    }
    default {
        Write-Host "使用默认配置: RTX 30系列"
        $env:CUDAARCHS = "80-real;86-real;87-real"
    }
}

Write-Host "CUDA架构: $env:CUDAARCHS" -ForegroundColor Yellow

# 4.2 设置 CMake 参数（生产级配置）
Write-Host "设置 CMake 参数..." -ForegroundColor Yellow

$cmakeArgs = @(
    # CUDA 后端
    '-DGGML_CUDA=ON'
    '-DGGML_CUDA_FORCE_MMQ=ON'

    # 动态加载后端（重要！）
    '-DGGML_BACKEND_DL=ON'
    '-DGGML_CPU_ALL_VARIANTS=ON'

    # 通用性（不绑定特定 CPU）
    '-DGGML_NATIVE=OFF'

    # OpenMP 支持
    '-DGGML_OPENMP=ON'

    # CUDA 架构
    "-DCMAKE_CUDA_ARCHITECTURES=$env:CUDAARCHS"

    # 禁用不需要的构建目标
    '-DLLAMA_BUILD_EXAMPLES=OFF'
    '-DLLAMA_BUILD_TESTS=OFF'
    '-DLLAMA_BUILD_SERVER=OFF'
    '-DLLAMA_BUILD_UI=OFF'
    '-DLLAMA_USE_PREBUILT_UI=OFF'
    '-DLLAMA_CURL=OFF'

    # 编译优化
    '-DCMAKE_BUILD_PARALLEL_LEVEL=12'  # 并行编译
)

$env:CMAKE_ARGS = $cmakeArgs -join ' '
Write-Host "CMAKE_ARGS: $env:CMAKE_ARGS" -ForegroundColor Cyan

# 4.3 设置其他环境变量
$env:VERBOSE = '1'              # 详细日志
$env:CMAKE_GENERATOR = 'Ninja'  # 使用 Ninja（更快）
$env:MAX_JOBS = 12              # 最大并行任务

Write-Host "VERBOSE: $env:VERBOSE" -ForegroundColor Yellow
Write-Host "CMAKE_GENERATOR: $env:CMAKE_GENERATOR" -ForegroundColor Yellow

# ============================================================================
# 第五步：开始编译
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "步骤 5: 编译 wheel 包" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "开始编译... (这可能需要10-30分钟)" -ForegroundColor Yellow
Write-Host "请耐心等待..." -ForegroundColor Yellow

# 5.1 清理之前的构建
if (Test-Path "build") {
    Write-Host "清理之前的构建..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "build"
}

if (Test-Path "dist") {
    Write-Host "清理之前的 dist..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "dist" -ErrorAction SilentlyContinue
}

# 5.2 开始构建
Write-Host "`n运行构建命令..." -ForegroundColor Green
python -m build --wheel

# 5.3 检查构建结果
if (-not (Test-Path ".\dist\*.whl")) {
    Write-Host "`n错误: 构建失败，未生成 wheel 包" -ForegroundColor Red
    Write-Host "请检查上面的错误日志" -ForegroundColor Red
    exit 1
}

Write-Host "`n成功! wheel 包已生成" -ForegroundColor Green

# ============================================================================
# 第六步：处理生成的 wheel 包
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "步骤 6: 处理 wheel 包" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 6.1 获取生成的 wheel 文件
$wheelFile = Get-Item ".\dist\*.whl" | Select-Object -First 1
Write-Host "生成的 wheel: $wheelFile" -ForegroundColor Yellow

# 6.2 显示包信息
$parts = $wheelFile.Name.Split('-')
$distName = $parts[0]
$version = $parts[1]
$pyTag = $parts[2]
$abiTag = $parts[3]
$platTag = $parts[4]

Write-Host "`n包信息:" -ForegroundColor Cyan
Write-Host "  名称: $distName"
Write-Host "  版本: $version"
Write-Host "  Python: $pyTag"
Write-Host "  ABI: $abiTag"
Write-Host "  平台: $platTag"

# 6.3 可选：重命名包含 CUDA 版本信息
$cudaVersion = $env:CUDA_PATH.Split('\')[-1].Replace('v', '').Split('.')[0..1] -join ''
$newVersion = "$version+cu$cudaVersion-custom"  # 添加 custom 标记
$newName = "$distName-$newVersion-$pyTag-$abiTag-$platTag"

Write-Host "`n是否重命名 wheel 包以包含 CUDA 版本标记?" -ForegroundColor Yellow
Write-Host "建议: Y (便于区分)" -ForegroundColor Yellow
$renameChoice = Read-Host "重命名? (Y/N)"

if ($renameChoice -eq 'Y' -or $renameChoice -eq 'y') {
    Rename-Item -Path $wheelFile.FullName -NewName $newName
    $wheelFile = Get-Item ".\dist\$newName"
    Write-Host "已重命名为: $newName" -ForegroundColor Green
}

# 6.4 显示包内容（验证）
Write-Host "`n检查包内容..." -ForegroundColor Yellow
Write-Host "解压查看..." -ForegroundColor Yellow

$tempDir = "temp_wheel_check"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}

python -m wheel unpack $wheelFile.FullName -d $tempDir

Write-Host "`n关键 DLL 文件:" -ForegroundColor Cyan
$dllFiles = Get-ChildItem "$tempDir\*\llama_cpp\lib\*.dll" -ErrorAction SilentlyContinue

if ($dllFiles) {
    $dllFiles | ForEach-Object {
        Write-Host "  $($_.Name)"
    }

    # 检查 CUDA DLL 是否存在
    $cudaDll = $dllFiles | Where-Object { $_.Name -like "*cuda*" }
    if ($cudaDll) {
        Write-Host "`n✓ CUDA 后端已包含" -ForegroundColor Green
    } else {
        Write-Host "`n✗ 警告: 未找到 CUDA DLL" -ForegroundColor Red
    }

    # 检查 CPU 变体
    $cpuVariants = $dllFiles | Where-Object { $_.Name -like "ggml-cpu-*" }
    Write-Host "✓ CPU 变体数量: $($cpuVariants.Count)" -ForegroundColor Green
}

# 清理临时目录
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

# ============================================================================
# 第七步：测试安装
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "步骤 7: 测试安装" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "是否安装并测试 wheel 包?" -ForegroundColor Yellow
$testChoice = Read-Host "测试安装? (Y/N)"

if ($testChoice -eq 'Y' -or $testChoice -eq 'y') {
    Write-Host "`n安装 wheel 包..." -ForegroundColor Yellow
    pip uninstall llama-cpp-python -y -ErrorAction SilentlyContinue
    pip install $wheelFile.FullName --force-reinstall

    Write-Host "`n测试导入..." -ForegroundColor Yellow
    python -c "from llama_cpp import Llama; print('导入成功!')"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ 测试通过!" -ForegroundColor Green
    } else {
        Write-Host "`n✗ 测试失败" -ForegroundColor Red
    }
}

# ============================================================================
# 完成！
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✓ 编译完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`n生成的 wheel 包位置:" -ForegroundColor Cyan
Write-Host "  $wheelFile" -ForegroundColor Yellow

Write-Host "`n包大小:" -ForegroundColor Cyan
$size = (Get-Item $wheelFile).Length / 1MB
Write-Host "  $([math]::Round($size, 2)) MB" -ForegroundColor Yellow

Write-Host "`n下一步建议:" -ForegroundColor Cyan
Write-Host "  1. 在其他机器上测试安装" -ForegroundColor Yellow
Write-Host "  2. 发布到 GitHub Releases" -ForegroundColor Yellow
Write-Host "  3. 分发给其他用户" -ForegroundColor Yellow

Write-Host "`n注意事项:" -ForegroundColor Cyan
Write-Host "  - 确保 CUDA 版本匹配" -ForegroundColor Yellow
Write-Host "  - 确保 Python 版本匹配" -ForegroundColor Yellow
Write-Host "  - 包含了你的 llama.cpp 自定义修改" -ForegroundColor Yellow

Write-Host "`n安装命令示例:" -ForegroundColor Cyan
Write-Host "  pip install $wheelFile" -ForegroundColor Yellow