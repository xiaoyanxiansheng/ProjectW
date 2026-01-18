using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;
using ProjectW.LuaBridge;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 技能测试驱动器（Phase B）
    /// - 不改变Lua技能逻辑
    /// - Unity侧仅做“观测+可视化同步”：把Lua中的实体位置同步到Unity场景物体
    ///
    /// 说明：
    /// - Lua技能坐标系：x/y平面，z高度
    /// - Unity世界：x/z平面，y高度
    /// </summary>
    public sealed class SkillTestRig : MonoBehaviour
    {
        [Header("Entity Visuals (Unity)")]
        [SerializeField] private Transform _caster;
        [SerializeField] private int _casterInsId = 1;

        [SerializeField] private Transform _target;
        [SerializeField] private int _targetInsId = 2;

        [Header("Optional: Dummies Root (children named Dummy_<insId>)")]
        [SerializeField] private Transform _dummiesRoot;

        [Header("Unity -> Lua Sync (Caster)")]
        [SerializeField] private Transform _casterSource;
        [SerializeField] private int _casterSourceInsId = 1;
        [SerializeField] private bool _syncCasterFromUnity = true;
        [SerializeField] private bool _syncCasterForward = true;

        private LuaEnv _env;
        private LuaFunction _getEntityPosition;
        private LuaFunction _setEntityPosition;
        private LuaFunction _setEntityForward;
        private LuaFunction _vectorCtor;

        // 移动判定：必须走 SkillAPI.CheckEntityMove
        private LuaTable _skillApi;
        private LuaFunction _checkEntityMove;
        private float _nextMoveCheckTime;
        private bool _canMoveCached = true;
        private const float MoveCheckInterval = 0.05f;

        private readonly List<(int insId, Transform t)> _syncList = new();

        private void Start()
        {
            if (ProjectW.LuaBridge.LuaManager.Instance == null)
            {
                var go = new GameObject("LuaManager");
                go.AddComponent<ProjectW.LuaBridge.LuaManager>();
            }

            _env = ProjectW.LuaBridge.LuaManager.Instance != null
                ? ProjectW.LuaBridge.LuaManager.Instance.Env
                : null;

            if (_env == null)
            {
                Debug.LogError("[SkillTestRig] LuaManager not found. Ensure SkillBridge exists in scene.");
                enabled = false;
                return;
            }

            // 确保Unity兼容层已加载，这样 GetEntityPosition 等全局函数一定存在
            _env.DoString("require('Systems.UnityBridge')");
            // 技能模块自带Debug.lua会注册消息并打印；这里不再额外注入Trace/UI文本，避免重复与复杂度

            // GetEntityPosition(insId) -> Vector (Lua table)
            _getEntityPosition = _env.Global.Get<LuaFunction>("GetEntityPosition");
            if (_getEntityPosition == null)
            {
                Debug.LogError("[SkillTestRig] Lua global GetEntityPosition not found.");
                enabled = false;
                return;
            }

            _setEntityPosition = _env.Global.Get<LuaFunction>("SetEntityPosition");
            _setEntityForward = _env.Global.Get<LuaFunction>("SetEntityForwardVector");
            _vectorCtor = _env.Global.Get<LuaFunction>("Vector");

            BuildSyncList();
            PreferPlayerAsCasterIfPresent();
        }

        private void Update()
        {
            if (_getEntityPosition == null) return;

            for (var i = 0; i < _syncList.Count; i++)
            {
                var (insId, t) = _syncList[i];
                SyncOne(insId, t);
            }

            // 关键：位移/击飞/击退等期间，Lua会强制驱动位置。
            // 为避免 Unity->Lua 每帧回写把位移覆盖，必须用 SkillAPI.CheckEntityMove 判定：
            // - 可移动：Unity->Lua（玩家输入）
            // - 不可移动：Lua->Unity（表现跟随技能位移）
            if (CanCasterMove())
            {
                SyncCasterFromUnity();
            }
            else
            {
                SyncCasterFromLua();
            }
        }

        private void OnDestroy()
        {
            _getEntityPosition?.Dispose();
            _setEntityPosition?.Dispose();
            _setEntityForward?.Dispose();
            _vectorCtor?.Dispose();
            _checkEntityMove?.Dispose();
            _skillApi?.Dispose();
            _getEntityPosition = null;
            _setEntityPosition = null;
            _setEntityForward = null;
            _vectorCtor = null;
            _checkEntityMove = null;
            _skillApi = null;
        }

        private void OnDisable()
        {
            _getEntityPosition?.Dispose();
            _getEntityPosition = null;
            _setEntityPosition?.Dispose();
            _setEntityForward?.Dispose();
            _vectorCtor?.Dispose();
            _checkEntityMove?.Dispose();
            _skillApi?.Dispose();
            _setEntityPosition = null;
            _setEntityForward = null;
            _vectorCtor = null;
            _checkEntityMove = null;
            _skillApi = null;
            _env = null;
        }

        private void BuildSyncList()
        {
            _syncList.Clear();

            if (_caster != null) _syncList.Add((_casterInsId, _caster));
            if (_target != null) _syncList.Add((_targetInsId, _target));

            if (_dummiesRoot == null)
            {
                var go = GameObject.Find("Dummies");
                _dummiesRoot = go != null ? go.transform : null;
            }

            if (_dummiesRoot == null) return;

            for (var i = 0; i < _dummiesRoot.childCount; i++)
            {
                var child = _dummiesRoot.GetChild(i);
                if (child == null) continue;

                var name = child.name ?? string.Empty;
                // 约定：Dummy_<insId>
                if (!name.StartsWith("Dummy_", StringComparison.OrdinalIgnoreCase)) continue;

                var parts = name.Split('_');
                if (parts.Length < 2) continue;
                if (!int.TryParse(parts[1], out var insId)) continue;
                if (insId <= 0) continue;

                _syncList.Add((insId, child));
            }
        }

        /// <summary>
        /// 规则：当场景里已经有 Player，就不应再依赖单独的 Caster 显示对象。
        /// - Player 作为施法者（Unity->Lua 同步源）
        /// - Caster（若存在）运行时禁用，避免重复
        /// - 确保 Player 上有 EntityProxy(insId=施法者insId, camp=1)
        /// </summary>
        private void PreferPlayerAsCasterIfPresent()
        {
            var player = GameObject.Find("Player");
            if (player == null) return;

            _casterSource = player.transform;
            _syncCasterFromUnity = true;
            _syncCasterForward = true;

            // 确保Player具备EntityProxy，供选中/飘字/闪色等系统定位
            var proxy = player.GetComponent<EntityProxy>();
            if (proxy == null)
            {
                proxy = player.AddComponent<EntityProxy>();
            }
            proxy.Initialize(_casterSourceInsId, 1);

            // 禁用 Caster 物体（如存在），并避免Lua->Unity同步覆写Player
            if (_caster != null && _caster != player.transform)
            {
                _caster.gameObject.SetActive(false);
                _caster = null;
            }

            var casterGo = GameObject.Find("Caster");
            if (casterGo != null && casterGo != player)
            {
                casterGo.SetActive(false);
            }

            // 从同步列表里移除施法者（由PlayerController控制移动），只保留Target/Dummies等
            for (var i = _syncList.Count - 1; i >= 0; i--)
            {
                if (_syncList[i].insId == _casterInsId)
                {
                    _syncList.RemoveAt(i);
                }
            }
        }

        private void SyncCasterFromUnity()
        {
            if (!_syncCasterFromUnity) return;
            if (_casterSource == null)
            {
                var player = GameObject.Find("Player");
                _casterSource = player != null ? player.transform : null;
            }

            if (_casterSource == null) return;

            EnsureLuaSyncFunctions();
            if (_setEntityPosition == null || _vectorCtor == null) return;

            // Unity -> Skill 坐标（含缩放）
            var skillPos = CoordAdapter.UnityToSkill(_casterSource.position);
            var vecObj = _vectorCtor.Call(skillPos.x, skillPos.y, skillPos.z);
            if (vecObj != null && vecObj.Length > 0)
            {
                _setEntityPosition.Call(_casterSourceInsId, vecObj[0]);
            }

            if (_syncCasterForward && _setEntityForward != null)
            {
                var skillDir = CoordAdapter.UnityToSkillDir(_casterSource.forward);
                var dirObj = _vectorCtor.Call(skillDir.x, skillDir.y, skillDir.z);
                if (dirObj != null && dirObj.Length > 0)
                {
                    _setEntityForward.Call(_casterSourceInsId, dirObj[0]);
                }
            }
        }

        private void EnsureLuaSyncFunctions()
        {
            if (_env == null) return;

            // 运行时可能先加载 Systems.UnityBridge，后加载 Skills(Define.lua)。
            // 这里做懒加载/懒绑定，避免 SetEntityPosition 等函数在Start时为null导致永远不同步。
            if (_vectorCtor == null) _vectorCtor = _env.Global.Get<LuaFunction>("Vector");
            if (_setEntityPosition == null) _setEntityPosition = _env.Global.Get<LuaFunction>("SetEntityPosition");
            if (_setEntityForward == null) _setEntityForward = _env.Global.Get<LuaFunction>("SetEntityForwardVector");

            if (_setEntityPosition != null && _vectorCtor != null) return;

            try
            {
                // 通过对外入口加载技能模块依赖（不会修改Skills逻辑）
                _env.DoString("require('critcore.skill.SkillAPI')");
            }
            catch
            {
                // 忽略：技能模块未就绪时不阻塞
            }

            if (_vectorCtor == null) _vectorCtor = _env.Global.Get<LuaFunction>("Vector");
            if (_setEntityPosition == null) _setEntityPosition = _env.Global.Get<LuaFunction>("SetEntityPosition");
            if (_setEntityForward == null) _setEntityForward = _env.Global.Get<LuaFunction>("SetEntityForwardVector");
        }

        private void SyncCasterFromLua()
        {
            if (_casterSource == null) return;

            try
            {
                var ret = _getEntityPosition.Call(_casterSourceInsId);
                if (ret == null || ret.Length <= 0 || ret[0] == null) return;

                if (ret[0] is LuaTable vec)
                {
                    var x = vec.Get<float>("x");
                    var y = vec.Get<float>("y");
                    var z = vec.Get<float>("z");
                    var skill = new Vector3(x, y, z);
                    _casterSource.position = CoordAdapter.SkillToUnity(skill);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[SkillTestRig] SyncCasterFromLua failed insId={_casterSourceInsId}: {e.Message}");
            }
        }

        private bool CanCasterMove()
        {
            // 默认允许（Lua未就绪/未加载技能系统时）
            if (_env == null) return true;

            // 降频：避免每帧跨语言调用
            if (Time.time < _nextMoveCheckTime) return _canMoveCached;
            _nextMoveCheckTime = Time.time + MoveCheckInterval;

            try
            {
                if (_checkEntityMove == null)
                {
                    _env.DoString("require('critcore.skill.SkillAPI')");
                    _skillApi = _env.Global.Get<LuaTable>("SkillAPI");
                    _checkEntityMove = _skillApi?.Get<LuaFunction>("CheckEntityMove");
                }

                if (_checkEntityMove == null) return true;

                var ret = _checkEntityMove.Call(_casterSourceInsId);
                if (ret != null && ret.Length > 0 && ret[0] != null)
                {
                    if (ret[0] is bool b)
                    {
                        _canMoveCached = b;
                        return _canMoveCached;
                    }
                    if (ret[0] is double d)
                    {
                        _canMoveCached = d != 0;
                        return _canMoveCached;
                    }
                }
            }
            catch
            {
                // Lua异常时不阻塞测试
                _canMoveCached = true;
                return true;
            }

            return _canMoveCached;
        }

        private void SyncOne(int insId, Transform t)
        {
            if (t == null) return;

            try
            {
                var ret = _getEntityPosition.Call(insId);
                if (ret == null || ret.Length <= 0 || ret[0] == null) return;

                // Lua Vector 是 table：{x,y,z}
                if (ret[0] is LuaTable vec)
                {
                    var x = vec.Get<float>("x");
                    var y = vec.Get<float>("y");
                    var z = vec.Get<float>("z");
                    var skill = new Vector3(x, y, z);
                    t.position = CoordAdapter.SkillToUnity(skill);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[SkillTestRig] SyncOne failed insId={insId}: {e.Message}");
            }
        }
    }
}

