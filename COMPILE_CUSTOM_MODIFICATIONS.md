# 本地编译 CUDA 版本的 whl 包（包含自定义 llama.cpp 修改）

## 适用场景

当你修改了 `vendor/llama.cpp` 的功能，需要编译包含这些自定义修改的 wheel 包时使用本指南。

---

## 快速开始（推荐）

### Windows - 使用自动化脚本

```powershell
# 1. 克隆代码（包含你的修改）
cd J:/mickeylan/ai/llama-cpp-python

# 2. 运行自动化脚本
.\build_cuda_wheel.ps1
```

脚本会自动：
- ✅ 检查环境（CUDA, VS, Python）
- ✅ 检查 submodule 修改
- ✅ 设置编译参数
- ✅ 选择 GPU 架构
- ✅ 编译 wheel 包
- ✅ 验证包内容
- ✅ 可选测试安装

### Linux - 使用自动化脚本

```bash
# 1. 进入项目目录
cd J:/mickeylan/ai/llama-cpp-python

# 2. 运行自动化脚本
chmod +x build_cuda_wheel.sh
./build_cuda_wheel.sh
```

---

## 手动编译步骤

### 第一步：确保你的修改已保存

```powershell
# 检查 llama.cpp submodule 状态
cd J:/mickeylan/ai/llama-cpp-python
git submodule status vendor/llama.cpp

# 进入 submodule 查看修改
cd vendor/llama.cpp
git status

# 如果有未提交的修改，建议提交以便追踪
git add -A
git commit -m "Custom modifications for MTP support"
```

**重要**：未提交的修改仍然会被编译进去，但提交后更容易追踪。

### 第二步：设置 CUDA 环境（Windows）

```powershell
# 2.1 设置 CUDA 路径
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
$env:CUDA_HOME = $env:CUDA_PATH
$env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH

# 2.2 设置 MSVC 环境（关键！）
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
cmd /c "call `"$vsPath\VC\Auxiliary\Build\vcvarsall.bat`" x64 && set" | `
    ForEach-Object {
        if ($_ -match "=") {
            $v = $_.split("=", 2)
            Set-Item -force -path "ENV:\$($v[0])" -value "$($v[1])"
        }
    }

# 2.3 验证环境
nvcc --version  # 应显示 CUDA 版本
cl             # 应显示 MSVC 版本
```

### 第三步：配置编译参数

```powershell
# 3.1 选择 GPU 架构
# RTX 30系列
$env:CUDAARCHS = "80-real;86-real;87-real"

# RTX 40系列
# $env:CUDAARCHS = "89-real;90-real"

# 通用包（所有架构）
# $env:CUDAARCHS = "75-real;80-real;86-real;87-real;89-real;90-real;100-real;120-real"

# 3.2 设置 CMake 参数（包含自定义修改）
$env:CMAKE_ARGS = @(
    # CUDA 支持
    '-DGGML_CUDA=ON'
    '-DGGML_CUDA_FORCE_MMQ=ON'
    
    # 动态后端加载（重要！）
    '-DGGML_BACKEND_DL=ON'
    '-DGGML_CPU_ALL_VARIANTS=ON'
    
    # 通用性
    '-DGGML_NATIVE=OFF'
    
    # OpenMP
    '-DGGML_OPENMP=ON'
    
    # CUDA 架构
    "-DCMAKE_CUDA_ARCHITECTURES=$env:CUDAARCHS"
    
    # 优化构建
    '-DLLAMA_BUILD_EXAMPLES=OFF'
    '-DLLAMA_BUILD_TESTS=OFF'
    '-DLLAMA_BUILD_SERVER=OFF'
    '-DCMAKE_BUILD_PARALLEL_LEVEL=12'
) -join ' '

# 3.3 其他环境变量
$env:VERBOSE = '1'
$env:CMAKE_GENERATOR = 'Ninja'
$env:MAX_JOBS = 12
```

### 第四步：开始编译

```powershell
# 4.1 安装构建工具
pip install --upgrade pip build wheel setuptools packaging scikit-build-core ninja

# 4.2 清理旧构建
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue

# 4.3 编译 wheel 包
python -m build --wheel

