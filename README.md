# 包袋厂计件工资管理系统

一个基于 Flutter 的移动端计件工资管理应用，支持员工管理、工序定义、产量录入、工资计算和报表导出。

## 功能

### 员工管理
- 添加、编辑、删除员工信息
- 按部门分组管理（车缝组、包装组、质检组等）
- 支持员工编号、手机号等字段

### 工序管理
- 按产品类型（手提袋、电脑包等）管理工序
- 自定义工序名称和计件单价
- 灵活配置计件单位

### 计件录入
- 快速录入每日产量记录
- 按员工、工序、日期关联记录

### 计件查询
- 按员工、包袋种类、日期范围查询记录
- 查看详细生产明细

### 工资计算
- 按月统计工资汇总
- 查看每位员工的工序明细
- 导出 Excel 工资报表（含汇总 + 明细）

### 数据备份
- 备份数据库到手机「下载」文件夹
- 从备份文件导入恢复数据
- 管理历史备份文件（分享 / 删除）
- 清空所有数据

## 技术栈

| 技术 | 说明 |
|------|------|
| **Flutter** 3.44.3 | 跨平台 UI 框架 |
| **Dart** ^3.12.2 | 开发语言 |
| **sqflite** ^2.3.0 | 本地 SQLite 数据库 |
| **excel** ^4.0.0 | Excel 报表生成 |
| **share_plus** ^10.1.4 | 文件分享 |
| **file_picker** ^10.0.0 | 文件选择（导入备份） |
| **intl** ^0.20.2 | 国际化支持 |

## 环境要求

- Flutter 3.44.3+
- Dart ^3.12.2
- Android SDK 36+
- Gradle 9.0.1
- Kotlin 2.3.20

## 构建

```bash
# 获取依赖
flutter pub get

# 调试构建
flutter build apk --debug

# 发布构建（推荐，仅 arm64）
flutter build apk --release --split-per-abi
```

发布构建产物位于 `build/app/outputs/flutter-apk/`：
- `app-arm64-v8a-release.apk` — 现代 Android 手机（约 18MB）
- `app-armeabi-v7a-release.apk` — 旧版 Android 手机（约 16MB）

## 使用说明

1. 首次启动为**空数据库**，需先添加员工和工序
2. 录入产量后可在「工资计算」查看统计并导出报表
3. 建议定期备份数据到「下载」文件夹

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── database/
│   └── database_helper.dart     # 数据库操作（SQLite）
├── models/
│   ├── employee.dart            # 员工模型
│   ├── department.dart          # 部门模型
│   ├── product_type.dart        # 产品类型模型
│   ├── process_model.dart       # 工序模型
│   └── production_record.dart   # 生产记录模型
└── screens/
    ├── home_screen.dart         # 首页
    ├── employee_screen.dart     # 员工管理
    ├── product_screen.dart      # 工序管理
    ├── record_screen.dart       # 计件录入
    ├── record_query_screen.dart # 计件查询
    ├── wage_screen.dart         # 工资计算 / 导出
    └── backup_screen.dart       # 数据备份 / 恢复
```

## 截图

（待添加）

## 许可证

本项目为私有项目，仅供内部使用。
