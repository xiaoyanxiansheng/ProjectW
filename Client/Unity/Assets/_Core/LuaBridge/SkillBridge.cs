using System;
using UnityEngine;
using XLua;

namespace ProjectW.LuaBridge
{
    /// <summary>
    /// 技能系统桥接：
    /// - 负责加载 UnityBridge.lua（补齐全局依赖）
    /// - require 技能模块（SkillModule）
    /// - 驱动 SkillModule.Update（Unity Update）
    /// </summary>
    public sealed class SkillBridge : MonoBehaviour
    {
        [Header("Lua Entry")]
        [SerializeField] private string _unityBridgeModule = "Systems.UnityBridge";
        [SerializeField] private string _skillModule = "critcore.skill.SkillModule";
        [SerializeField] private bool _runSmokeTestOnStart = true;

        private LuaEnv _env;
        private LuaTable _skillModuleTable;
        private LuaFunction _skillInit;
        private LuaFunction _skillUpdate;

        private void Start()
        {
            if (LuaManager.Instance == null)
            {
                var go = new GameObject("LuaManager");
                go.AddComponent<LuaManager>();
            }

            _env = LuaManager.Instance.Env;

            // 先加载Unity兼容层
            _env.DoString($"require('{_unityBridgeModule}')");
            // 再加载技能模块（该模块本身依赖大量require）
            _env.DoString($"require('{_skillModule}')");

            _skillModuleTable = _env.Global.Get<LuaTable>("SkillModule");
            if (_skillModuleTable == null)
            {
                throw new Exception("SkillBridge: SkillModule global table not found (require did not set SkillModule?)");
            }

            _skillInit = _skillModuleTable.Get<LuaFunction>("Init");
            _skillUpdate = _skillModuleTable.Get<LuaFunction>("Update");

            _skillInit?.Call();

            if (_runSmokeTestOnStart)
            {
                // Phase1：尽早暴露缺失的兼容点
                TestDoSkill101();
            }
        }

        private void Update()
        {
            _skillUpdate?.Call();
        }

        private void OnDestroy()
        {
            _skillInit?.Dispose();
            _skillUpdate?.Dispose();
            _skillModuleTable?.Dispose();
            _skillInit = null;
            _skillUpdate = null;
            _skillModuleTable = null;
        }

        [ContextMenu("Test/DoSkill(101)")]
        private void TestDoSkill101()
        {
            // Phase1验证：只要求能调用到 SkillAPI.DoSkill，不要求完整表现
            // 这里在Lua侧构造 DoSkillData 并调用
            _env.DoString(@"
                require('critcore.skill.SkillAPI')
                local d = DoSkillData.New()
                d.CasterInsId = 1
                d.TargetInsId = 2
                d.SkillId = 101
                d.SkillLevel = 1
                d.Position = Vector(5,0,0)
                SkillAPI.DoSkill(d)
            ");
        }
    }
}

