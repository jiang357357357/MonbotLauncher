"""
MonConfig 加载器测试
用于验证配置加载器的功能
"""

import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from Public.LoadConfig import MonConfig, ConfigNotFoundError, ConfigParseError
from Public.LoadConfig.helpers import get_config, get_section


def test_basic_usage():
    """测试基础使用"""
    print("=" * 60)
    print("测试 1: 基础使用")
    print("=" * 60)
    
    try:
        config = MonConfig()
        
        # 显示加载信息
        print(f"\n✓ 配置实例: {config}")
        print(f"✓ 工作区根目录: {config.workspace_root()}")
        print(f"✓ 已加载配置文件:")
        for file in config.loaded_files():
            print(f"  - {file}")
        
        # 显示所有配置节
        print(f"\n✓ 配置节列表 ({len(config.sections())} 个):")
        for section in config.sections():
            print(f"  - [{section}]")
        
        print("\n✅ 基础使用测试通过")
        return True
        
    except Exception as e:
        print(f"\n❌ 基础使用测试失败: {e}")
        return False


def test_get_config():
    """测试配置读取"""
    print("\n" + "=" * 60)
    print("测试 2: 配置读取")
    print("=" * 60)
    
    try:
        config = MonConfig()
        
        # 测试字符串读取
        service_name = config.get("service", "NAME", default="Unknown")
        print(f"\n✓ 服务名称: {service_name}")
        
        # 测试整数读取
        port = config.get("nonebot", "PORT", default=8080, cast=int)
        print(f"✓ NoneBot 端口: {port} (类型: {type(port).__name__})")
        
        # 测试布尔值读取
        debug = config.get("debug", "DEBUG", default=False, cast=bool)
        print(f"✓ 调试模式: {debug} (类型: {type(debug).__name__})")
        
        # 测试列表读取
        nicknames = config.get("bot", "NICKNAMES", default=[], cast=list)
        print(f"✓ 机器人昵称: {nicknames} (类型: {type(nicknames).__name__})")
        
        # 测试不存在的配置
        missing = config.get("nonexistent", "KEY", default="默认值")
        print(f"✓ 不存在的配置: {missing}")
        
        print("\n✅ 配置读取测试通过")
        return True
        
    except Exception as e:
        print(f"\n❌ 配置读取测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_get_section():
    """测试配置节读取"""
    print("\n" + "=" * 60)
    print("测试 3: 配置节读取")
    print("=" * 60)
    
    try:
        config = MonConfig()
        
        # 读取 server 配置节
        server_config = config.section("server")
        print(f"\n✓ [server] 配置节:")
        for key, value in server_config.items():
            print(f"  {key} = {value}")
        
        # 读取 bot 配置节
        bot_config = config.section("bot")
        print(f"\n✓ [bot] 配置节:")
        for key, value in bot_config.items():
            print(f"  {key} = {value}")
        
        print("\n✅ 配置节读取测试通过")
        return True
        
    except Exception as e:
        print(f"\n❌ 配置节读取测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_helpers():
    """测试辅助函数"""
    print("\n" + "=" * 60)
    print("测试 4: 辅助函数")
    print("=" * 60)
    
    try:
        # 使用便捷函数
        service_name = get_config('service', 'NAME', default='Unknown')
        print(f"\n✓ get_config('service', 'NAME'): {service_name}")
        
        port = get_config('nonebot', 'PORT', default=8080, cast=int)
        print(f"✓ get_config('nonebot', 'PORT', cast=int): {port}")
        
        server_config = get_section('server')
        print(f"✓ get_section('server'): {len(server_config)} 个配置项")
        
        print("\n✅ 辅助函数测试通过")
        return True
        
    except Exception as e:
        print(f"\n❌ 辅助函数测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_type_casting():
    """测试类型转换"""
    print("\n" + "=" * 60)
    print("测试 5: 类型转换")
    print("=" * 60)
    
    try:
        config = MonConfig()
        
        # 测试布尔值转换
        test_cases = [
            ("features", "ENABLE_GLOBAL_COMMANDS", bool),
            ("features", "VOICE_MODE_ENABLED", bool),
            ("debug", "DEBUG", bool),
        ]
        
        print("\n✓ 布尔值转换:")
        for section, key, cast_type in test_cases:
            value = config.get(section, key, default=False, cast=cast_type)
            print(f"  {section}.{key} = {value} ({type(value).__name__})")
        
        # 测试整数转换
        print("\n✓ 整数转换:")
        int_cases = [
            ("nonebot", "PORT"),
            ("moncore", "WS_PORT"),
            ("moncore", "DISCOVERY_PORT"),
        ]
        
        for section, key in int_cases:
            value = config.get(section, key, default=0, cast=int)
            print(f"  {section}.{key} = {value} ({type(value).__name__})")
        
        # 测试列表转换
        print("\n✓ 列表转换:")
        nicknames = config.get("bot", "NICKNAMES", default=[], cast=list)
        print(f"  bot.NICKNAMES = {nicknames} ({type(nicknames).__name__})")
        
        print("\n✅ 类型转换测试通过")
        return True
        
    except Exception as e:
        print(f"\n❌ 类型转换测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_all_configs():
    """显示所有配置"""
    print("\n" + "=" * 60)
    print("测试 6: 显示所有配置")
    print("=" * 60)
    
    try:
        config = MonConfig()
        all_configs = config.to_dict()
        
        print(f"\n✓ 共 {len(all_configs)} 个配置节:\n")
        
        for section, items in all_configs.items():
            print(f"[{section}]")
            for key, value in items.items():
                # 截断过长的值
                display_value = value if len(value) <= 50 else value[:47] + "..."
                print(f"  {key} = {display_value}")
            print()
        
        print("✅ 显示所有配置测试通过")
        return True
        
    except Exception as e:
        print(f"\n❌ 显示所有配置测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """运行所有测试"""
    print("\n" + "=" * 60)
    print("MonConfig 加载器测试")
    print("=" * 60)
    
    tests = [
        test_basic_usage,
        test_get_config,
        test_get_section,
        test_helpers,
        test_type_casting,
        test_all_configs,
    ]
    
    results = []
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"\n❌ 测试异常: {e}")
            import traceback
            traceback.print_exc()
            results.append(False)
    
    # 显示测试结果
    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)
    
    passed = sum(results)
    total = len(results)
    
    print(f"\n通过: {passed}/{total}")
    
    if passed == total:
        print("\n🎉 所有测试通过！")
        return 0
    else:
        print(f"\n⚠️  {total - passed} 个测试失败")
        return 1


if __name__ == "__main__":
    exit(main())
