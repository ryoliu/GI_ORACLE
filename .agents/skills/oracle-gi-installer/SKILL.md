---
name: oracle-gi-installer
description: 規劃、產生及檢查 Oracle Grid Infrastructure 單機環境、Oracle Restart、ASM 與單機 Oracle Database 的簡短 Bash 安裝腳本。適用於分階段安裝、前置檢查、設定與安裝後檢查；不適用於 RAC。
---

# Oracle GI Installer

此 Skill 用於建立 Oracle Grid Infrastructure 單機環境、Oracle Restart、ASM 與單機 Oracle Database 的安裝腳本。

## 適用範圍

- Oracle Grid Infrastructure Standalone Server
- Oracle Restart
- Oracle ASM
- Single Instance Oracle Database
- Silent installation

RAC、RAC One Node、Oracle Appliance 與雲端代管資料庫不屬於此 Skill 的範圍。

## 使用流程

1. 先確認 `GI_Setup.conf` 的 `ENVIRONMENT`。
2. 當 `ENVIRONMENT="PERSONAL_LAB"` 時，必須讀取 [個人環境特別注意事項](references/personal-environment.md)，並優先套用其中的 LAB 例外規則。
3. 產生或修改腳本前，讀取 [必要輸入資料](references/required-inputs.md)。
4. 規劃、產生或修改腳本時，讀取 [安裝流程](references/installation-flow.md) 中的相關階段。
5. 產生、修改或檢查 Shell 腳本時，讀取 [驗證規則](references/validation-rules.md)。
6. 安裝前使用 [安裝前檢查清單](checklists/pre-install.md)。
7. 安裝完成後使用 [安裝後檢查清單](checklists/post-install.md)。
8. 腳本範本存放於 `templates` 目錄。

## 基本原則

- 使用繁體中文說明。
- 所有 Shell 程式必須遵循專案 `AGENTS.md`。
- 環境設定集中放在 `GI_Setup.conf`，不得儲存密碼。
- `PERSONAL_LAB` 只能套用 `personal-environment.md` 明確定義的例外。
- 不得猜測磁碟、目錄、帳號、群組、主機名稱或資料庫名稱。
- 產生腳本不代表可以執行安裝或修改主機。

## 輸出規則

`templates/` 目錄下的檔案是可重複使用的設計範本，用於提供安裝流程、核心判斷邏輯及基本程式結構，不是最終可執行的安裝套件。

設計範本不得省略會影響 Oracle GI 安裝正確性或安全性的判斷邏輯。

除非使用者明確要求修改範本，否則不得將主機專屬設定值寫入或直接修改範本檔案。

產生 Oracle GI 安裝套件時，應根據範本、參考文件及使用者提供的環境設定，將完整可執行的檔案建立在使用者指定的輸出目錄中。

如果使用者沒有指定輸出目錄，預設使用專案根目錄下的：

```text
output/oracle-gi-install/
```

當使用者要求完整安裝套件時，應產生：

```text
GI_Setup.conf
00_PreCheck.sh
01_PreInstall.sh
02_InstallGI.sh
03_ConfigGI.sh
04_InstallDatabaseSoftware.sh
05_CreateListener.sh
06_CreateDatabase.sh
07_ConfigDatabase.sh
08_CreateTnsnames.sh
09_PostCheck.sh
```

- 當使用者只要求單一階段或指定檔案時，只產生其要求的檔案及該階段必要的設定檔。
- 若必要輸入不足，先列出缺少的資料，不產生可直接執行且含猜測值的腳本。