# 预计时间：10-30分钟
# 详细日志会显示编译进度
```

### 第五步：验证编译结果

```powershell
# 5.1 检查生成的 wheel
ls dist\
$wheelFile = Get-Item "dist\*.whl" | Select-Object -First 1

# 5.2 解压检查内容
python -m wheel unpack $wheelFile.FullName -d temp_check
ls temp_check\*\llama_cpp\lib\*.dll

# 应包含：
# - ggml-cuda.dll  (CUDA 后端)
# - llama.dll      (主库)
# - ggml-cpu-*.dll (CPU 变体)

# 5.3 检查你的修改是否包含
# 可以检查特定文件或符号
```

### 第六步：测试安装

```powershell
# 6.1 安装测试
pip uninstall llama-cpp-python -y
pip install $wheelFile.FullName --force-reinstall

# 6.2 测试导入
python -c "from llama_cpp import Llama; print('成功导入')"

# 6.3 测试 CUDA 功能
python -c "
from llama_cpp import Llama
llm = Llama('model.gguf', n_gpu_layers=-1, verbose=True)
# 应显示: ggml_cuda_init: found 1 CUDA devices
"

# 6.4 测试你的自定义修改
# 根据你的修改内容进行测试
```

---

## 关键配置说明

### 确保自定义修改被包含

**方法1：修改已提交**
```powershell
cd vendor/llama.cpp
git add src/models/qwen35.cpp  # 你的修改文件
git commit -m "Custom MTP enhancement"
cd ..
python -m build --wheel  # 会包含提交的修改
```

**方法2：修改未提交（工作区）**
```powershell
# 未提交的修改也会被编译！
# CMake 会从工作区读取文件
cd vendor/llama.cpp
# 直接修改文件...
cd ..
python -m build --wheel  # 仍会包含修改
```

### 重要：不要更新 submodule

```powershell
# ❌ 不要执行这些命令（会覆盖你的修改）
git submodule update --remote

# ✅ 保持当前修改
git submodule status  # 只查看状态
```

---

## 生产级配置

### 最优性能配置

```powershell
$env:CMAKE_ARGS = @(
    '-DGGML_CUDA=ON'
    '-DGGML_CUDA_FORCE_MMQ=ON'
    '-DGGML_CUDA_PDL=ON'  # PDL优化（CC>=90）
    '-DGGML_BACKEND_DL=ON'
    '-DGGML_NATIVE=OFF'
    '-DCMAKE_BUILD_TYPE=Release'
    '-DLLAMA_BUILD_EXAMPLES=OFF'
    '-DLLAMA_BUILD_TESTS=OFF'
) -join ' '
```

### 最小包大小配置

```powershell
$env:CMAKE_ARGS = @(
    '-DGGML_CUDA=ON'
    '-DGGML_BACKEND_DL=ON'
    '-DGGML_CPU_HASWELL=ON'  # 只构建一个CPU变体
    '-DGGML_NATIVE=OFF'
) -join ' '

# 只针对你的GPU
$env:CUDAARCHS = "89-real"  # 只RTX 40系列
```

---

## 问题诊断

### 问题1：修改未被包含

**症状**：编译后功能没有改变

**检查**：
```powershell
cd vendor/llama.cpp
git status  # 查看修改是否还在
git diff src/models/qwen35.cpp  # 查看具体差异
```

**解决**：
```powershell
# 确保修改在工作区或已提交
git add -A
git commit -m "Save modifications"
```

### 问题2：编译失败

**症状**：`CMake Error` 或 `nvcc error`

**检查**：
```powershell
# 验证环境
nvcc --version
cmake --version
git submodule status  # 确认 submodule 已初始化

# 检查 MSVC
where.exe cl
where.exe nvcc
```

**解决**：
```powershell
# 重新初始化 submodule（如果缺失）
git submodule update --init --recursive

# 重新设置 MSVC 环境
cmd /c "call vcvarsall.bat x64"
```

### 问题3：CUDA 功能不工作

**症状**：安装后无 CUDA 设备识别

**检查**：
```powershell
# 查看包内容
python -m wheel unpack dist\*.whl -d check
ls check\*\llama_cpp\lib\ggml-cuda.dll

# 测试 CUDA DLL
python -c "import ctypes; ctypes.CDLL('ggml-cuda.dll')"
```

**解决**：
```powershell
# 确保环境变量正确
$env:CUDA_HOME = $env:CUDA_PATH

