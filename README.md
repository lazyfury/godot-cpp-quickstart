# Godot C++ Quickstart (GDExtension Template)

**Godot 4 + C++ GDExtension (godot-cpp)** 最小可运行快速启动模板。

开箱即用：一个 C++ 节点类（属性 / 方法 / 静态方法 / 信号）+ 一个展示 C++ ↔ GDScript 交互的场景 + 一套跨平台构建脚本。

```
GDScript (UI 胶水)  ⇄  C++ GDExtension (核心逻辑)  →  Godot ClassDB / 场景
```

## 环境要求

| 依赖 | 版本 |
|---|---|
| Godot | 4.x（已在 4.7.2 上验证） |
| godot-cpp | 4.5 分支（配合 Godot 4.7 实测可用） |
| SCons | >= 4.0 |
| 编译器 | macOS: clang++ (Xcode CLT) / Windows: MSVC / Linux: g++ |
| Windows 交叉编译（可选） | Docker（Linux + MinGW-w64，见下文「构建」） |

## 1. 准备 godot-cpp

模板通过 `godot-cpp/` 目录引用绑定库。二选一：

```bash
# 方式 A：作为 git submodule（推荐，仓库可移植）
git submodule add -b 4.5 https://github.com/godotengine/godot-cpp.git godot-cpp
git submodule update --init --recursive

# 方式 B：已有本地副本，直接软链
ln -s /path/to/godot-cpp godot-cpp
```

> 当前仓库里的 `godot-cpp` 是一个指向本地副本的软链，直接 `scons` 即可构建。
> 也可以通过 `scons godot_cpp=/path/to/godot-cpp` 或环境变量 `GODOT_CPP_PATH` 指定路径。

## 2. 构建

### 一键构建（主扩展 + 所有 addons）

```bash
scons platform=macos                             # Debug（主扩展 + addons/*）
scons platform=macos target=template_release     # Release
scons platform=macos addons=no                   # 只构建主扩展
scons platform=windows arch=x86_64               # Windows
scons platform=linux arch=x86_64                 # Linux
scons platform=macos compiledb=yes               # 生成 compile_commands.json (clangd)
```

主扩展产物在 `bin/`，各 addon 产物在 `addons/<name>/bin/`：

```
bin/
├── quickstart.gdextension                                  # 主扩展描述文件
└── libquickstart.macos.template_debug.framework/           # macOS (framework)

addons/data_binding/bin/
├── data_binding.gdextension                                # addon 描述文件
└── libdata_binding.macos.template_debug.framework/
```

根目录 `SConstruct` 会自动遍历并构建每个 `addons/*/SConscript`；用 `addons=no` 可跳过。

### 用 Docker 交叉编译 Windows 产物（Linux + MinGW-w64）

没有 Windows / MSVC 也可以验证 Windows 构建：`docker/` 提供一个基于 Debian +
MinGW-w64 的 Linux 容器，用 `x86_64-w64-mingw32-g++`（posix 线程模型）交叉编译出
Windows x86_64 DLL。

```bash
./docker/build-windows.sh                            # Debug
TARGETS=template_release ./docker/build-windows.sh   # Release
TARGETS="template_debug template_release" ./docker/build-windows.sh
./docker/build-windows.sh addons=no -j8              # 额外参数透传给 scons
```

脚本行为：

- 构建镜像 `quickstart-mingw`（首次约 3 分钟，之后走缓存）。
- 把工程源码与 godot-cpp 同步到 Docker 卷 `quickstart-mingw-build:/build` 中**独立构建**，
  不会改动宿主机的 macOS 构建状态（`.os` / `.sconsign.dblite` / framework 均不受影响）。
- 只把生成的 `*.dll` 复制回 `bin/` 与 `addons/*/bin/`，并用 `file` 校验 PE 头、确认入口符号已导出。
- 构建树保存在命名卷里，重复构建是增量的（debug 已构建后再跑一次约 3 秒）。

产物：

```
bin/libquickstart.windows.template_debug.x86_64.dll
bin/libquickstart.windows.template_release.x86_64.dll
addons/data_binding/bin/libdata_binding.windows.template_{debug,release}.x86_64.dll
```

> MinGW 使用 posix 线程模型并静态链接 libstdc++/libgcc，产物仅依赖
> `KERNEL32.dll` / `msvcrt.dll`，可直接放进 Windows 版 Godot 的工程中加载。

可调环境变量：`IMAGE`、`BUILD_VOLUME`、`TARGETS`（默认 `template_debug`）、`ARCH`（默认 `x86_64`）。
需要联网拉取 `debian:bookworm-slim` 与 apt 包；彻底重编可执行
`docker volume rm quickstart-mingw-build`。

### 单独构建某个 addon

每个 addon 都是独立子项目，可单独构建（与根构建共享 `.sconsign.dblite`，来回切换不会全量重编）：

```bash
cd addons/data_binding
scons platform=macos
scons platform=macos target=template_release
```

## 3. 运行

