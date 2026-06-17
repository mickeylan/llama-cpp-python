#!/usr/bin/env python3
"""
Example of how to create Qwen36ChatHandler as an alias/subclass.

Note: This is purely for user experience/Qwen branding purposes.
Technically, Qwen3.5 and Qwen3.6 share the same chat template.
"""

# Option 1: Simple alias (推荐 - 避免代码冗余)
# 在 llama_multimodal.py 导出时添加：
from llama_cpp.llama_multimodal import Qwen35ChatHandler
Qwen36ChatHandler = Qwen35ChatHandler  # Alias for clarity

# Option 2: Subclass (不推荐 - 没有实际功能差异)
class Qwen36ChatHandler(Qwen35ChatHandler):
    """
    Handler for Qwen3.6 models.

    Note: This is an alias of Qwen35ChatHandler since Qwen3.5 and Qwen3.6
    use identical chat templates and formats.
    """
    pass

# Option 3: Factory function (可选 - 提供更好的文档说明)
def get_qwen_chat_handler(model_version: str = "3.5") -> Qwen35ChatHandler:
    """
    Get appropriate Qwen ChatHandler based on model version.

    Args:
        model_version: "3.5" or "3.6" (both use same handler)

    Returns:
        Qwen35ChatHandler instance

    Note:
        Qwen3.5 and Qwen3.6 share identical chat templates, so they
        both use Qwen35ChatHandler. This factory is for documentation
        purposes only.
    """
    return Qwen35ChatHandler

# 实际使用示例
if __name__ == "__main__":
    from llama_cpp import Llama

    # 所有这些用法都是等价的：

    # 1. 直接使用 Qwen35ChatHandler (推荐)
    llm1 = Llama(
        model_path="Qwen3.6-27B-MTP.gguf",
        chat_handler=Qwen35ChatHandler(enable_thinking=True)
    )

    # 2. 使用别名 Qwen36ChatHandler (如果创建了)
    llm2 = Llama(
        model_path="Qwen3.6-27B-MTP.gguf",
        chat_handler=Qwen36ChatHandler(enable_thinking=True)
    )

    # 3. 通过名称自动选择 (ComfyUI 已经实现)
    # UI 中选择 "Qwen3.6" → 映射到 Qwen35ChatHandler