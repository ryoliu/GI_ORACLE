# 安裝流程

## 共用設定

`GI_Setup.conf` 保存所有非機密環境設定。每支腳本執行前必須載入並檢查目前階段需要的設定。

## 00_PreCheck.sh

- 執行帳號：`root`
- 僅進行讀取與檢查，不修改主機
- 檢查 OS、CPU、記憶體、Swap、Filesystem、Hostname、名稱解析、時間同步、套件、Kernel、Limits、帳號、群組、目錄、安裝媒體及 ASM 磁碟可見性
- 套件、Kernel、Limits、帳號、群組及目錄若缺少且可由 `01_PreInstall.sh` 建立或設定，只顯示警告，不得阻止進入 PreInstall
- 現有設定與預期衝突、平台不相容、必要安裝媒體缺失或 ASM 磁碟不可見時，顯示錯誤並停止

## 01_PreInstall.sh

- 執行帳號：`root`
- 安裝必要 OS 套件
- 建立群組、`grid`、`oracle`、目錄及權限
- 將 `grid` 加入 Database OSDBA 與 OSRACDBA，並將 `oracle` 加入 ASM OSDBA
- 只有在使用者要求職責分離時才建立或指定 Database OSOPER 與 ASM OSOPER
- 設定 Kernel Parameters、Limits 與持久化磁碟權限

## 02_InstallGI.sh

- 執行帳號：`grid`
- 解壓或準備 GI 安裝媒體
- 建立符合指定版本的 Response File
- 使用 Silent Mode 安裝 Oracle Restart
- 清楚顯示後續需要由 `root` 執行的腳本

不同版本的 `gridSetup.sh` 可能同時進行 Oracle Restart 或初始 ASM 設定。必須依指定版本的 Oracle 官方文件安排步驟，不可強制拆成不受支援的 Software-only 流程。

## 03_ConfigGI.sh

- 執行帳號：依步驟使用 `root` 或 `grid`
- 執行必要的 Root Script
- 設定與驗證 Oracle Restart
- 建立安裝階段尚未建立的 ASM 資源或 Disk Group
- 驗證 CRS、OHAS、ASM、Disk Group 與自動啟動狀態

## 04_InstallDatabaseSoftware.sh

- 執行帳號：`oracle`
- 解壓或準備 Database 安裝媒體
- 建立符合指定版本的 Response File
- 使用 Silent Mode 執行 Software-only 安裝
- 清楚顯示需要由 `root` 執行的腳本

## 05_CreateListener.sh

- 執行帳號：`grid`
- 使用 Grid Home 建立 Listener
- 使用指定的 Listener 名稱、位址與連接埠
- 將 Listener 註冊至 Oracle Restart 並驗證狀態

## 06_CreateDatabase.sh

- 執行帳號：`oracle`
- 使用 DBCA Silent Mode 建立 Database
- 使用已確認的 CDB、PDB、Character Set、Memory、ASM 與密碼輸入方式
- 將 Database 與 Service 註冊至 Oracle Restart

## 07_ConfigDatabase.sh

- 執行帳號：`oracle`
- 只調整使用者要求的 Database 設定
- 視需求設定 ARCHIVELOG、FRA、Service、SPFILE 與啟動策略
- 驗證實際生效的參數

## 08_CreateTnsnames.sh

- 執行帳號：依目標目錄使用 `grid` 或 `oracle`
- 保留不相關的 Alias
- 只新增或更新指定的 TNS Alias
- 分別處理 Grid Home 與 Database Home 的 Network 設定

## 09_PostCheck.sh

- 執行帳號：依檢查項目使用 `root`、`grid` 或 `oracle`
- 檢查 Oracle Restart、ASM、Disk Group、Listener、Database、PDB、Service、ARCHIVELOG、FRA 及連線狀態
- 必要元件異常時回傳非零狀態

## 執行交接

不得將帳號切換隱藏在腳本內。交付時必須列出每個階段的執行帳號，以及 `root`、`grid`、`oracle` 之間的交接順序。
