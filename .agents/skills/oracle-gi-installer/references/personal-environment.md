# 個人環境特別注意事項

## 適用範圍

個人環境主要用於 Oracle Grid Infrastructure、ASM、Oracle Restart 與 Oracle Database 的學習、測試及安裝練習。

個人 LAB 環境的作業系統固定為：

```text
Oracle Linux 9（OEL9）
```

本文件中的規則只適用於 `ENVIRONMENT="PERSONAL_LAB"`。

## Oracle Linux 9 版本與 Patch 原則

Oracle Linux 9 安裝 Oracle Database 19c 與 Oracle Grid Infrastructure 19c 時，必須使用 Oracle 官方支援的 RU 與相容 OPatch。

Oracle 19.3 Gold Image 只能作為 Base Software 來源，不得在 Oracle Linux 9 上略過必要 RU 後直接視為支援的安裝組合。

一般模式必須提供 Base、套用至各 Oracle Home 的 RU，以及相容 OPatch 的版本及位置：

```bash
GI_BASE_VERSION="19.3.0.0.0"
GI_RU_VERSION="CHANGE_ME"
GI_RU="CHANGE_ME"
GI_OPATCH_VERSION="CHANGE_ME"
GI_OPATCH="CHANGE_ME"

DB_BASE_VERSION="19.3.0.0.0"
DB_RU_VERSION="CHANGE_ME"
DB_RU="CHANGE_ME"
DB_OPATCH_VERSION="CHANGE_ME"
DB_OPATCH="CHANGE_ME"
```

`DB_RU_VERSION` 與 `DB_RU` 代表要套用至 Database Home 的 RU 版本與位置，不預先限定 Patch Bundle 名稱一定是 DBRU。實際應使用 DBRU、GIRU 或其他 Oracle 指定的 RU Bundle，必須依安裝拓撲與當時的 Oracle 官方文件決定。

`DB_OPATCH_VERSION` 與 `DB_OPATCH` 代表用於更新 Database Home 的 OPatch，不得與 Grid Home 的 OPatch 設定混用。

實際 RU 與 OPatch 版本必須依產生安裝套件當下的 Oracle 官方文件確認，不得只依固定範例版本判斷。

## 無 RU／OPatch 的個人 LAB 例外

無法取得 My Oracle Support Patch 時，可以明確啟用不受支援的 19.3 Base-only LAB 模式：

```bash
ALLOW_UNSUPPORTED_19_3_BASE="YES"

GI_RU_VERSION=""
GI_RU=""
GI_OPATCH_VERSION=""
GI_OPATCH=""

DB_RU_VERSION=""
DB_RU=""
DB_OPATCH_VERSION=""
DB_OPATCH=""
```

這個例外必須同時符合：

- `ENVIRONMENT="PERSONAL_LAB"`。
- `ALLOW_UNSUPPORTED_19_3_BASE="YES"`。
- GI 與 Database Base Software 仍必須存在。
- PreCheck 必須顯示不符合 Oracle Linux 9 官方支援條件的警告。
- GI 與 Database 安裝腳本必須略過外部 OPatch 更新、`-applyRU` 及 Patch Inventory 版本比對。
- 不得將結果描述為符合 Oracle prerequisite 或 Oracle 支援組合。

如果 RU 或 OPatch 留空，但 `ALLOW_UNSUPPORTED_19_3_BASE` 不是 `YES`：

- `00_PreCheck.sh` 必須顯示錯誤並停止。
- 不得產生可直接執行且宣稱符合支援條件的 Oracle Linux 9 安裝套件。
- RU 與 OPatch 的版本及路徑仍為必要設定。

## 必要安裝媒體

Oracle Grid Infrastructure 與 Oracle Database 的 Base 安裝檔仍為必要項目。

例如：

```bash
GI_SOFTWARE="/software/LINUX.X64_193000_grid_home.zip"
DB_SOFTWARE="/software/LINUX.X64_193000_db_home.zip"
```

如果必要的 Base 安裝檔不存在，PreCheck 必須失敗並停止後續安裝。

## 記憶體例外

Oracle Grid Infrastructure 的正式最低記憶體要求為 8 GB。個人 LAB 可以在至少 4 GB RAM 時使用警告型例外繼續安裝練習。Swap 必須依下列規則判斷：

```text
RAM >= 8192 MB and RAM <= 16384 MB
    -> PASS
    -> Swap >= RAM

RAM > 16384 MB
    -> PASS
    -> Swap >= 16384 MB

RAM >= 4096 MB and RAM < 8192 MB
and ENVIRONMENT=PERSONAL_LAB
    -> WARNING
    -> Swap >= RAM
    -> Allow PERSONAL_LAB exception
    -> Does not meet the official RAM prerequisite

RAM < 4096 MB
    -> ERROR
```

- 4 GB 到 8 GB 之間不得顯示為符合 Oracle prerequisite，只能顯示 LAB warning。
- 4 GB 到 8 GB 的 `Swap >= RAM` 是 PERSONAL_LAB 規則，不代表符合 Oracle 官方 RAM prerequisite。
- Swap 不符合上述門檻時，`00_PreCheck.sh` 必須顯示錯誤並停止。

## Script 處理原則

對套用至 Grid Home 或 Database Home 的 RU 與 OPatch 採用簡單規則：

```text
版本與路徑有設定
    -> 檢查檔案是否存在
    -> 執行對應處理

版本或路徑未設定
and PERSONAL_LAB + ALLOW_UNSUPPORTED_19_3_BASE=YES
    -> 顯示 WARNING
    -> 略過 OPatch 與 RU

版本或路徑未設定
and unsupported mode is not enabled
    -> 顯示 ERROR
    -> 停止執行
```