```bash
/Applications/Godot.app/Contents/MacOS/Godot -e --path .   # 打开编辑器
/Applications/Godot.app/Contents/MacOS/Godot --path .      # 直接运行
```

首次打开编辑器时 Godot 会扫描并写入 `.godot/extension_list.cfg`。之后运行主场景即可看到
C++ 节点打印 `[QuickStart] ready: Hello from C++ GDExtension!`，界面上有 Greet / Increment / Reset 三个按钮演示属性与信号。

## 目录结构

```
├── SConstruct                 # 构建脚本（跨平台，自动解析 godot-cpp）
├── project.godot              # Godot 项目配置
├── bin/
│   └── quickstart.gdextension # entry_symbol + 各平台库路径
├── src/
│   ├── register_types.h/.cpp  # 模块入口：注册所有 C++ 类
│   └── quick_start.h/.cpp     # 示例 C++ 节点（GDCLASS）
├── addons/
│   └── data_binding/          # 子项目：Model + Binding 双向绑定（独立 GDExtension）
└── scenes/
    ├── main.tscn              # 演示场景（含 QuickStart 节点）
    └── main.gd                # UI 胶水，调用 C++ 方法 / 连接信号
```

## 子项目（addons）

`addons/` 下可以放独立的 GDExtension 子项目，各自拥有 `SConstruct`、入口符号和 `.gdextension`，Godot 会自动扫描加载。

当前示例：

| 子项目 | 说明 |
|---|---|
| [`addons/data_binding`](addons/data_binding/README.md) | `Model`（Dictionary + `value_changed`）+ `Binding`（带 guard 的双向胶水层），支持 LineEdit / SpinBox / CheckBox 等 |

构建子项目：

```bash
scons                                # 根目录：主扩展 + 所有 addons 一起构建
scons addons=no                      # 只构建主扩展

cd addons/data_binding && scons      # 或单独构建某个 addon
```

运行其 Demo：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  res://addons/data_binding/demo/data_binding_demo.tscn
```

运行其无头自测：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  res://addons/data_binding/tests/binding_test.tscn
```

## 如何新增一个 C++ 类

1. 新建 `src/my_node.h` / `src/my_node.cpp`，使用 `GDCLASS`：

   ```cpp
   class MyNode : public Node {
       GDCLASS(MyNode, Node)
       String value;
   protected:
       static void _bind_methods();
   public:
       void set_value(const String &p_v) { value = p_v; }
       String get_value() const { return value; }
   };
   ```

2. 在 `_bind_methods()` 里注册，使其对 GDScript / 编辑器可见：

   ```cpp
   void MyNode::_bind_methods() {
       ClassDB::bind_method(D_METHOD("set_value", "value"), &MyNode::set_value);
       ClassDB::bind_method(D_METHOD("get_value"), &MyNode::get_value);
       ADD_PROPERTY(PropertyInfo(Variant::STRING, "value"), "set_value", "get_value");
       ADD_SIGNAL(MethodInfo("changed", PropertyInfo(Variant::STRING, "value")));
   }
   ```

3. 在 `src/register_types.cpp` 中引入头文件并注册：

   ```cpp
   #include "my_node.h"
   // ...
   GDREGISTER_CLASS(MyNode);
   ```

4. `scons platform=macos`，然后在 GDScript / 场景中直接使用 `MyNode`。

## 关键约定

- **类注册**：所有对 Godot 可见的类都要 `GDREGISTER_CLASS`，入口符号是 `quickstart_library_init`。
- **入口符号一致性**：`SConstruct` 的 `ENTRY_SYMBOL`、`register_types.cpp` 的 `quickstart_library_init`、`bin/quickstart.gdextension` 的 `entry_symbol` 三处必须一致。
- **const 与信号**：`emit_signal()` 是非 const，带信号的成员函数不能声明为 `const`。
- **静态方法**：用 `ClassDB::bind_static_method("ClassName", ...)`。

## 重命名模板

1. 修改 `SConstruct` 里的 `PROJECT_NAME`（同时决定入口符号）。
2. 修改 `src/register_types.cpp` 中的入口函数名 `quickstart_library_init`。
3. 修改 `bin/quickstart.gdextension` 的 `entry_symbol` 与库路径文件名（或直接重命名该文件）。
4. 更新 `project.godot` 的 `config/name`。

## 常见问题

- **编辑器报 `Cannot get class 'X'`**：先构建（`scons`）再打开编辑器；确认 `.godot/extension_list.cfg` 已生成。
- **改了 C++ 没生效**：GDExtension 默认需重新编译并在编辑器里重新加载（`.gdextension` 中 `reloadable = true` 时 Godot 会自动热重载；否则重启编辑器）。
- **找不到 godot-cpp**：`git submodule update --init --recursive`，或 `ln -s` 本地副本，或 `scons godot_cpp=...`。
- **Docker Windows 构建报 `std::mutex`/`std::thread` 缺失**：MinGW 用了 win32 线程模型，
  需安装 `*-posix` 变体（`docker/Dockerfile` 已处理）。
