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
3. 產生腳本前，讀取 [必要輸入資料](references/required-inputs.md)。
4. 規劃或產生完整安裝流程時，讀取 [安裝流程](references/installation-flow.md)。
5. 檢查腳本時，讀取 [驗證規則](references/validation-rules.md)。
6. 安裝前使用 [安裝前檢查清單](checklists/pre-install.md)。
7. 安裝完成後使用 [安裝後檢查清單](checklists/post-install.md)。
8. 腳本範本存放於 `templates` 目錄。

## 基本原則

- 使用繁體中文說明。
- 所有程式碼、變數、函式、註解及腳本輸出使用英文。
- 腳本保持簡短、簡單及容易閱讀。
- 使用 Bash，並遵循專案 `AGENTS.md` 的錯誤處理及冪等性規則；正式輸出程式另須遵循顏色輸出規則。
- 環境設定集中放在 `GI_Setup.conf`，不得儲存密碼。
- 個人 LAB 可以依 `personal-environment.md` 放寬記憶體、效能及建議性設定，但不得放寬 OS 與 Oracle 版本相容性、必要 RU、OPatch、CPU 架構或 Installer 必要條件。
- 不得猜測磁碟、目錄、帳號、群組、主機名稱或資料庫名稱。
- 產生腳本不代表可以執行安裝或修改主機。
- 未取得明確授權時，不得格式化磁碟、清除 ASM Header、刪除資料庫、移除 Oracle Home、關閉 SELinux、關閉 Firewall 或重新啟動主機。

## 輸出規則

`templates/` 目錄下的檔案是可重複使用的設計範本，用於提供安裝流程、核心判斷邏輯及基本程式結構。

不要將 `templates/` 目錄下的檔案視為最終可執行的安裝套件。

設計範本可以省略 ANSI 顏色、共用顯示函式及其他只影響輸出格式的程式碼，但不得省略會影響 Oracle GI 安裝正確性或安全性的判斷邏輯。

設計範本中的 Shell 程式碼必須保持有效 Bash 語法，並通過 `bash -n`。

除非使用者明確要求修改範本，否則不得將主機專屬設定值寫入或直接修改範本檔案。

產生 Oracle GI 安裝套件時，應根據範本、參考文件及使用者提供的環境設定，將完整可執行的檔案建立在使用者指定的輸出目錄中。

正式產生的程式必須完整遵循 `AGENTS.md` 的錯誤處理、顏色輸出、冪等性及驗證規則。

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