# 重新编译
Remove-Item -Recurse -Force build
python -m build --wheel
```

---

## 完整编译示例（实战）

```powershell
# ========== 从头开始的完整流程 ==========

# 1. 进入项目目录
cd J:/mickeylan/ai/llama-cpp-python

# 2. 确认你的修改
cd vendor/llama.cpp
git status
# 应显示：modified: src/models/qwen35.cpp (或其他文件)
git diff src/models/qwen35.cpp | head -20  # 查看修改内容
cd ..

# 3. 设置环境
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
$env:CUDA_HOME = $env:CUDA_PATH
$env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH

cmd /c "call `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat`" x64 && set" | `
    ForEach-Object { if ($_ -match "=") { $v = $_.split("=", 2); Set-Item -force -path "ENV:\$($v[0])" -value "$($v[1])" } }

# 4. 设置参数
$env:CUDAARCHS = "89-real;90-real"  # RTX 40系列
$env:CMAKE_ARGS = "-DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_NATIVE=OFF"
$env:VERBOSE = '1'

# 5. 清理
Remove-Item -Recurse -Force build, dist -ErrorAction SilentlyContinue

# 6. 编译
pip install build wheel setuptools packaging scikit-build-core ninja
python -m build --wheel

# 7. 验证
$wheel = Get-Item dist\*.whl | Select-Object -First 1
python -m wheel unpack $wheel.FullName -d temp
ls temp\*\llama_cpp\lib\*.dll

# 8. 安装测试
pip install $wheel.FullName --force-reinstall
python -c "from llama_cpp import Llama; print('✓ 成功')"

# 9. 清理
Remove-Item -Recurse -Force temp
```

---

## 最佳实践建议

### 1. 版本控制

```powershell
# 在 vendor/llama.cpp 中创建分支追踪修改
cd vendor/llama.cpp
git checkout -b custom-mtp-modifications
git add -A
git commit -m "Add custom MTP enhancements"
cd ..

# 记录在主项目
git add vendor/llama.cpp
git commit -m "Update llama.cpp with custom modifications"
```

### 2. 文档记录

创建 `CUSTOM_MODIFICATIONS.md`：
```markdown
# 自定义修改说明

## 修改内容
- 文件: vendor/llama.cpp/src/models/qwen35.cpp
- 功能: 增强 MTP 支持
- 日期: 2026-06-17

## 编译说明
使用 build_cuda_wheel.ps1 脚本编译

## 测试验证
运行 test_custom_modifications.py
```

### 3. 自动化测试

创建测试脚本验证修改：
```python
# test_custom_modifications.py
from llama_cpp import Llama

llm = Llama("model.gguf", n_gpu_layers=-1)

# 测试自定义功能
result = llm.create_chat_completion(...)
assert "custom_feature" in result  # 验证修改
```

---

## 分发你的 wheel 包

### 上传到 GitHub Releases

```powershell
# 1. 重命名包（包含修改标记）
$wheel = Get-Item dist\*.whl
$newName = $wheel.Name.Replace('.whl', '-custom.whl')
Rename-Item $wheel.FullName $newName

# 2. 创建 Release
gh release create v0.3.40-custom-mtp `
    --title "Custom MTP Build with CUDA" `
    --notes "包含 MTP 自定义修改的 CUDA 版本"

# 3. 上传 wheel
gh release upload v0.3.40-custom-mtp dist\$newName
```

### 用户安装

用户可以直接安装：
```powershell
pip install https://github.com/your-repo/releases/download/v0.3.40-custom-mtp/llama_cpp_python-0.3.40+cu128-custom-py311-none-win_amd64.whl
```

---

## 快速参考

| 操作 | 命令 |
|------|------|
| 检查修改 | `cd vendor/llama.cpp && git status` |
| 设置CUDA | `$env:CUDA_PATH = "C:\...\CUDA\v12.8"` |
| MSVC环境 | `cmd /c "call vcvarsall.bat x64"` |
| 编译 | `python -m build --wheel` |
| 验证 | `python -m wheel unpack dist\*.whl` |
| 安装 | `pip install dist\*.whl --force-reinstall` |

---

**最后更新**: 2026-06-17
**适用于**: 包含自定义 llama.cpp 修改的本地编译