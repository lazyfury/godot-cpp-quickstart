# Data Binding — Model + Binding (addon 子项目)

基于 **Godot 4 + GDExtension C++ + Signal** 的极简双向数据绑定。独立 GDExtension 子项目。

```
                 Godot Signal
                      │
                      ▼
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Model   │◄───►│ Binding  │◄───►│  Control │
└──────────┘     └──────────┘     └──────────┘
     │                │                │
     └── value ───────┘                │
                                      │
                              text_changed
                              value_changed
                              toggled
```

**核心约束：Model 和 Control 永远不直接认识对方；`Binding` 是唯一的双向同步边界。**

- `Model`：只存 `Variant`、改值、发 `value_changed` 信号；不知道 Control / Node / Binding。
- `Binding`：唯一胶水层，负责 `Model → View` 和 `View → Model`。
- `Control`：只用 Godot 原生 API；不知道 Model / Binding。

## 构建

两种方式，构建规则共享 `SConscript`，签名数据库与根目录共用：

```bash
# 方式 A：在项目根目录一键构建（主扩展 + 所有 addons）
scons
scons addons=no                      # 只构建主扩展

# 方式 B：只构建本 addon
cd addons/data_binding
scons platform=macos
scons platform=macos target=template_release
```

godot-cpp 默认取 `../../godot-cpp`，也可 `scons godot_cpp=/path/to/godot-cpp`。
产物 `addons/data_binding/bin/libdata_binding.<platform>.<target>.framework`，由同目录
`bin/data_binding.gdextension` 引用（Godot 自动扫描 res:// 下所有 `.gdextension`）。
首次使用需打开一次编辑器以写入 `.godot/extension_list.cfg`。

## API

### Model（`RefCounted`）

```cpp
void    set_value(const StringName &name, const Variant &value);  // 值不变则不 emit
Variant get_value(const StringName &name) const;
bool    has_value(const StringName &name) const;

signal value_changed(name: StringName, value: Variant);
```

### Binding（`RefCounted`）

```cpp
// 建立绑定并做一次 Model -> View 初始同步。失败返回 false，原因见 get_last_error()。
// target_signal 留空 => 单向绑定（只做 Model -> View，适合 Label 等只读视图）。
// format 非空 => Model -> View 写入前用 Godot 的 `%` 语法格式化（如 "%d%%"、"%.2fx"）。
bool bind(const Ref<Model> &model, const StringName &model_property,
          Object *target, const StringName &target_property,
          const StringName &target_signal = StringName(),
          const String &format = String());

void unbind();                       // 双向断开并清空引用，可重复调用

Ref<Model> get_model() const;
Object *get_target() const;          // 目标已释放时返回 null
StringName get_model_property() const;
StringName get_target_property() const;
StringName get_target_signal() const;
String get_format() const;
bool is_one_way() const;             // 未指定 target_signal
bool is_bound() const;               // 目标失效后返回 false
String get_last_error() const;
```

`target_signal` 非空时必须有**恰好一个参数**，且该参数就是绑定值：

| Control | property | signal |
|---|---|---|
| `LineEdit` | `text` | `text_changed(String)` |
| `SpinBox` / `Slider` | `value` | `value_changed(float)` |
| `CheckBox` / `CheckButton` | `button_pressed` | `toggled(bool)` |
| `OptionButton` | `selected` | `item_selected(int)` |

`target_signal` 留空则为单向（Model -> View），Label 这类没有 change signal 的控件也能直接作为绑定目标：

```gdscript
# 双向
binding.bind(model, "name", $LineEdit, "text", "text_changed")
# 单向 + 格式化：模型 master_volume=80 -> Label.text == "80%"
binding.bind(model, "master_volume", $ValueLabel, "text", "", "%d%%")
# 单向不格式化：原值直接写入
binding.bind(model, "master_volume", $ValueLabel, "text")
```

## 用法

```gdscript
var model := Model.new()
var binding := Binding.new()

model.set_value("name", "Alice")

binding.bind(model, "name", $LineEdit, "text", "text_changed")
```

## Demo

### 1. 经典游戏设置页（推荐）

`addons/data_binding/demo/settings_page.tscn`

