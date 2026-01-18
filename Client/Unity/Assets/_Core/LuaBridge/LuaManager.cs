using System;
using System.IO;
using System.Text;
using UnityEngine;
using XLua;

namespace ProjectW.LuaBridge
{
    /// <summary>
    /// Lua运行时管理器：
    /// - 初始化LuaEnv
    /// - 提供自定义loader：将 require("critcore.skill.xxx") 映射到 Assets/LuaScripts/Skills/skill/xxx.lua
    /// - 仅负责“C#调Lua”，避免早期引入大量C# Wrap生成依赖
    /// </summary>
    public sealed class LuaManager : MonoBehaviour
    {
        public static LuaManager Instance { get; private set; }

        [Header("Lua Scripts Root (under Assets/)")]
        [SerializeField] private string _luaRootUnderAssets = "LuaScripts";

        private LuaEnv _env;

        public LuaEnv Env => _env;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);

            _env = new LuaEnv();
            _env.AddLoader(CustomLoader);

            InjectBuiltinGlobals();
        }

        private void OnDestroy()
        {
            if (Instance == this)
            {
                Instance = null;
            }

            _env?.Dispose();
            _env = null;
        }

        private void Update()
        {
            // xLua建议每帧Tick，释放Lua侧临时对象引用等
            _env?.Tick();
        }

        private void InjectBuiltinGlobals()
        {
            // 注意：Lua侧使用 Time() / FrameTime() 函数（Dota风格），这里注入为全局函数
            _env.Global.Set("Time", (Func<float>)(() => UnityEngine.Time.time));
            _env.Global.Set("FrameTime", (Func<float>)(() => UnityEngine.Time.deltaTime));

            // DebugDrawLine：供 Debug.lua 的范围显示调用
            // Lua侧将传入 Vector(origin/target) 与 r/g/b/ztest/duration
            // 我们在Lua侧拆分为数值后再调用本函数（避免传LuaTable到C#）。
            _env.Global.Set(
                "UnityBridge_DebugDrawLineUnity",
                (System.Action<float, float, float, float, float, float, float, float, float, bool, float>)
                ProjectW.SkillTest.DebugDrawService.DrawLineUnityCoord
            );

            // 伤害/治疗表现（测试环境）
            // Lua侧调用：UnityBridge_PlayDamageHealVfx(insId, delta)
            _env.Global.Set(
                "UnityBridge_PlayDamageHealVfx",
                (System.Action<int, int>)ProjectW.SkillTest.DamageHealVfxService.Play
            );
        }

        private byte[] CustomLoader(ref string moduleName)
        {
            // moduleName 是 require 传入的字符串（不含.lua）
            var absPath = ResolveModuleAbsPath(moduleName);
            if (string.IsNullOrEmpty(absPath) || !File.Exists(absPath))
            {
                return null;
            }

            moduleName = absPath; // 便于Lua报错时定位真实路径
            var text = File.ReadAllText(absPath, Encoding.UTF8);
            return Encoding.UTF8.GetBytes(text);
        }

        private string ResolveModuleAbsPath(string moduleName)
        {
            // 统一把点号转为斜杠
            // 约定映射：
            // - critcore.skill.* -> LuaScripts/Skills/skill/*
            // - Config.*        -> LuaScripts/Config/*
            // - Systems.*       -> LuaScripts/Systems/*
            // - 其他            -> LuaScripts/<moduleName>
            string relUnderAssets;

            const string skillPrefix = "critcore.skill.";
            const string configPrefix = "Config.";
            const string systemsPrefix = "Systems.";

            if (moduleName.StartsWith(skillPrefix, StringComparison.Ordinal))
            {
                var tail = moduleName.Substring(skillPrefix.Length);
                relUnderAssets = $"{_luaRootUnderAssets}/Skills/skill/{tail.Replace('.', '/')}.lua";
            }
            else if (moduleName.StartsWith(configPrefix, StringComparison.Ordinal))
            {
                var tail = moduleName.Substring(configPrefix.Length);
                relUnderAssets = $"{_luaRootUnderAssets}/Config/{tail.Replace('.', '/')}.lua";
            }
            else if (moduleName.StartsWith(systemsPrefix, StringComparison.Ordinal))
            {
                var tail = moduleName.Substring(systemsPrefix.Length);
                relUnderAssets = $"{_luaRootUnderAssets}/Systems/{tail.Replace('.', '/')}.lua";
            }
            else
            {
                relUnderAssets = $"{_luaRootUnderAssets}/{moduleName.Replace('.', '/')}.lua";
            }

            // Assets目录的绝对路径：Application.dataPath
            var abs = Path.Combine(Application.dataPath, relUnderAssets.Replace('/', Path.DirectorySeparatorChar));
            return abs;
        }
    }
}

