using System.Collections.Generic;
using UnityEngine;

namespace ProjectW.LuaBridge
{
    /// <summary>
    /// Unity侧实体桥接（Phase2）
    /// 说明：
    /// - 当前Lua技能系统仍使用Lua侧MockEntity驱动验证
    /// - 该桥接用于后续把 insId 映射到Unity场景中的真实实体（Transform/属性/阵营）
    /// </summary>
    public static class EntityBridge
    {
        private sealed class EntityState
        {
            public int InsId;
            public int Camp;
            public bool Alive = true;
            public float MaxHp = 100f;
            public Transform Transform;
        }

        private static readonly Dictionary<int, EntityState> Entities = new();

        public static void Register(int insId, Transform transform, int camp = 1)
        {
            if (insId <= 0 || transform == null) return;

            Entities[insId] = new EntityState
            {
                InsId = insId,
                Camp = camp,
                Transform = transform,
            };
        }

        public static void Unregister(int insId, Transform transform)
        {
            if (!Entities.TryGetValue(insId, out var e)) return;
            if (e.Transform != transform) return;
            Entities.Remove(insId);
        }

        public static bool IsAlive(int insId) => Entities.TryGetValue(insId, out var e) && e.Alive;

        public static int GetCamp(int insId) => Entities.TryGetValue(insId, out var e) ? e.Camp : 0;

        public static Vector3 GetPosition(int insId) => Entities.TryGetValue(insId, out var e) && e.Transform != null
            ? e.Transform.position
            : Vector3.zero;

        public static void SetPosition(int insId, Vector3 pos)
        {
            if (!Entities.TryGetValue(insId, out var e) || e.Transform == null) return;
            e.Transform.position = pos;
        }

        public static Vector3 GetForward(int insId) => Entities.TryGetValue(insId, out var e) && e.Transform != null
            ? e.Transform.forward
            : Vector3.forward;

        public static bool TryGetTransform(int insId, out Transform transform)
        {
            if (Entities.TryGetValue(insId, out var e) && e.Transform != null)
            {
                transform = e.Transform;
                return true;
            }

            transform = null;
            return false;
        }

        public static void SetForward(int insId, Vector3 fwd)
        {
            if (!Entities.TryGetValue(insId, out var e) || e.Transform == null) return;
            if (fwd.sqrMagnitude < 1e-6f) return;
            e.Transform.forward = fwd.normalized;
        }

        public static float GetMaxHp(int insId) => Entities.TryGetValue(insId, out var e) ? e.MaxHp : 100f;
    }
}