一个 Model 承载全部设置，每个控件一个 Binding：

| Tab | 控件 | Model 字段 |
|---|---|---|
| Audio | HSlider ×3 / CheckButton | `master_volume` / `music_volume` / `sfx_volume` / `mute` |
| Display | OptionButton / CheckButton ×2 / SpinBox / HSlider | `resolution_index` / `fullscreen` / `vsync` / `max_fps` / `ui_scale` |
| Gameplay | OptionButton ×2 / HSlider / CheckButton / LineEdit | `difficulty_index` / `language_index` / `mouse_sensitivity` / `invert_y` / `player_name` |

- 拖动 / 勾选 / 输入 → 右侧 **LIVE MODEL** 实时更新（View → Model）。
- **Reset Defaults** 只写 Model，所有控件（含数值标签）自动跟随（Model → View）。
- 滑条数值标签是 **单向 + format** 绑定（`bind(model, "master_volume", label, "text", "", "%d%%")`），不再是手写刷新；右侧面板是多字段组合，仍从 `value_changed` 刷新。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  res://addons/data_binding/demo/settings_page.tscn
```

### 2. 最小示例

`addons/data_binding/demo/data_binding_demo.tscn`（LineEdit / SpinBox / CheckBox 对应 name / age / enabled 三个模型字段）。

## 实现要点

- **格式化**：`format` 只作用于 Model -> View，用 Godot 的 `%` 语法（内部走与 GDScript 相同的类型化重载，所以 `"%d%%" % 42.0` 不会报错）；留空则原值直写。
- **单向绑定**：`target_signal` 留空即只做 Model -> View，Label 等无信号控件也能被绑定。
- **循环防护**：`bool updating` 是唯一的防循环机制。两个方向在改写对方前都置位，回调进入时立即返回。
- **信号过滤**：一个 Binding 连接 Model 的 `value_changed` 后只处理自己的 `model_property`，忽略其他字段。
- **弱引用**：`target` 用 `ObjectID` 持有，目标释放后 `is_bound()` 为 false，`_on_model_changed` 直接返回，绝不访问野指针。
- **初始同步方向**：`Model → View`（Model 是 source of truth）。
- **错误明确**：`bind()` 校验 model / target / property / signal / 信号参数个数，失败返回 false 并写入 `last_error`，不静默失败。
- **不转换类型**：Model 的 Variant 必须能直接赋给目标属性；不做隐式转换器。

## 测试

无头自测，全部通过返回 0，否则返回 1：

```bash
# 单元测试：初始同步、双向、去重、防循环、unbind、非法输入、目标释放
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  res://addons/data_binding/tests/binding_test.tscn

# 集成测试：设置页的初值同步、各控件类型双向、Reset 默认值
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  res://addons/data_binding/tests/settings_page_test.tscn
```

## 目录

```
addons/data_binding/
├── SConstruct                     # 单独构建入口
├── SConscript                     # 共享构建规则（根/单独构建都用它）
├── README.md
├── bin/data_binding.gdextension
├── src/
│   ├── model.h / model.cpp
│   ├── binding.h / binding.cpp
│   └── register_types.h / register_types.cpp   # Model + Binding
├── demo/
│   ├── settings_page.tscn          # 经典游戏设置页
│   ├── settings_page.gd
│   ├── data_binding_demo.tscn      # 最小示例
│   └── data_binding_demo.gd
└── tests/
    ├── binding_test.tscn           # Model/Binding 单元测试
    ├── binding_test.gd
    ├── settings_page_test.tscn     # 设置页集成测试
    └── settings_page_test.gd
```

## 已知限制（第一版有意不做）

- 双向绑定只支持「信号第一个参数即绑定值」的控件；不支持 0 参 / 多参信号（留空 signal 则退化为单向）。
- 不做类型转换；Property 类型不兼容时由 `target.set()` 报错。`format` 只做 Model -> View 的显示格式化，不做反向解析。
- 一个 Binding 只连一个 target property（一个 Model 字段可连多个 Binding/视图）。
- 无 `Property<T>` / `Observable` / Computed / Converter Pipeline / Undo / 序列化。
- `bind()` 每次调用会重建整个绑定（不是增量追加）。
