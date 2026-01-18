using UnityEngine;
using UnityEngine.InputSystem;
using XLua;

namespace ProjectW.SkillTest
{
    /// <summary>
    /// 简易可移动玩家控制器（测试环境用）
    /// - 鼠标右键点击移动（点击地面/任意位置投射到地面平面）
    /// - 朝向自动跟随移动方向
    ///
    /// 注意：项目启用了 New Input System，因此使用 UnityEngine.InputSystem 读取输入。
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public sealed class PlayerController : MonoBehaviour
    {
        [Header("Move")]
        [SerializeField] private float _moveSpeed = 6f;
        [SerializeField] private float _gravity = 20f;
        [SerializeField] private float _stopDistance = 0.1f;
        [Tooltip("点击移动时优先用射线检测地面；如未命中则投射到Y=0平面")]
        [SerializeField] private LayerMask _groundMask = ~0;
        [Tooltip("技能系统实体InsId（用于调用SkillAPI.CheckEntityMove判定是否可移动）")]
        [SerializeField] private int _insId = 1;
        [Tooltip("调用SkillAPI.CheckEntityMove的频率（秒），避免每帧DoString开销")]
        [SerializeField] private float _checkMoveInterval = 0.05f;

        [Header("Debug")]
        [SerializeField] private bool _drawTargetGizmo = true;

        private CharacterController _cc;
        private Vector3 _velocity;
        private Vector3 _targetPos;
        private bool _hasTarget;

        // Lua侧移动判定（必须走 SkillAPI 对外接口）
        private LuaEnv _env;
        private LuaFunction _checkEntityMove;
        private float _nextCheckTime;
        private bool _canMoveCached = true;

        private void Awake()
        {
            _cc = GetComponent<CharacterController>();
            _targetPos = transform.position;
            EnsureCubeVisual();
        }

        private void Update()
        {
            if (_cc == null) return;

            var canMove = CanMove();
            if (!canMove)
            {
                _hasTarget = false;
                _velocity = Vector3.zero;

                // 位移/击飞/击退等期间由Lua驱动Transform位置：
                // CharacterController 仍然每帧 Move 会覆盖外部设置的位置（运行时证据已确认），因此这里禁用。
                if (_cc.enabled) _cc.enabled = false;

                return;
            }

            // 恢复Unity输入移动时，重新启用CharacterController
            if (!_cc.enabled)
            {
                _cc.enabled = true;
                _hasTarget = false;
                _targetPos = transform.position;
                _velocity = Vector3.zero;
            }

            UpdateTargetFromMouseClick();

            if (_cc.isGrounded)
            {
                _velocity.y = 0f;
            }
            _velocity.y -= _gravity * Time.deltaTime;

            var planarMove = Vector3.zero;
            if (_hasTarget)
            {
                var pos = transform.position;
                var to = _targetPos - pos;
                to.y = 0f;

                var dist = to.magnitude;
                if (dist <= _stopDistance)
                {
                    _hasTarget = false;
                }
                else
                {
                    var dir = to / dist;
                    planarMove = dir * _moveSpeed;

                    // 朝向跟随移动方向
                    if (dir.sqrMagnitude > 1e-6f)
                    {
                        transform.forward = dir;
                    }
                }
            }

            _velocity.x = planarMove.x;
            _velocity.z = planarMove.z;
            _cc.Move(_velocity * Time.deltaTime);
        }

        private void UpdateTargetFromMouseClick()
        {
            if (Mouse.current == null) return;
            if (!Mouse.current.rightButton.wasPressedThisFrame) return;
            if (!CanMove()) return;

            var cam = Camera.main;
            if (cam == null) return;

            var mousePos = Mouse.current.position.ReadValue();
            var ray = cam.ScreenPointToRay(mousePos);

            if (Physics.Raycast(ray, out var hit, 2000f, _groundMask, QueryTriggerInteraction.Ignore))
            {
                _targetPos = hit.point;
                _hasTarget = true;
                return;
            }

            // 兜底：投射到Y=0平面，避免没有地面Collider时无法移动
            var plane = new Plane(Vector3.up, Vector3.zero);
            if (plane.Raycast(ray, out var enter))
            {
                _targetPos = ray.GetPoint(enter);
                _hasTarget = true;
            }
        }

        private void OnDrawGizmosSelected()
        {
            if (!_drawTargetGizmo) return;
            if (!_hasTarget) return;

            Gizmos.color = Color.cyan;
            Gizmos.DrawWireSphere(_targetPos, 0.25f);
            Gizmos.DrawLine(transform.position, _targetPos);
        }

        private void EnsureCubeVisual()
        {
            // 目标：测试场景里 Player 显示为 Cube，并保持碰撞由 CharacterController 控制
            // - 不销毁原物体（避免影响其他脚本通过 GameObject.Find("Player") 引用）
            // - 仅禁用现有Renderer，并挂一个Cube作为子物体显示

            var existingRenderers = GetComponentsInChildren<Renderer>(includeInactive: true);
            for (var i = 0; i < existingRenderers.Length; i++)
            {
                var r = existingRenderers[i];
                if (r == null) continue;
                if (r.gameObject == gameObject) continue; // 根对象如果未来加了Renderer也不强行禁用
                r.enabled = false;
            }

            // 已经有Cube子物体则不重复创建
            var child = transform.Find("CubeVisual");
            if (child != null) return;

            var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cube.name = "CubeVisual";
            cube.transform.SetParent(transform, worldPositionStays: false);

            // 去掉BoxCollider，避免与CharacterController/射线检测冲突
            var box = cube.GetComponent<BoxCollider>();
            if (box != null) Destroy(box);

            // 让Cube位于角色中心高度
            var h = _cc != null ? _cc.height : 2f;
            cube.transform.localPosition = new Vector3(0f, h * 0.5f, 0f);
            cube.transform.localRotation = Quaternion.identity;
            cube.transform.localScale = Vector3.one;
        }

        private bool CanMove()
        {
            if (Time.time < _nextCheckTime) return _canMoveCached;
            _nextCheckTime = Time.time + Mathf.Max(0.01f, _checkMoveInterval);

            // 默认允许移动（当Lua未就绪/未加载技能系统时）
            if (ProjectW.LuaBridge.LuaManager.Instance == null) return true;

            _env ??= ProjectW.LuaBridge.LuaManager.Instance.Env;
            if (_env == null) return true;

            try
            {
                if (_checkEntityMove == null)
                {
                    // 确保 SkillAPI 存在（对外接口入口）
                    _env.DoString("require('critcore.skill.SkillAPI')");
                    var api = _env.Global.Get<LuaTable>("SkillAPI");
                    _checkEntityMove = api?.Get<LuaFunction>("CheckEntityMove");
                }

                if (_checkEntityMove == null) return true;

                var ret = _checkEntityMove.Call(_insId);
                if (ret != null && ret.Length > 0 && ret[0] != null)
                {
                    if (ret[0] is bool b)
                    {
                        _canMoveCached = b;
                        return _canMoveCached;
                    }

                    // Lua可能返回0/1
                    if (ret[0] is double d)
                    {
                        _canMoveCached = d != 0;
                        return _canMoveCached;
                    }
                }
            }
            catch
            {
                // Lua异常时不阻塞测试移动
                _canMoveCached = true;
                return true;
            }

            return _canMoveCached;
        }
    }
}

