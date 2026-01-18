using System.Collections.Generic;
using ProjectW.LuaBridge;
using UnityEngine;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 测试环境：实体血量状态同步（Lua -> C#）
    /// - Lua侧通过 UnityBridge_OnEntityHpChanged 回调上报
    /// - Unity侧负责：缓存HP、自动挂血条、死亡变暗
    /// </summary>
    public sealed class EntityHealthService : MonoBehaviour
    {
        private sealed class HpState
        {
            public int Hp;
            public int MaxHp;
            public bool Dead;
        }

        private static EntityHealthService _instance;
        private static readonly Dictionary<int, HpState> States = new();

        public static EntityHealthService Instance
        {
            get
            {
                if (_instance != null) return _instance;
                var go = new GameObject("EntityHealthService");
                DontDestroyOnLoad(go);
                _instance = go.AddComponent<EntityHealthService>();
                return _instance;
            }
        }

        /// <summary>
        /// Lua回调入口（由 LuaManager 注入全局函数）
        /// </summary>
        public static void OnEntityHpChanged(int insId, int hp, int maxHp, bool isDead)
        {
            if (insId <= 0) return;
            Instance.Apply(insId, hp, maxHp, isDead);
        }

        public static bool TryGet(int insId, out int hp, out int maxHp, out bool dead)
        {
            if (States.TryGetValue(insId, out var s))
            {
                hp = s.Hp;
                maxHp = s.MaxHp;
                dead = s.Dead;
                return true;
            }
            hp = 0;
            maxHp = 0;
            dead = false;
            return false;
        }

        private float _nextScanTime;
        private const float ScanInterval = 0.75f;

        private void Apply(int insId, int hp, int maxHp, bool isDead)
        {
            if (!States.TryGetValue(insId, out var s))
            {
                s = new HpState();
                States[insId] = s;
            }

            s.Hp = Mathf.Max(0, hp);
            s.MaxHp = Mathf.Max(1, maxHp);
            s.Dead = isDead;

            if (EntityBridge.TryGetTransform(insId, out var t) && t != null)
            {
                EnsureView(t.gameObject, insId);
            }
        }

        private static void EnsureView(GameObject go, int insId)
        {
            if (go == null) return;
            var view = go.GetComponent<EntityHealthView>();
            if (view == null) view = go.AddComponent<EntityHealthView>();
            view.BindInsId(insId);
        }

        private void Update()
        {
            // 场景里可能已经有 EntityProxy，但还没有发生过伤害事件；
            // 扫描一次把血条预挂上（显示满血），避免“要打一下才出现血条”。
            if (Time.time < _nextScanTime) return;
            _nextScanTime = Time.time + ScanInterval;

            var proxies = FindObjectsByType<EntityProxy>(FindObjectsInactive.Exclude, FindObjectsSortMode.None);
            foreach (var p in proxies)
            {
                if (p == null) continue;
                EnsureView(p.gameObject, p.InsId);

                // 若没有收到Lua上报，则先按满血显示
                if (!States.ContainsKey(p.InsId))
                {
                    States[p.InsId] = new HpState { Hp = 100, MaxHp = 100, Dead = false };
                }
            }
        }
    }
}

