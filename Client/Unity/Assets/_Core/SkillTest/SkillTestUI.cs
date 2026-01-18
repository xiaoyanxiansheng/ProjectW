using System;
using UnityEngine;
using UnityEngine.InputSystem;
using ProjectW.LuaBridge;
using ProjectW.Rendering;
using XLua;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// PlayMode测试UI（IMGUI版，先快速打通“单技能验证闭环”）
    /// - Release
    /// </summary>
    public sealed class SkillTestUI : MonoBehaviour
    {
        [Header("Defaults")]
        [SerializeField] private int _casterInsId = 1;
        [SerializeField] private int _targetInsId = 2;
        [SerializeField] private bool _debugRangeOnStart = true;
        [SerializeField] private bool _debugLogOnStart = true;

        [Header("Cast Skills (Hotkeys)")]
        [Tooltip("按 Q 释放")]
        [SerializeField] private int _skillIdQ = 1100002;
        [Tooltip("Q 技能等级")]
        [SerializeField] private int _skillLevelQ = 1;
        [Tooltip("按 W 释放")]
        [SerializeField] private int _skillIdW = 0;
        [Tooltip("W 技能等级")]
        [SerializeField] private int _skillLevelW = 1;
        [Tooltip("按 E 释放")]
        [SerializeField] private int _skillIdE = 0;
        [Tooltip("E 技能等级")]
        [SerializeField] private int _skillLevelE = 1;
        [Tooltip("按 D 释放")]
        [SerializeField] private int _skillIdD = 0;
        [Tooltip("D 技能等级")]
        [SerializeField] private int _skillLevelD = 1;
        [Tooltip("按 R 释放")]
        [SerializeField] private int _skillIdR = 0;
        [Tooltip("R 技能等级")]
        [SerializeField] private int _skillLevelR = 1;

        [Header("Cast Origin")]
        [Tooltip("优先使用该Transform作为释放初始位置（Unity坐标->Lua技能坐标）。为空则使用默认位置。")]
        [SerializeField] private Transform _castOrigin;

        [Header("Ground Raycast (Cast Position)")]
        [Tooltip("用于计算鼠标指向的地面落点（作为 DoSkillData.Position）。")]
        [SerializeField] private LayerMask _groundMask = ~0;
        [SerializeField] private float _groundRayLength = 2000f;

        [Header("Targeting")]
        [SerializeField] private LayerMask _targetMask = ~0;
        [Tooltip("怪物Camp值（默认：2）")]
        [SerializeField] private int _monsterCamp = 2;
        [Tooltip("选中变暗系数（<1变暗）")]
        [Range(0.05f, 1f)]
        [SerializeField] private float _selectedDarkenMultiplier = 0.7f;

        private Vector3 _skillPos = new(0, 0, 0); // Lua技能坐标：x/y平面，z高度

        private ProjectW.LuaBridge.SkillBridge _skillBridge;
        private LuaEnv _env;
        private EntityProxy _selectedTarget;
        private EntityProxy _lastSelectedTarget;

        private void Start()
        {
            _skillBridge = FindFirstObjectByType<ProjectW.LuaBridge.SkillBridge>();
            _env = ProjectW.LuaBridge.LuaManager.Instance != null ? ProjectW.LuaBridge.LuaManager.Instance.Env : null;

            if (_env != null)
            {
                SetLuaGlobal("DebugSkillRange", _debugRangeOnStart ? 1 : 0);
                SetLuaGlobal("DebugSkillLog", _debugLogOnStart ? 1 : 0);
            }

            // 默认释放点：优先绑定场景中的 Player
            if (_castOrigin == null)
            {
                var player = GameObject.Find("Player");
                if (player != null) _castOrigin = player.transform;
            }
        }

        private void OnDisable()
        {
            // 退出PlayMode时避免访问已释放的LuaEnv
            _env = null;
        }

        private void Update()
        {
            if (_env == null && ProjectW.LuaBridge.LuaManager.Instance != null)
            {
                _env = ProjectW.LuaBridge.LuaManager.Instance.Env;
                if (_env != null)
                {
                    // 延迟注入默认开关
                    SetLuaGlobal("DebugSkillRange", _debugRangeOnStart ? 1 : 0);
                    SetLuaGlobal("DebugSkillLog", _debugLogOnStart ? 1 : 0);
                }
            }

            UpdateClickSelectTarget();
            UpdateHotkeyCast();
        }

        private void OnGUI()
        {
            const float w = 420f;
            const float h = 360f;
            GUILayout.BeginArea(new Rect(10, 10, w, h), GUI.skin.box);

            GUILayout.Label("Skill Test (Logic)");

            GUILayout.Label("按键施法：Q / W / E / D / R");
            SkillIdLevelField("Q", ref _skillIdQ, ref _skillLevelQ);
            SkillIdLevelField("W", ref _skillIdW, ref _skillLevelW);
            SkillIdLevelField("E", ref _skillIdE, ref _skillLevelE);
            SkillIdLevelField("D", ref _skillIdD, ref _skillLevelD);
            SkillIdLevelField("R", ref _skillIdR, ref _skillLevelR);

            GUILayout.Space(6);
            GUILayout.Label($"SelectedTarget InsId: {(_selectedTarget != null ? _selectedTarget.InsId : 0)}");

            GUILayout.EndArea();
        }

        private void DoSkill(int skillId, int skillLevel, int casterInsId, int targetInsId)
        {
            if (_env == null) return;
            if (skillLevel <= 0) skillLevel = 1;

            SyncAllEntityProxiesToLua();

            // StartPosition：施法者当前位置（不要用鼠标点）
            var casterPos = GetCasterPositionSkillCoord();

            // 释放前同步施法者位置/朝向（避免仍用原点）
            if (_castOrigin != null)
            {
                var dir = CoordAdapter.UnityToSkillDir(_castOrigin.forward);
                _env.DoString($@"
                    SetEntityPosition({casterInsId}, Vector({casterPos.x}, {casterPos.y}, {casterPos.z}))
                    SetEntityForwardVector({casterInsId}, Vector({dir.x}, {dir.y}, {dir.z}))
                ");
            }

            // 直接走Lua侧标准入口（保持技能逻辑不变）
            var start = casterPos;

            // Position：优先选中目标，其次鼠标地面点，最后兜底为施法者位置
            var targetPos = casterPos;
            if (_selectedTarget != null)
            {
                targetInsId = _selectedTarget.InsId;
                targetPos = CoordAdapter.UnityToSkill(_selectedTarget.transform.position);
                var targetDir = CoordAdapter.UnityToSkillDir(_selectedTarget.transform.forward);
                _env.DoString($@"
                    SetEntityPosition({targetInsId}, Vector({targetPos.x}, {targetPos.y}, {targetPos.z}))
                    SetEntityForwardVector({targetInsId}, Vector({targetDir.x}, {targetDir.y}, {targetDir.z}))
                ");
            }
            else if (TryGetMouseGroundSkillCoord(out var mousePos))
            {
                // 地面点击点在Unity通常是y=0（Skill z=0）。
                // 这里保持“施法者当前高度”（Skill z），避免位移结束后角色被写到地面高度导致下落。
                targetPos = mousePos;
                targetPos.z = casterPos.z;
            }

            _env.DoString($@"
                require('critcore.skill.SkillAPI')
                local d = DoSkillData.New()
                d.CasterInsId = {casterInsId}
                d.TargetInsId = {targetInsId}
                d.SkillId = {skillId}
                d.SkillLevel = {skillLevel}
                d.StartPosition = Vector({start.x}, {start.y}, {start.z})
                d.Position = Vector({targetPos.x}, {targetPos.y}, {targetPos.z})
                SkillAPI.DoSkill(d)
            ");
        }

        private void SetLuaGlobal(string name, int value)
        {
            if (_env == null) return;
            try
            {
                _env.DoString($"{name} = {value}");
            }
            catch
            {
                _env = null;
            }
        }

        private Vector3 GetCasterPositionSkillCoord()
        {
            if (_castOrigin != null)
            {
                return CoordAdapter.UnityToSkill(_castOrigin.position);
            }
            return _skillPos;
        }

        private bool TryGetMouseGroundSkillCoord(out Vector3 skillPos)
        {
            skillPos = default;
            if (Mouse.current == null) return false;

            var cam = Camera.main;
            if (cam == null) return false;

            var mousePos = Mouse.current.position.ReadValue();
            var ray = cam.ScreenPointToRay(mousePos);

            if (Physics.Raycast(ray, out var hit, _groundRayLength, _groundMask, QueryTriggerInteraction.Ignore))
            {
                skillPos = CoordAdapter.UnityToSkill(hit.point);
                return true;
            }

            // 兜底：投射到Y=0平面
            var plane = new Plane(Vector3.up, Vector3.zero);
            if (plane.Raycast(ray, out var enter))
            {
                var p = ray.GetPoint(enter);
                skillPos = CoordAdapter.UnityToSkill(p);
                return true;
            }

            return false;
        }

        private void UpdateClickSelectTarget()
        {
            if (Mouse.current == null) return;

            var cam = Camera.main;
            if (cam == null) return;

            // 左键点击选中
            if (!Mouse.current.leftButton.wasPressedThisFrame) return;

            var mousePos = Mouse.current.position.ReadValue();
            var ray = cam.ScreenPointToRay(mousePos);
            if (Physics.Raycast(ray, out var hit, 1000f, _targetMask))
            {
                var proxy = hit.collider.GetComponentInParent<EntityProxy>();
                // 只允许选中怪物（避免误选Player）
                if (proxy != null && proxy.Camp == _monsterCamp)
                {
                    SetSelectedTarget(proxy);
                }
                else
                {
                    SetSelectedTarget(null);
                }
                return;
            }

            // 点击空处取消选中
            SetSelectedTarget(null);
        }

        private void UpdateHotkeyCast()
        {
            if (_env == null) return;
            if (Keyboard.current == null) return;

            // 注意：仅在按下当帧触发，避免长按连发
            TryCastHotkey(Keyboard.current.qKey.wasPressedThisFrame, _skillIdQ, _skillLevelQ);
            TryCastHotkey(Keyboard.current.wKey.wasPressedThisFrame, _skillIdW, _skillLevelW);
            TryCastHotkey(Keyboard.current.eKey.wasPressedThisFrame, _skillIdE, _skillLevelE);
            TryCastHotkey(Keyboard.current.dKey.wasPressedThisFrame, _skillIdD, _skillLevelD);
            TryCastHotkey(Keyboard.current.rKey.wasPressedThisFrame, _skillIdR, _skillLevelR);
        }

        private void TryCastHotkey(bool pressed, int skillId, int skillLevel)
        {
            if (!pressed) return;
            if (skillId <= 0) return;
            DoSkill(skillId, skillLevel, _casterInsId, _targetInsId);
        }

        private void SetSelectedTarget(EntityProxy proxy)
        {
            if (_selectedTarget == proxy) return;

            _lastSelectedTarget = _selectedTarget;
            _selectedTarget = proxy;

            ApplyMonsterSelectedDarken(_lastSelectedTarget, false);
            ApplyMonsterSelectedDarken(_selectedTarget, true);

            _targetInsId = _selectedTarget != null ? _selectedTarget.InsId : 0;
        }

        private void ApplyMonsterSelectedDarken(EntityProxy proxy, bool selected)
        {
            if (proxy == null) return;
            if (proxy.Camp != _monsterCamp) return;

            var effect = proxy.GetComponent<HoverDarkenByPropertyBlock>();
            if (effect == null)
            {
                effect = proxy.gameObject.AddComponent<HoverDarkenByPropertyBlock>();
            }

            // 运行时把系数同步进去（避免需要改场景/预制体）
            effect.SetDarkenMultiplier(_selectedDarkenMultiplier);
            effect.SetHovered(selected);
        }

        private void SyncAllEntityProxiesToLua()
        {
            if (_env == null) return;

            var proxies = FindObjectsByType<EntityProxy>(FindObjectsInactive.Exclude, FindObjectsSortMode.None);
            foreach (var proxy in proxies)
            {
                if (proxy == null) continue;
                var pos = CoordAdapter.UnityToSkill(proxy.transform.position);
                var dir = CoordAdapter.UnityToSkillDir(proxy.transform.forward);
                _env.DoString($@"
                    local e = GetEntityByInsId({proxy.InsId})
                    if e then e:SetCamp({proxy.Camp}) end
                    SetEntityPosition({proxy.InsId}, Vector({pos.x}, {pos.y}, {pos.z}))
                    SetEntityForwardVector({proxy.InsId}, Vector({dir.x}, {dir.y}, {dir.z}))
                ");
            }
        }

        private static int IntField(string label, int v)
        {
            GUILayout.BeginHorizontal();
            GUILayout.Label(label, GUILayout.Width(110));
            var s = GUILayout.TextField(v.ToString(), GUILayout.Width(120));
            GUILayout.EndHorizontal();
            return int.TryParse(s, out var r) ? r : v;
        }

        private static void SkillIdLevelField(string key, ref int skillId, ref int skillLevel)
        {
            GUILayout.BeginHorizontal();
            GUILayout.Label($"{key} SkillId", GUILayout.Width(110));
            var sId = GUILayout.TextField(skillId.ToString(), GUILayout.Width(120));
            GUILayout.Label("Lv", GUILayout.Width(22));
            var sLv = GUILayout.TextField(skillLevel.ToString(), GUILayout.Width(50));
            GUILayout.EndHorizontal();

            if (int.TryParse(sId, out var idParsed)) skillId = idParsed;
            if (int.TryParse(sLv, out var lvParsed)) skillLevel = Mathf.Max(1, lvParsed);
        }
    }
}

