using UnityEngine;

namespace ProjectW.LuaBridge
{
    /// <summary>
    /// 挂在真实Unity实体上的组件：
    /// - 提供 insId / camp
    /// - 自动注册到 EntityBridge
    /// </summary>
    public sealed class EntityProxy : MonoBehaviour
    {
        [SerializeField] private int _insId = 1;
        [SerializeField] private int _camp = 1;

        public int InsId => _insId;
        public int Camp => _camp;

        /// <summary>
        /// 运行时初始化/修改insId与camp（测试环境用）
        /// </summary>
        public void Initialize(int insId, int camp)
        {
            var wasEnabled = isActiveAndEnabled;
            if (wasEnabled)
            {
                EntityBridge.Unregister(_insId, transform);
            }

            _insId = insId;
            _camp = camp;

            if (wasEnabled)
            {
                EntityBridge.Register(_insId, transform, _camp);
            }
        }

        private void OnEnable()
        {
            EntityBridge.Register(_insId, transform, _camp);
        }

        private void OnDisable()
        {
            EntityBridge.Unregister(_insId, transform);
        }
    }
}

