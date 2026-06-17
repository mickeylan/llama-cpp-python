# 构建 CUDA 支持的 llama-cpp-python whl 包

## 目录
1. [本地快速构建（推荐）](#本地快速构建推荐)
2. [完整 CI 构建流程](#完整-ci-构建流程)
3. [构建选项详解](#构建选项详解)
4. [常见问题](#常见问题)

---

## 本地快速构建（推荐）

### Windows 系统

#### 方法一：直接 pip 安装（最简单）

```powershell
# 1. 设置环境变量
$env:CMAKE_ARGS = "-DGGML_CUDA=on"

# 2. 安装（会自动编译）
pip install "llama-cpp-python @ git+https://github.com/JamePeng/llama-cpp-python.git"

# 或者从本地源码安装
git clone https://github.com/JamePeng/llama-cpp-python --recursive
cd llama-cpp-python
$env:CMAKE_ARGS = "-DGGML_CUDA=on"
pip install .
```

#### 方法二：构建 whl 包（用于分发）

```powershell
# 1. 安装构建工具
pip install build wheel setuptools packaging

# 2. 设置环境变量
$env:CMAKE_ARGS = "-DGGML_CUDA=on"
$env:CUDA_HOME = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"  # 你的CUDA路径
$env:VERBOSE = '1'  # 显示详细日志

# 3. 构建wheel包
python -m build --wheel

# 4. 查找生成的wheel包
# 位置：dist/llama_cpp_python-xxx.whl
```

### Linux 系统

```bash
# 1. 设置环境变量
export CMAKE_ARGS="-DGGML_CUDA=on"

# 2. 安装
pip install "llama-cpp-python @ git+https://github.com/JamePeng/llama-cpp-python.git"

# 或者构建wheel包
pip install build wheel setuptools packaging
python -m build --wheel
```

---

## 完整 CI 构建流程（生产级）

### 前置要求

#### Windows:
- Visual Studio 2022 Build Tools
- CUDA Toolkit 12.4/12.6/12.8/13.0/13.1
- CMake 3.21+
- Python 3.10-3.14
- Ninja build system

#### Linux:
- GCC 或 Clang
- CUDA Toolkit
- CMake 3.21+
- Python 3.10-3.14

### Windows 详细构建步骤

```powershell
# 1. 克隆代码（包含submodules）
git clone https://github.com/JamePeng/llama-cpp-python --recursive
cd llama-cpp-python

# 2. 设置CUDA环境
$env:CUDA_HOME = $env:CUDA_PATH  # CUDA安装路径
$env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH

# 3. 设置MSVC环境（重要！）
cmd /c "call `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat`" x64 && set" | `
    ForEach-Object {
        if ($_ -match "=") {
            $v = $_.split("=")
            Set-Item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
        }
    }

# 4. 设置构建参数
$env:CMAKE_ARGS = "-DGGML_CUDA=on -DGGML_NATIVE=OFF"
$env:CUDAARCHS = "75-real;80-real;86-real;87-real;89-real;90-real;100-real;120-real"  # CUDA架构
$env:VERBOSE = '1'
$env:CMAKE_GENERATOR = 'Ninja'  # 使用Ninja生成器

# 5. 安装构建依赖
pip install build wheel setuptools packaging scikit-build-core

# 6. 构建wheel
python -m build --wheel

# 7. 查看生成的包
ls dist/
```

### Linux 详细构建步骤

```bash
# 1. 克隆代码
git clone https://github.com/JamePeng/llama-cpp-python --recursive
cd llama-cpp-python

# 2. 设置环境变量
export CUDA_HOME=/usr/local/cuda
export CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda
export CMAKE_ARGS="-DGGML_CUDA=on -DGGML_NATIVE=OFF"
export CUDAARCHS="75-real;80-real;86-real;87-real;89-real;90-real;100-real;120-real"
export VERBOSE=1

# 3. 安装构建依赖
pip install build wheel setuptools packaging scikit-build-core

# 4. 构建wheel
python -m build --wheel

# 5. 查看生成的包
ls dist/
```

---

## 构建选项详解

### 核心 CUDA 选项

| 选项 | 说明 | 推荐值 |
|------|------|--------|
| `-DGGML_CUDA=on` | 启用 CUDA 支持 | **必须设置** |
| `-DGGML_NATIVE=OFF` | 不绑定到特定CPU | **推荐设置**（通用性） |
| `-DCUDA_ARCHITECTURES` | CUDA GPU架构 | 见下表 |

### CUDA 架构设置

根据你的GPU型号选择对应的架构：

```powershell
# Windows
$env:CUDAARCHS = "80-real;86-real;87-real"  # RTX 30系列
$env:CUDAARCHS = "89-real;90-real"          # RTX 40系列
$env:CUDAARCHS = "100-real;120-real"        # 新架构

# Linux
export CUDAARCHS="80-real;86-real;87-real"
```

**常见GPU架构对应表**：

| GPU系列 | 架构值 | 示例显卡 |
|---------|--------|----------|
| RTX 20系列 | 75 | RTX 2070, 2080 |
| RTX 30系列 | 80, 86, 87 | RTX 3070, 3080, 3090 |
| RTX 40系列 | 89, 90 | RTX 4070, 4080, 4090 |
| GTX 10系列 | 61, 70 | GTX 1070, 1080 |
| Tesla/Quadro | 根据型号 | V100(70), A100(80) |

### 高级选项

#### 动态后端加载（推荐用于wheel分发）

```powershell
$env:CMAKE_ARGS = "-DGGML_CUDA=on -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON"
```

**说明**：
- `-DGGML_BACKEND_DL=ON` - 启用动态加载后端DLL
- `-DGGML_CPU_ALL_VARIANTS=ON` - 构建所有CPU变体（x64, haswell, alderlake等）

#### CPU优化变体

```powershell
# 只构建特定CPU变体（减少包大小）
$env:CMAKE_ARGS = "-DGGML_CUDA=on -DGGML_CPU_HASWELL=ON"
```

可用变体：
- `GGML_CPU_X64` - 基础x64
- `GGML_CPU_HASWELL` - Haswell架构
- `GGML_CPU_ALDERLAKE` - Alder Lake架构
- `GGML_CPU_ZEN4` - AMD Zen4

---

## 不同 CUDA 版本的构建

### CUDA 12.4

```powershell
# 安装CUDA 12.4后
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"
$env:CMAKE_ARGS = "-DGGML_CUDA=on"
```

### CUDA 12.8

```powershell
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
$env:CMAKE_ARGS = "-DGGML_CUDA=on"
```

### CUDA 13.0+

```powershell
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0"
$env:CMAKE_ARGS = "-DGGML_CUDA=on"
```

---

## 完整构建示例（生产级）

### 构建支持所有GPU架构的通用包

```powershell
# Windows PowerShell
cd llama-cpp-python

# 设置完整环境
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
$env:CUDA_HOME = $env:CUDA_PATH
$env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH

# MSVC环境
cmd /c "call `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat`" x64 && set" | `
    ForEach-Object {
        if ($_ -match "=") {
            $v = $_.split("=")
            Set-Item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
        }
    }

# 构建参数（生产级配置）
$env:CMAKE_ARGS = @(
    '-DGGML_CUDA=ON'
    '-DGGML_NATIVE=OFF'
    '-DGGML_BACKEND_DL=ON'
    '-DGGML_CPU_ALL_VARIANTS=ON'
    '-DLLAMA_BUILD_EXAMPLES=OFF'
    '-DLLAMA_BUILD_TESTS=OFF'
    '-DLLAMA_BUILD_SERVER=OFF'
) -join ' '

$env:CUDAARCHS = "75-real;80-real;86-real;87-real;89-real;90-real;100-real;120-real"
$env:VERBOSE = '1'
$env:CMAKE_GENERATOR = 'Ninja'

# 构建
pip install build wheel setuptools packaging scikit-build-core
python -m build --wheel

# 验证
ls dist/
pip install dist/llama_cpp_python-*.whl --force-reinstall
python -c "from llama_cpp import Llama; print('CUDA build successful')"
```

---

## 常见问题

### 1. 找不到 CUDA

**错误**：`Could not find CUDA`

**解决**：
```powershell
# 明确指定CUDA路径
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
$env:CUDA_HOME = $env:CUDA_PATH
$env:CUDA_TOOLKIT_ROOT_DIR = $env:CUDA_PATH
```

### 2. nvcc 编译失败

**错误**：`nvcc fatal : Unsupported gpu architecture`

**解决**：
```powershell
# 使用正确的架构值（必须加 -real 后缀）
$env:CUDAARCHS = "80-real;86-real;87-real"  # 不要用 "80;86;87"
```

### 3. MSVC 环境问题

**错误**：`Could not find CMAKE_C_COMPILER`

**解决**：
```powershell
# 必须调用 vcvarsall.bat
cmd /c "call `"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat`" x64 && set"
```

### 4. Ninja 生成器问题

**错误**：`CMake Error: Could not find CMAKE_GENERATOR`

**解决**：
```powershell
# 安装Ninja
pip install ninja

# 或使用默认生成器
$env:CMAKE_GENERATOR = 'Visual Studio 17 2022'
```

### 5. 构建速度慢

**优化**：
```powershell
# 并行构建
$env:MAX_JOBS = 12  # 根据CPU核心数调整

# 只构建必要的架构
$env:CUDAARCHS = "86-real;89-real"  # 只针对你的GPU
```

---

## 验证构建结果

### 测试 CUDA 是否工作

```python
from llama_cpp import Llama

llm = Llama(
    model_path="model.gguf",
    n_gpu_layers=-1,  # 全部GPU层
    verbose=True
)

# 输出应包含：
# ggml_cuda_init: GGML_CUDA_FORCE_MMQ:    no
# ggml_cuda_init: GGML_CUDA_FORCE_CUBLAS: no
# ggml_cuda_init: found 1 CUDA devices:
#   Device 0: NVIDIA GeForce RTX 3080, compute capability 8.6
```

### 检查 wheel 包内容

```powershell
# 解压查看
python -m wheel unpack dist/llama_cpp_python-*.whl -d unpacked

# 检查CUDA DLL
ls unpacked/*/llama_cpp/lib/
# 应包含：ggml-cuda.dll, ggml-cpu-*.dll, llama.dll
```

---

## 发布到 GitHub Releases

如果你构建了生产级的 wheel 包，可以：

1. 创建 GitHub Release
2. 上传 wheel 文件
3. 用户可以直接下载安装：

```powershell
pip install https://github.com/YOUR_REPO/releases/download/v0.3.40/llama_cpp_python-0.3.40+cu128-cp311-win_amd64.whl
```

---

## 参考资料

- [llama.cpp CUDA构建文档](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [CI构建配置](https://github.com/JamePeng/llama-cpp-python/tree/main/.github/workflows)
- [CMakeLists.txt配置](https://github.com/JamePeng/llama-cpp-python/blob/main/CMakeLists.txt)

---

**最后更新**: 2026-06-17
**适用版本**: llama-cpp-python v0.3.40+