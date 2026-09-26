# 個人環境特別注意事項

本文件僅適用於個人 LAB 環境。

## 適用範圍

個人環境主要用於 Oracle Grid Infrastructure、ASM、Oracle Restart 與 Oracle Database 的學習、測試及安裝練習。

個人 LAB 環境的作業系統固定為：

```text
Oracle Linux 9（OEL9）
```

本文件中的例外規則，不適用於正式環境、UAT、公司環境或客戶環境。

## RU 與 OPatch 限制

個人環境可能無法登入 My Oracle Support，因此可能無法下載下列檔案：

- Oracle Grid Infrastructure Release Update（GI RU）
- Oracle Database Release Update（DB RU）
- 新版 OPatch

因此，`GI_Setup.conf` 必須允許以下設定留空：

```bash
GI_RU=""
GI_OPATCH=""

DB_RU=""
DB_OPATCH=""
```

當上述變數為空時：

- 不得視為必要檔案缺失。
- `00_PreCheck.sh` 不得因 RU 或 OPatch 未設定而失敗。
- 對應的 RU 或 OPatch 安裝步驟必須略過。
- 仍可繼續使用現有的 Oracle Base 安裝媒體進行安裝。

## 必要安裝媒體

Oracle Grid Infrastructure 與 Oracle Database 的 Base 安裝檔仍為必要項目。

例如：

```bash
GI_SOFTWARE="/software/LINUX.X64_193000_grid_home.zip"
DB_SOFTWARE="/software/LINUX.X64_193000_db_home.zip"
```

如果必要的 Base 安裝檔不存在，PreCheck 必須失敗並停止後續安裝。

## Oracle 19.3 Base 安裝

個人 LAB 環境允許在沒有 RU 的情況下，使用 Oracle 19.3 Base Software 進行安裝與練習。

此規則僅為個人測試環境的例外，不應自動套用至正式環境。

## 記憶體例外

個人 LAB 環境允許使用最少 4 GB RAM 進行安裝練習。

- `00_PreCheck.sh` 在 RAM 達到 4096 MB 時可以通過記憶體檢查。
- Swap 仍依腳本中的 LAB 規則檢查。
- 此設定只用於資源有限的個人測試環境，不代表 Oracle 正式環境的最低需求。
- 正式環境、UAT、公司環境或客戶環境不得套用此例外。

## Oracle Linux 相容性

若 Oracle 19.3 Base Software 安裝於較新的 Oracle Linux 版本，可能出現 prerequisite 或相容性警告。

如個人 LAB 環境需要加入相容性處理，必須符合以下原則：

- 寫法保持簡單、明確。
- 明確標示為個人 LAB 專用處理。
- 不得默認套用到正式環境。
- 不得為了相容性處理加入過度複雜的 Shell 邏輯。

## Script 處理原則

對 RU 與 OPatch 採用簡單規則：

```text
變數有設定
    -> 檢查檔案是否存在
    -> 執行對應處理

變數為空
    -> 顯示 Skip 訊息
    -> 略過該步驟
```

例如：

```bash
if [ -n "$GI_RU" ]; then
    if [ ! -f "$GI_RU" ]; then
        echo "ERROR: GI RU file not found: $GI_RU"
        exit 1
    fi
else
    echo "GI RU is not configured. Skip."
fi
```

## 重要界線

本文件中的所有例外設定，只適用於個人 LAB 環境。

正式環境、UAT、公司環境或客戶環境，應依各自的 Oracle 版本、RU、OPatch、OS 相容性與 Patch 標準進行規劃與驗證。
