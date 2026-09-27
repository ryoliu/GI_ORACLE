# 驗證規則

一般 Shell 程式標準、錯誤處理、冪等性、相依工具、語法檢查及顏色輸出依專案 `AGENTS.md`。本文件只定義 Oracle GI 安裝的技術驗證與安全規則。

## Shell 檢查

- Oracle 指令必須使用指定安裝媒體或 Oracle Home 提供的工具。
- 必須檢查目前帳號符合 [安裝流程](installation-flow.md) 指定的執行帳號。
- 必須檢查目前階段需要的設定變數。
- 不得輸出密碼或其他機密資訊。

## 安全檢查

- ASM 裝置路徑必須由使用者明確確認。
- 發現磁碟不代表取得修改磁碟的授權。
- 不得自動清除磁碟、ASM Header 或未知設定。
- 不得自動關閉 SELinux 或 Firewall。
- 不得自動重新啟動主機。
- 產生腳本後預設只進行語法與靜態檢查，不在目前主機執行安裝。

## 版本檢查

OS 套件、Kernel 需求、Installer 參數、Response File 與 DBCA 選項必須依指定 Oracle 版本的官方文件確認，不得直接沿用其他版本設定。

當 `ENVIRONMENT="PERSONAL_LAB"` 時，只能套用 [個人環境特別注意事項](personal-environment.md) 明確定義的例外；未定義的項目仍使用標準規則。
