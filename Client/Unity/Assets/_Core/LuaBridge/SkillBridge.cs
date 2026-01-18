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
        [SerializeField] private bool _autoUpdate = true;

        [Header("Inspector Test Params (SkillCoord)")]
        [SerializeField] private int _testSkillId = 1100002;
        [SerializeField] private int _testSkillLevel = 1;
        [SerializeField] private int _testCasterInsId = 1;
        [SerializeField] private int _testTargetInsId = 2;
        [Tooltip("Lua技能坐标系：x/y平面，z高度")]
        [SerializeField] private Vector3 _testSkillPosition = new Vector3(5, 0, 0);
        [SerializeField] private float _testStepDelta = 0.05f;

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

            // 注意：测试环境不再使用额外TraceRecorder（避免UI/重复输出），仅使用技能模块自带 Debug.lua 打印到控制台

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
                TestDoSkillDefault();
            }
        }

        private void Update()
        {
            if (!_autoUpdate) return;
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

        [ContextMenu("Test/DoSkill(1100002)")]
        private void TestDoSkillDefault()
        {
            // Phase1验证：只要求能调用到 SkillAPI.DoSkill，不要求完整表现
            // 这里在Lua侧构造 DoSkillData 并调用
            _env.DoString(@"
                require('critcore.skill.SkillAPI')
                local d = DoSkillData.New()
                d.CasterInsId = 1
                d.TargetInsId = 2
                d.SkillId = 1100002
                d.SkillLevel = 1
                d.Position = Vector(5,0,0)
                SkillAPI.DoSkill(d)
            ");
        }

        [ContextMenu("Test/DoSkill(Inspector Params)")]
        private void TestDoSkillInspectorParams()
        {
            if (_env == null) return;

            var x = _testSkillPosition.x;
            var y = _testSkillPosition.y;
            var z = _testSkillPosition.z;

            _env.DoString($@"
                require('critcore.skill.SkillAPI')
                local d = DoSkillData.New()
                d.CasterInsId = {_testCasterInsId}
                d.TargetInsId = {_testTargetInsId}
                d.SkillId = {_testSkillId}
                d.SkillLevel = {_testSkillLevel}
                d.Position = Vector({x}, {y}, {z})
                SkillAPI.DoSkill(d)
            ");
        }

        [ContextMenu("Test/BreakSkill(Caster)")]
        private void TestBreakSkillCaster()
        {
            if (_env == null) return;
            _env.DoString($@"
                require('critcore.skill.SkillAPI')
                SkillAPI.BreakSkill({_testCasterInsId}, false)
            ");
        }

        [ContextMenu("Test/ForceBreakSkill(Caster)")]
        private void TestForceBreakSkillCaster()
        {
            if (_env == null) return;
            _env.DoString($@"
                require('critcore.skill.SkillAPI')
                SkillAPI.BreakSkill({_testCasterInsId}, true)
            ");
        }

        [ContextMenu("Test/Step(Inspector Δt)")]
        private void TestStepOnce()
        {
            StepOnce(_testStepDelta);
        }

        private void StepOnce(float delta)
        {
            if (_env == null || _skillUpdate == null) return;

            // 临时覆写FrameTime，然后驱动一次Update，便于“暂停/步进”观察
            _env.Global.Set("FrameTime", (Func<float>)(() => delta));
            _skillUpdate.Call();
            _env.Global.Set("FrameTime", (Func<float>)(() => UnityEngine.Time.deltaTime));
        }
    }
}

