#!/bin/bash
# 本地编译 CUDA 版本的 llama-cpp-python whl 包（包含自定义修改）
# Linux 版本

set -e  # 遇到错误立即退出

echo "========================================"
echo "步骤 1: 准备编译环境"
echo "========================================"

# 1.1 检查 Python
python_version=$(python3 --version)
echo "Python版本: $python_version"

# 1.2 检查 CUDA
if [ -z "$CUDA_PATH" ]; then
    echo "错误: CUDA_PATH 未设置"
    echo "请设置: export CUDA_PATH=/usr/local/cuda"
    exit 1
fi

echo "CUDA路径: $CUDA_PATH"

# 1.3 检查 GCC
gcc_version=$(gcc --version | head -1)
echo "GCC版本: $gcc_version"

echo ""
echo "========================================"
echo "步骤 2: 检查 llama.cpp submodule"
echo "========================================"

# 2.1 检查 submodule 状态
git submodule status vendor/llama.cpp

# 2.2 检查修改
cd vendor/llama.cpp
if [ -n "$(git status --porcelain)" ]; then
    echo "警告: llama.cpp 有未提交的修改"
    echo "这些修改会被包含在编译中"
else
    echo "llama.cpp submodule 状态正常"
fi
cd -

echo ""
echo "========================================"
echo "步骤 3: 安装构建工具"
echo "========================================"

pip3 install --upgrade pip build wheel setuptools packaging scikit-build-core ninja cmake

echo ""
echo "========================================"
echo "步骤 4: 配置编译参数"
echo "========================================"

# 4.1 设置环境变量
export CUDA_HOME=$CUDA_PATH
export CUDA_TOOLKIT_ROOT_DIR=$CUDA_PATH

echo "选择 GPU 系列:"
echo "  1. RTX 20系列 - 架构 75"
echo "  2. RTX 30系列 - 架构 80,86,87"
echo "  3. RTX 40系列 - 架构 89,90"
echo "  4. 所有架构"

read -p "请选择 (1-4): " gpu_choice

case $gpu_choice in
    1) CUDAARCHS="75-real" ;;
    2) CUDAARCHS="80-real;86-real;87-real" ;;
    3) CUDAARCHS="89-real;90-real" ;;
    4) CUDAARCHS="75-real;80-real;86-real;87-real;89-real;90-real;100-real;120-real" ;;
    *) CUDAARCHS="80-real;86-real;87-real" ;;
esac

export CUDAARCHS
echo "CUDA架构: $CUDAARCHS"

# 4.2 CMake 参数
export CMAKE_ARGS="-DGGML_CUDA=ON \
-DGGML_BACKEND_DL=ON \
-DGGML_CPU_ALL_VARIANTS=ON \
-DGGML_NATIVE=OFF \
-DGGML_OPENMP=ON \
-DCMAKE_CUDA_ARCHITECTURES=$CUDAARCHS \
-DLLAMA_BUILD_EXAMPLES=OFF \
-DLLAMA_BUILD_TESTS=OFF \
-DLLAMA_BUILD_SERVER=OFF"

export VERBOSE=1
export MAX_JOBS=$(nproc)

echo "CMAKE_ARGS: $CMAKE_ARGS"

echo ""
echo "========================================"
echo "步骤 5: 编译 wheel 包"
echo "========================================"

echo "开始编译... (可能需要10-30分钟)"

# 清理之前的构建
rm -rf build dist

# 构建
python3 -m build --wheel

# 检查结果
if [ ! -f "dist/*.whl" ]; then
    echo "错误: 构建失败"
    exit 1
fi

echo ""
echo "========================================"
echo "步骤 6: 处理 wheel 包"
echo "========================================"

wheel_file=$(ls dist/*.whl | head -1)
echo "生成的 wheel: $wheel_file"

# 显示包信息
parts=$(basename $wheel_file | tr '-' ' ')
echo "包信息:"
echo "  文件名: $(basename $wheel_file)"
echo "  大小: $(du -h $wheel_file | cut -f1)"

# 可选重命名
cuda_version=$(basename $CUDA_PATH | sed 's/v//' | cut -d. -f1,2 | tr -d '.')
read -p "重命名包含 CUDA 版本标记? (y/n): " rename_choice

if [ "$rename_choice" = "y" ]; then
    dist_dir=$(dirname $wheel_file)
    old_name=$(basename $wheel_file)
    version=$(echo $old_name | cut -d'-' -f2)
    rest=$(echo $old_name | cut -d'-' -f3-)
    new_name="llama_cpp_python-${version}+cu${cuda_version}-custom-${rest}"

    mv "$wheel_file" "$dist_dir/$new_name"
    wheel_file="$dist_dir/$new_name"
    echo "已重命名为: $new_name"
fi

echo ""
echo "========================================"
echo "步骤 7: 测试安装"
echo "========================================"

read -p "测试安装? (y/n): " test_choice

if [ "$test_choice" = "y" ]; then
    pip3 uninstall llama-cpp-python -y
    pip3 install "$wheel_file" --force-reinstall

    python3 -c "from llama_cpp import Llama; print('导入成功!')"

    if [ $? -eq 0 ]; then
        echo "✓ 测试通过!"
    else
        echo "✗ 测试失败"
    fi
fi

echo ""
echo "========================================"
echo "✓ 编译完成!"
echo "========================================"

echo ""
echo "生成的 wheel 包:"
echo "  $wheel_file"

echo ""
echo "下一步:"
echo "  1. 测试 CUDA 功能"
echo "  2. 分发给其他用户"
echo "  3. 发布到 GitHub Releases"

echo ""
echo "安装命令:"
echo "  pip3 install $wheel_file"